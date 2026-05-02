import 'dart:convert';
import 'dart:math';

/// GPS Location data model
class GpsLocation {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final DateTime timestamp;

  const GpsLocation({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.timestamp,
  });

  /// Create GpsLocation from JSON
  factory GpsLocation.fromJson(Map<String, dynamic> json) {
    return GpsLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convert GpsLocation to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'GpsLocation(lat: $latitude, lng: $longitude, alt: $altitude, acc: $accuracy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GpsLocation &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.accuracy == accuracy &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
        longitude.hashCode ^
        altitude.hashCode ^
        accuracy.hashCode ^
        timestamp.hashCode;
  }
}

/// Vehicle Parameters model containing all sensor data from IoT device
class VehicleParameters {
  final String deviceId;
  final DateTime timestamp;
  final double accelerationX; // G-force in X axis
  final double accelerationY; // G-force in Y axis
  final double accelerationZ; // G-force in Z axis
  final double speed; // Speed in km/h
  final GpsLocation location;
  final double orientation; // Orientation in degrees (0-360)
  final double impactForce; // Combined impact force in G
  final Map<String, dynamic> additionalSensors; // Additional sensor data

  const VehicleParameters({
    required this.deviceId,
    required this.timestamp,
    required this.accelerationX,
    required this.accelerationY,
    required this.accelerationZ,
    required this.speed,
    required this.location,
    required this.orientation,
    required this.impactForce,
    this.additionalSensors = const {},
  });

  /// Create VehicleParameters from JSON
  factory VehicleParameters.fromJson(Map<String, dynamic> json) {
    return VehicleParameters(
      deviceId: json['deviceId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      accelerationX: (json['accelerationX'] as num).toDouble(),
      accelerationY: (json['accelerationY'] as num).toDouble(),
      accelerationZ: (json['accelerationZ'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      location: GpsLocation.fromJson(json['location'] as Map<String, dynamic>),
      orientation: (json['orientation'] as num).toDouble(),
      impactForce: (json['impactForce'] as num).toDouble(),
      additionalSensors: Map<String, dynamic>.from(
        json['additionalSensors'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert VehicleParameters to JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'accelerationX': accelerationX,
      'accelerationY': accelerationY,
      'accelerationZ': accelerationZ,
      'speed': speed,
      'location': location.toJson(),
      'orientation': orientation,
      'impactForce': impactForce,
      'additionalSensors': additionalSensors,
    };
  }

  /// Create VehicleParameters from JSON string
  factory VehicleParameters.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return VehicleParameters.fromJson(json);
  }

  /// Convert VehicleParameters to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Validate parameter ranges
  bool isValid() {
    // Check for reasonable ranges
    if (accelerationX.abs() > 50 || accelerationY.abs() > 50 || accelerationZ.abs() > 50) {
      return false; // Unrealistic acceleration values
    }
    
    if (speed < 0 || speed > 500) {
      return false; // Invalid speed range
    }
    
    if (orientation < 0 || orientation > 360) {
      return false; // Invalid orientation range
    }
    
    if (impactForce < 0 || impactForce > 100) {
      return false; // Invalid impact force range
    }
    
    if (location.latitude.abs() > 90 || location.longitude.abs() > 180) {
      return false; // Invalid GPS coordinates
    }
    
    return true;
  }

  /// Calculate total acceleration magnitude
  double get totalAcceleration {
    return sqrt(accelerationX * accelerationX +
                accelerationY * accelerationY +
                accelerationZ * accelerationZ);
  }

  /// Check if this represents normal driving conditions
  bool get isNormalDriving {
    return totalAcceleration < 2.0 && // Less than 2G total acceleration
           speed < 120 && // Reasonable speed
           impactForce < 1.5; // Low impact force
  }

  /// Rule-based fallback — used only when TFLite model is unavailable.
  /// ML replaces this for normal operation.
  bool get exceedsAccidentThreshold {
    return totalAcceleration > 4.0 || // High G-force
           impactForce > 3.0 || // High impact
           (speed > 50 && totalAcceleration > 3.0); // High speed with high G
  }

  /// Returns a 6-float feature vector for a single sensor sample:
  /// [accelX, accelY, accelZ, speed_norm, impactForce, orientation_norm]
  ///
  /// Values are normalised to roughly [-1, 1] / [0, 1] ranges
  /// to match the training-data distribution.
  List<double> toFeatureVector() {
    return [
      accelerationX / 10.0,      // normalise ±10 G range
      accelerationY / 10.0,
      accelerationZ / 10.0,
      speed / 200.0,             // normalise 0-200 km/h
      impactForce / 10.0,        // normalise 0-10 G impact
      orientation / 360.0,       // normalise 0-360°
    ];
  }

  /// Creates a flat 30-float array from a 5-sample sliding window.
  ///
  /// Each sample contributes 6 floats → 5 × 6 = 30 total.
  /// If [window] has fewer than 5 samples, earlier slots are zero-padded.
  static List<double> flattenWindow(List<VehicleParameters> window) {
    const int windowSize = 5;
    const int featuresPerSample = 6;
    final result = List<double>.filled(windowSize * featuresPerSample, 0.0);

    final start = window.length >= windowSize
        ? window.length - windowSize
        : 0;
    final samples = window.sublist(start);

    for (int i = 0; i < samples.length; i++) {
      final vec = samples[i].toFeatureVector();
      final offset = i * featuresPerSample;
      for (int j = 0; j < featuresPerSample; j++) {
        result[offset + j] = vec[j];
      }
    }
    return result;
  }

  /// Create a copy with updated values
  VehicleParameters copyWith({
    String? deviceId,
    DateTime? timestamp,
    double? accelerationX,
    double? accelerationY,
    double? accelerationZ,
    double? speed,
    GpsLocation? location,
    double? orientation,
    double? impactForce,
    Map<String, dynamic>? additionalSensors,
  }) {
    return VehicleParameters(
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      accelerationX: accelerationX ?? this.accelerationX,
      accelerationY: accelerationY ?? this.accelerationY,
      accelerationZ: accelerationZ ?? this.accelerationZ,
      speed: speed ?? this.speed,
      location: location ?? this.location,
      orientation: orientation ?? this.orientation,
      impactForce: impactForce ?? this.impactForce,
      additionalSensors: additionalSensors ?? this.additionalSensors,
    );
  }

  @override
  String toString() {
    return 'VehicleParameters(deviceId: $deviceId, speed: ${speed.toStringAsFixed(1)} km/h, '
           'acceleration: ${totalAcceleration.toStringAsFixed(2)}G, '
           'impact: ${impactForce.toStringAsFixed(2)}G, '
           'location: $location)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleParameters &&
        other.deviceId == deviceId &&
        other.timestamp == timestamp &&
        other.accelerationX == accelerationX &&
        other.accelerationY == accelerationY &&
        other.accelerationZ == accelerationZ &&
        other.speed == speed &&
        other.location == location &&
        other.orientation == orientation &&
        other.impactForce == impactForce;
  }

  @override
  int get hashCode {
    return deviceId.hashCode ^
        timestamp.hashCode ^
        accelerationX.hashCode ^
        accelerationY.hashCode ^
        accelerationZ.hashCode ^
        speed.hashCode ^
        location.hashCode ^
        orientation.hashCode ^
        impactForce.hashCode;
  }
}

/// Extension for mathematical operations
extension VehicleParametersExtension on VehicleParameters {
  /// Calculate sudden deceleration (change in speed per second)
  double calculateDeceleration(VehicleParameters previous) {
    final timeDiff = timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
    if (timeDiff <= 0) return 0.0;
    
    final speedDiff = previous.speed - speed; // Positive for deceleration
    return speedDiff / timeDiff; // km/h per second
  }

  /// Calculate distance from another GPS location in meters
  double distanceFrom(GpsLocation other) {
    const double earthRadius = 6371000; // Earth radius in meters
    
    final lat1Rad = location.latitude * (3.14159265359 / 180);
    final lat2Rad = other.latitude * (3.14159265359 / 180);
    final deltaLatRad = (other.latitude - location.latitude) * (3.14159265359 / 180);
    final deltaLngRad = (other.longitude - location.longitude) * (3.14159265359 / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}