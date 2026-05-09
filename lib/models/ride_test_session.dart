import 'dart:math';

import 'vehicle_parameters.dart';

enum RideTestSessionType {
  rideTest,
  slowRidingTest,
}

enum RideTestVehicleMode {
  bike,
  car,
}

class RideTestLocation {
  final double latitude;
  final double longitude;
  final double accuracy;

  const RideTestLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  factory RideTestLocation.fromGpsLocation(GpsLocation location) {
    return RideTestLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
    );
  }

  factory RideTestLocation.zero() {
    return const RideTestLocation(
      latitude: 0,
      longitude: 0,
      accuracy: 0,
    );
  }

  factory RideTestLocation.fromJson(Map<String, dynamic> json) {
    return RideTestLocation(
      latitude: (json['latitude'] as num? ?? 0).toDouble(),
      longitude: (json['longitude'] as num? ?? 0).toDouble(),
      accuracy: (json['accuracy'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    };
  }
}

class RideTestSample {
  final DateTime timestamp;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double speed;
  final double impactForce;
  final double orientation;
  final double latitude;
  final double longitude;
  final double totalAcceleration;

  const RideTestSample({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.speed,
    required this.impactForce,
    required this.orientation,
    required this.latitude,
    required this.longitude,
    required this.totalAcceleration,
  });

  factory RideTestSample.fromVehicleParameters(VehicleParameters params) {
    return RideTestSample(
      timestamp: params.timestamp,
      accelX: params.accelerationX,
      accelY: params.accelerationY,
      accelZ: params.accelerationZ,
      speed: params.speed,
      impactForce: params.impactForce,
      orientation: params.orientation,
      latitude: params.location.latitude,
      longitude: params.location.longitude,
      totalAcceleration: params.totalAcceleration,
    );
  }

  factory RideTestSample.fromJson(Map<String, dynamic> json) {
    return RideTestSample(
      timestamp: DateTime.parse(json['timestamp'] as String),
      accelX: (json['accel_x'] as num? ?? 0).toDouble(),
      accelY: (json['accel_y'] as num? ?? 0).toDouble(),
      accelZ: (json['accel_z'] as num? ?? 0).toDouble(),
      speed: (json['speed'] as num? ?? 0).toDouble(),
      impactForce: (json['impact_force'] as num? ?? 0).toDouble(),
      orientation: (json['orientation'] as num? ?? 0).toDouble(),
      latitude: (json['latitude'] as num? ?? 0).toDouble(),
      longitude: (json['longitude'] as num? ?? 0).toDouble(),
      totalAcceleration: (json['total_acceleration'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'accel_x': accelX,
      'accel_y': accelY,
      'accel_z': accelZ,
      'speed': speed,
      'impact_force': impactForce,
      'orientation': orientation,
      'latitude': latitude,
      'longitude': longitude,
      'total_acceleration': totalAcceleration,
    };
  }
}

class RideTestSession {
  final String sessionId;
  final RideTestSessionType sessionType;
  final RideTestVehicleMode vehicleMode;
  final DateTime startTime;
  final DateTime? stopTime;
  final RideTestLocation startLocation;
  final RideTestLocation? stopLocation;
  final int durationSeconds;
  final int totalSamples;
  final String notes;
  final List<RideTestSample> samples;
  final bool uploadedToFirestore;

  const RideTestSession({
    required this.sessionId,
    required this.sessionType,
    required this.vehicleMode,
    required this.startTime,
    this.stopTime,
    required this.startLocation,
    this.stopLocation,
    required this.durationSeconds,
    required this.totalSamples,
    required this.notes,
    required this.samples,
    this.uploadedToFirestore = false,
  });

  factory RideTestSession.start({
    required String sessionId,
    required RideTestSessionType sessionType,
    required RideTestVehicleMode vehicleMode,
    required RideTestLocation startLocation,
  }) {
    return RideTestSession(
      sessionId: sessionId,
      sessionType: sessionType,
      vehicleMode: vehicleMode,
      startTime: DateTime.now(),
      startLocation: startLocation,
      durationSeconds: 0,
      totalSamples: 0,
      notes: '',
      samples: const [],
    );
  }

  factory RideTestSession.fromJson(Map<String, dynamic> json) {
    final samples = (json['samples'] as List<dynamic>? ?? [])
        .map(
            (sample) => RideTestSample.fromJson(sample as Map<String, dynamic>))
        .toList();

    return RideTestSession(
      sessionId: json['session_id'] as String,
      sessionType: rideTestSessionTypeFromId(json['session_type'] as String),
      vehicleMode: rideTestVehicleModeFromId(json['vehicle_mode'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      stopTime: json['stop_time'] == null
          ? null
          : DateTime.parse(json['stop_time'] as String),
      startLocation: RideTestLocation.fromJson(
        json['start_location'] as Map<String, dynamic>? ?? {},
      ),
      stopLocation: json['stop_location'] == null
          ? null
          : RideTestLocation.fromJson(
              json['stop_location'] as Map<String, dynamic>,
            ),
      durationSeconds: (json['duration_seconds'] as num? ?? 0).toInt(),
      totalSamples: (json['total_samples'] as num? ?? samples.length).toInt(),
      notes: json['notes'] as String? ?? '',
      samples: samples,
      uploadedToFirestore: json['uploaded_to_firestore'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'session_type': sessionType.id,
      'vehicle_mode': vehicleMode.id,
      'start_time': startTime.toIso8601String(),
      'stop_time': stopTime?.toIso8601String(),
      'start_location': startLocation.toJson(),
      'stop_location': stopLocation?.toJson(),
      'duration_seconds': durationSeconds,
      'total_samples': totalSamples,
      'notes': notes,
      'samples': samples.map((sample) => sample.toJson()).toList(),
      'uploaded_to_firestore': uploadedToFirestore,
    };
  }

  RideTestSession copyWith({
    DateTime? stopTime,
    RideTestLocation? stopLocation,
    int? durationSeconds,
    int? totalSamples,
    String? notes,
    List<RideTestSample>? samples,
    bool? uploadedToFirestore,
  }) {
    return RideTestSession(
      sessionId: sessionId,
      sessionType: sessionType,
      vehicleMode: vehicleMode,
      startTime: startTime,
      stopTime: stopTime ?? this.stopTime,
      startLocation: startLocation,
      stopLocation: stopLocation ?? this.stopLocation,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalSamples: totalSamples ?? this.totalSamples,
      notes: notes ?? this.notes,
      samples: samples ?? this.samples,
      uploadedToFirestore: uploadedToFirestore ?? this.uploadedToFirestore,
    );
  }

  RideTestSessionSummary toSummary() {
    return RideTestSessionSummary(
      sessionId: sessionId,
      sessionType: sessionType,
      vehicleMode: vehicleMode,
      startTime: startTime,
      durationSeconds: durationSeconds,
      totalSamples: totalSamples,
      uploadedToFirestore: uploadedToFirestore,
    );
  }

  RideTestSessionStats get stats {
    return RideTestSessionStats.fromSamples(samples);
  }
}

class RideTestSessionSummary {
  final String sessionId;
  final RideTestSessionType sessionType;
  final RideTestVehicleMode vehicleMode;
  final DateTime startTime;
  final int durationSeconds;
  final int totalSamples;
  final bool uploadedToFirestore;

  const RideTestSessionSummary({
    required this.sessionId,
    required this.sessionType,
    required this.vehicleMode,
    required this.startTime,
    required this.durationSeconds,
    required this.totalSamples,
    required this.uploadedToFirestore,
  });

  factory RideTestSessionSummary.fromJson(Map<String, dynamic> json) {
    return RideTestSessionSummary(
      sessionId: json['session_id'] as String,
      sessionType: rideTestSessionTypeFromId(json['session_type'] as String),
      vehicleMode: rideTestVehicleModeFromId(json['vehicle_mode'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      durationSeconds: (json['duration_seconds'] as num? ?? 0).toInt(),
      totalSamples: (json['total_samples'] as num? ?? 0).toInt(),
      uploadedToFirestore: json['uploaded_to_firestore'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'session_type': sessionType.id,
      'vehicle_mode': vehicleMode.id,
      'start_time': startTime.toIso8601String(),
      'duration_seconds': durationSeconds,
      'total_samples': totalSamples,
      'uploaded_to_firestore': uploadedToFirestore,
    };
  }
}

class RideTestSessionStats {
  final double minSpeed;
  final double maxSpeed;
  final double avgSpeed;
  final double minGForce;
  final double maxGForce;
  final double avgGForce;
  final double distanceMeters;

  const RideTestSessionStats({
    required this.minSpeed,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.minGForce,
    required this.maxGForce,
    required this.avgGForce,
    required this.distanceMeters,
  });

  factory RideTestSessionStats.fromSamples(List<RideTestSample> samples) {
    if (samples.isEmpty) {
      return const RideTestSessionStats(
        minSpeed: 0,
        maxSpeed: 0,
        avgSpeed: 0,
        minGForce: 0,
        maxGForce: 0,
        avgGForce: 0,
        distanceMeters: 0,
      );
    }

    double minSpeed = samples.first.speed;
    double maxSpeed = samples.first.speed;
    double speedTotal = 0;
    double minGForce = samples.first.totalAcceleration;
    double maxGForce = samples.first.totalAcceleration;
    double gForceTotal = 0;
    double distanceMeters = 0;

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      minSpeed = min(minSpeed, sample.speed);
      maxSpeed = max(maxSpeed, sample.speed);
      speedTotal += sample.speed;
      minGForce = min(minGForce, sample.totalAcceleration);
      maxGForce = max(maxGForce, sample.totalAcceleration);
      gForceTotal += sample.totalAcceleration;

      if (i > 0) {
        distanceMeters += _distanceBetween(samples[i - 1], sample);
      }
    }

    return RideTestSessionStats(
      minSpeed: minSpeed,
      maxSpeed: maxSpeed,
      avgSpeed: speedTotal / samples.length,
      minGForce: minGForce,
      maxGForce: maxGForce,
      avgGForce: gForceTotal / samples.length,
      distanceMeters: distanceMeters,
    );
  }

  static double _distanceBetween(RideTestSample a, RideTestSample b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final deltaLat = (b.latitude - a.latitude) * pi / 180;
    final deltaLng = (b.longitude - a.longitude) * pi / 180;

    final h = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h));
  }
}

extension RideTestSessionTypeX on RideTestSessionType {
  String get id {
    switch (this) {
      case RideTestSessionType.rideTest:
        return 'ride_test';
      case RideTestSessionType.slowRidingTest:
        return 'slow_riding_test';
    }
  }

  String get label {
    switch (this) {
      case RideTestSessionType.rideTest:
        return 'Ride Test';
      case RideTestSessionType.slowRidingTest:
        return 'Slow Riding Test';
    }
  }
}

extension RideTestVehicleModeX on RideTestVehicleMode {
  String get id {
    switch (this) {
      case RideTestVehicleMode.bike:
        return 'bike';
      case RideTestVehicleMode.car:
        return 'car';
    }
  }

  String get label {
    switch (this) {
      case RideTestVehicleMode.bike:
        return 'Bike';
      case RideTestVehicleMode.car:
        return 'Car';
    }
  }
}

RideTestSessionType rideTestSessionTypeFromId(String id) {
  switch (id) {
    case 'slow_riding_test':
      return RideTestSessionType.slowRidingTest;
    case 'ride_test':
    default:
      return RideTestSessionType.rideTest;
  }
}

RideTestVehicleMode rideTestVehicleModeFromId(String id) {
  switch (id) {
    case 'car':
      return RideTestVehicleMode.car;
    case 'bike':
    default:
      return RideTestVehicleMode.bike;
  }
}
