import 'package:firebase_database/firebase_database.dart';
import '../models/vehicle_parameters.dart';

/// Hot-path repository: writes real-time data to Firebase Realtime Database.
///
/// Structure:
///   /ambulances/{deviceId}/live          — latest telemetry (overwritten each tick)
///   /ambulances/{deviceId}/crash_events/{id} — immutable crash snapshots
class FirebaseRTDRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Write the latest telemetry for [params.deviceId].
  ///
  /// Uses `set()` (overwrite) instead of `push()` to avoid unbounded list
  /// growth at 1 Hz.
  Future<void> writeRealtime(
    VehicleParameters params, {
    bool crashDetected = false,
    bool sosActive = false,
  }) async {
    final ref = _db.child('ambulances/${params.deviceId}/live');

    await ref.set({
      'lat': params.location.latitude,
      'lng': params.location.longitude,
      'speed': params.speed,
      'crash_detected': crashDetected,
      'sos_active': sosActive,
      'impact_force': params.impactForce,
      'total_acceleration': params.totalAcceleration,
      'device_status': 'online',
      'updated_at': ServerValue.timestamp,
    });
  }

  /// Persist a crash event snapshot under the device's crash history.
  ///
  /// Uses `push()` here because crash events are rare and each one must be
  /// individually addressable.
  Future<void> writeCrashEvent(
    VehicleParameters params,
    String eventId,
  ) async {
    final ref =
        _db.child('ambulances/${params.deviceId}/crash_events/$eventId');

    await ref.set({
      'event_id': eventId,
      'lat': params.location.latitude,
      'lng': params.location.longitude,
      'speed': params.speed,
      'impact_force': params.impactForce,
      'accel_x': params.accelerationX,
      'accel_y': params.accelerationY,
      'accel_z': params.accelerationZ,
      'total_acceleration': params.totalAcceleration,
      'orientation': params.orientation,
      'additional_sensors': params.additionalSensors,
      'timestamp': params.timestamp.toIso8601String(),
      'created_at': ServerValue.timestamp,
    });
  }

  /// Mark a device as offline in the live node.
  Future<void> markOffline(String deviceId) async {
    final ref = _db.child('ambulances/$deviceId/live');
    await ref.update({
      'device_status': 'offline',
      'updated_at': ServerValue.timestamp,
    });
  }
}
