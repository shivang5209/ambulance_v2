import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';
import '../models/vehicle_parameters.dart';

/// Cold-path repository: batches sensor data and flushes to Supabase PostgreSQL.
///
/// Call [enqueue] on every tick (cheap, in-memory only).
/// Call [flush] to batch-insert the queue into the `sensor_readings` table.
/// On flush failure the records are re-enqueued at the front to preserve order.
class SupabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;

  final List<Map<String, dynamic>> _queue = [];

  /// Number of records currently waiting to be flushed.
  int get pendingCount => _queue.length;

  /// Add a sensor reading to the in-memory queue (no I/O).
  void enqueue(VehicleParameters params) {
    _queue.add(_toRow(params));
  }

  /// Batch-insert all queued records into the `sensor_readings` table.
  ///
  /// Returns the number of rows successfully inserted.
  /// On failure, re-enqueues the records at the front so nothing is lost.
  Future<int> flush() async {
    if (_queue.isEmpty) return 0;

    // Snapshot the current batch and clear the queue optimistically.
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      await _client
          .from(SupabaseConfig.sensorReadingsTable)
          .insert(batch);
      return batch.length;
    } catch (e) {
      // Re-enqueue at front to preserve chronological order.
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
    await _client.from(SupabaseConfig.tripSummariesTable).insert({
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
    await _client.from(SupabaseConfig.crashEventsTable).insert({
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

  // ── Private helpers ────────────────────────────────────────────────

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
}
