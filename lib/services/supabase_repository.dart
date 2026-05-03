import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_config.dart';
import '../models/sensor_analytics.dart';
import '../models/vehicle_parameters.dart';

/// Cold-path repository: batches sensor data and flushes to Supabase PostgreSQL.
///
/// Call [enqueue] on every tick (cheap, in-memory only).
/// Call [flush] to batch-insert the queue into the `sensor_readings` table.
/// On flush failure the records are re-enqueued at the front to preserve order.
class SupabaseRepository {
  final List<Map<String, dynamic>> _queue = [];

  bool get _isEnabled => SupabaseConfig.isConfigured;
  SupabaseClient? get _client => _isEnabled ? Supabase.instance.client : null;

  /// Number of records currently waiting to be flushed.
  int get pendingCount => _isEnabled ? _queue.length : 0;

  /// Add a sensor reading to the in-memory queue (no I/O).
  void enqueue(VehicleParameters params) {
    if (!_isEnabled) return;
    _queue.add(_toRow(params));
  }

  /// Batch-insert all queued records into the `sensor_readings` table.
  ///
  /// Returns the number of rows successfully inserted.
  /// On failure, re-enqueues the records at the front so nothing is lost.
  Future<int> flush() async {
    if (!_isEnabled) {
      _queue.clear();
      return 0;
    }
    if (_queue.isEmpty) return 0;

    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      await _client!.from(SupabaseConfig.sensorReadingsTable).insert(batch);
      return batch.length;
    } catch (e) {
      _queue.insertAll(0, batch);
      rethrow;
    }
  }

  /// Write an aggregated trip summary row.
  Future<void> writeTripSummary({
    required String deviceId,
    required String tripId,
    required DateTime startTime,
    required DateTime endTime,
    required int totalReadings,
    required double distanceKm,
    required double avgSpeed,
    required double maxSpeed,
    required double maxGForce,
    required int crashEventCount,
  }) async {
    if (!_isEnabled) return;

    await _client!.from(SupabaseConfig.tripSummariesTable).insert({
      'device_id': deviceId,
      'trip_id': tripId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'total_readings': totalReadings,
      'distance_km': distanceKm,
      'avg_speed': avgSpeed,
      'max_speed': maxSpeed,
      'max_g_force': maxGForce,
      'crash_event_count': crashEventCount,
    });
  }

  /// Write a crash event row with JSONB parameter history.
  Future<void> writeCrashEvent({
    required String eventId,
    required VehicleParameters params,
    required List<VehicleParameters> recentHistory,
  }) async {
    if (!_isEnabled) return;

    await _client!.from(SupabaseConfig.crashEventsTable).insert({
      'event_id': eventId,
      'device_id': params.deviceId,
      'lat': params.location.latitude,
      'lng': params.location.longitude,
      'speed': params.speed,
      'impact_force': params.impactForce,
      'total_acceleration': params.totalAcceleration,
      'parameter_history': recentHistory.map((p) => p.toJson()).toList(),
      'timestamp': params.timestamp.toIso8601String(),
    });
  }

  Map<String, dynamic> _toRow(VehicleParameters p) {
    return {
      'device_id': p.deviceId,
      'accel_x': p.accelerationX,
      'accel_y': p.accelerationY,
      'accel_z': p.accelerationZ,
      'speed': p.speed,
      'lat': p.location.latitude,
      'lng': p.location.longitude,
      'altitude': p.location.altitude,
      'gps_accuracy': p.location.accuracy,
      'orientation': p.orientation,
      'impact_force': p.impactForce,
      'total_acceleration': p.totalAcceleration,
      'temperature': p.additionalSensors['temperature'],
      'humidity': p.additionalSensors['humidity'],
      'pressure': p.additionalSensors['pressure'],
      'battery_voltage': p.additionalSensors['battery_voltage'],
      'timestamp': p.timestamp.toIso8601String(),
    };
  }

  Future<SensorAnalyticsSummary> loadSensorAnalytics({
    int readingLimit = 180,
    int crashLimit = 120,
    int tripLimit = 60,
  }) async {
    if (!_isEnabled) return SensorAnalyticsSummary.empty();

    final readingsRaw = await _client!
        .from(SupabaseConfig.sensorReadingsTable)
        .select(
          'device_id,speed,impact_force,total_acceleration,timestamp,lat,lng,battery_voltage',
        )
        .order('timestamp', ascending: false)
        .limit(readingLimit);

    final crashRaw = await _client!
        .from(SupabaseConfig.crashEventsTable)
        .select('event_id')
        .order('timestamp', ascending: false)
        .limit(crashLimit);

    final tripRaw = await _client!
        .from(SupabaseConfig.tripSummariesTable)
        .select('distance_km')
        .order('start_time', ascending: false)
        .limit(tripLimit);

    final readings = (readingsRaw as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_toReadingSnapshot)
        .toList(growable: false)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final crashes = (crashRaw as List<dynamic>).cast<Map<String, dynamic>>();
    final trips = (tripRaw as List<dynamic>).cast<Map<String, dynamic>>();

    if (readings.isEmpty) {
      return SensorAnalyticsSummary(
        readingSampleCount: 0,
        activeDeviceCount: 0,
        averageSpeed: 0,
        peakSpeed: 0,
        averageImpactForce: 0,
        peakImpactForce: 0,
        averageAcceleration: 0,
        crashEventCount: crashes.length,
        tripSummaryCount: trips.length,
        totalTripDistanceKm: trips.fold<double>(
          0,
          (sum, row) => sum + ((row['distance_km'] as num?)?.toDouble() ?? 0),
        ),
        latestReadingAt: null,
        recentReadings: const <SensorReadingSnapshot>[],
        deviceBreakdown: const <DeviceAnalyticsSummary>[],
        speedSeries: const <double>[],
        impactSeries: const <double>[],
        accelerationSeries: const <double>[],
      );
    }

    final speedSeries = readings.map((reading) => reading.speed).toList();
    final impactSeries =
        readings.map((reading) => reading.impactForce).toList();
    final accelerationSeries =
        readings.map((reading) => reading.totalAcceleration).toList();

    final speedTotal = speedSeries.fold<double>(0, (sum, value) => sum + value);
    final impactTotal =
        impactSeries.fold<double>(0, (sum, value) => sum + value);
    final accelerationTotal =
        accelerationSeries.fold<double>(0, (sum, value) => sum + value);

    final deviceBuckets = <String, List<SensorReadingSnapshot>>{};
    for (final reading in readings) {
      deviceBuckets
          .putIfAbsent(reading.deviceId, () => <SensorReadingSnapshot>[])
          .add(reading);
    }

    final deviceBreakdown = deviceBuckets.entries.map((entry) {
      final deviceReadings = entry.value;
      final avgSpeed = deviceReadings.fold<double>(
            0,
            (sum, item) => sum + item.speed,
          ) /
          deviceReadings.length;
      final maxImpact = deviceReadings
          .map((item) => item.impactForce)
          .reduce((a, b) => a > b ? a : b);
      final lastSeen =
          deviceReadings.isEmpty ? null : deviceReadings.last.timestamp;
      return DeviceAnalyticsSummary(
        deviceId: entry.key,
        readingCount: deviceReadings.length,
        averageSpeed: avgSpeed,
        maxImpactForce: maxImpact,
        lastSeen: lastSeen,
      );
    }).toList(growable: false)
      ..sort((a, b) => b.readingCount.compareTo(a.readingCount));

    return SensorAnalyticsSummary(
      readingSampleCount: readings.length,
      activeDeviceCount: deviceBuckets.length,
      averageSpeed: speedTotal / readings.length,
      peakSpeed: speedSeries.reduce((a, b) => a > b ? a : b),
      averageImpactForce: impactTotal / readings.length,
      peakImpactForce: impactSeries.reduce((a, b) => a > b ? a : b),
      averageAcceleration: accelerationTotal / readings.length,
      crashEventCount: crashes.length,
      tripSummaryCount: trips.length,
      totalTripDistanceKm: trips.fold<double>(
        0,
        (sum, row) => sum + ((row['distance_km'] as num?)?.toDouble() ?? 0),
      ),
      latestReadingAt: readings.last.timestamp,
      recentReadings: readings.reversed.take(16).toList(growable: false),
      deviceBreakdown: deviceBreakdown,
      speedSeries: speedSeries,
      impactSeries: impactSeries,
      accelerationSeries: accelerationSeries,
    );
  }

  SensorReadingSnapshot _toReadingSnapshot(Map<String, dynamic> row) {
    return SensorReadingSnapshot(
      deviceId: row['device_id'] as String? ?? 'unknown',
      timestamp: DateTime.tryParse(row['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      speed: (row['speed'] as num?)?.toDouble() ?? 0,
      impactForce: (row['impact_force'] as num?)?.toDouble() ?? 0,
      totalAcceleration: (row['total_acceleration'] as num?)?.toDouble() ?? 0,
      latitude: (row['lat'] as num?)?.toDouble(),
      longitude: (row['lng'] as num?)?.toDouble(),
      batteryVoltage: (row['battery_voltage'] as num?)?.toDouble(),
    );
  }
}
