import 'dart:convert';
import 'vehicle_parameters.dart';
import 'emergency_response.dart';

/// Accident severity levels
enum AccidentSeverity {
  minor('Minor', 1),
  moderate('Moderate', 2),
  severe('Severe', 3),
  critical('Critical', 4);

  const AccidentSeverity(this.displayName, this.level);

  final String displayName;
  final int level;

  /// Create AccidentSeverity from string
  static AccidentSeverity fromString(String value) {
    return AccidentSeverity.values.firstWhere(
      (severity) => severity.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AccidentSeverity.minor,
    );
  }

  /// Get color associated with severity level
  int get colorValue {
    switch (this) {
      case AccidentSeverity.minor:
        return 0xFFF59E0B; // Amber
      case AccidentSeverity.moderate:
        return 0xFFF97316; // Orange
      case AccidentSeverity.severe:
        return 0xFFEF4444; // Red
      case AccidentSeverity.critical:
        return 0xFFDC2626; // Dark Red
    }
  }

  /// Check if severity requires immediate emergency response
  bool get requiresEmergencyResponse {
    return level >= AccidentSeverity.moderate.level;
  }

  /// Check if severity requires hospital transport
  bool get requiresHospitalTransport {
    return level >= AccidentSeverity.severe.level;
  }
}

/// Accident analysis result
class AccidentAnalysis {
  final double probabilityScore; // 0.0 to 1.0
  final List<String> triggeredFactors; // Factors that triggered detection
  final Map<String, double> parameterScores; // Individual parameter scores
  final DateTime analysisTimestamp;
  final bool isFalsePositive;

  /// ML model confidence score (0.0–1.0). Null for legacy rule-based events.
  final double? mlConfidence;

  /// ML-predicted accident type: frontal, rollover, side, rear, false_positive.
  /// Null for legacy events.
  final String? predictedType;

  const AccidentAnalysis({
    required this.probabilityScore,
    required this.triggeredFactors,
    required this.parameterScores,
    required this.analysisTimestamp,
    this.isFalsePositive = false,
    this.mlConfidence,
    this.predictedType,
  });

  /// Create AccidentAnalysis from JSON
  factory AccidentAnalysis.fromJson(Map<String, dynamic> json) {
    return AccidentAnalysis(
      probabilityScore: (json['probabilityScore'] as num).toDouble(),
      triggeredFactors: List<String>.from(json['triggeredFactors'] as List),
      parameterScores: Map<String, double>.from(
        (json['parameterScores'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
      analysisTimestamp: DateTime.parse(json['analysisTimestamp'] as String),
      isFalsePositive: json['isFalsePositive'] as bool? ?? false,
      mlConfidence: json['mlConfidence'] != null
          ? (json['mlConfidence'] as num).toDouble()
          : null,
      predictedType: json['predictedType'] as String?,
    );
  }

  /// Convert AccidentAnalysis to JSON
  Map<String, dynamic> toJson() {
    return {
      'probabilityScore': probabilityScore,
      'triggeredFactors': triggeredFactors,
      'parameterScores': parameterScores,
      'analysisTimestamp': analysisTimestamp.toIso8601String(),
      'isFalsePositive': isFalsePositive,
      if (mlConfidence != null) 'mlConfidence': mlConfidence,
      if (predictedType != null) 'predictedType': predictedType,
    };
  }

  /// Check if analysis indicates confirmed accident
  bool get isConfirmedAccident {
    return probabilityScore >= 0.7 && !isFalsePositive;
  }

  /// Get severity based on probability score and factors
  AccidentSeverity get suggestedSeverity {
    if (probabilityScore >= 0.9) return AccidentSeverity.critical;
    if (probabilityScore >= 0.8) return AccidentSeverity.severe;
    if (probabilityScore >= 0.7) return AccidentSeverity.moderate;
    return AccidentSeverity.minor;
  }
}

/// Accident Event model containing all accident-related information
class AccidentEvent {
  final String eventId;
  final String deviceId;
  final DateTime detectionTime;
  final AccidentSeverity severity;
  final GpsLocation location;
  final List<VehicleParameters> parameterHistory;
  final AccidentAnalysis analysis;
  final EmergencyResponse? response;
  final Map<String, dynamic> metadata;

  const AccidentEvent({
    required this.eventId,
    required this.deviceId,
    required this.detectionTime,
    required this.severity,
    required this.location,
    required this.parameterHistory,
    required this.analysis,
    this.response,
    this.metadata = const {},
  });

  /// Create AccidentEvent from JSON
  factory AccidentEvent.fromJson(Map<String, dynamic> json) {
    return AccidentEvent(
      eventId: json['eventId'] as String,
      deviceId: json['deviceId'] as String,
      detectionTime: DateTime.parse(json['detectionTime'] as String),
      severity: AccidentSeverity.fromString(json['severity'] as String),
      location: GpsLocation.fromJson(json['location'] as Map<String, dynamic>),
      parameterHistory: (json['parameterHistory'] as List)
          .map((param) => VehicleParameters.fromJson(param as Map<String, dynamic>))
          .toList(),
      analysis: AccidentAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
      response: json['response'] != null
          ? EmergencyResponse.fromJson(json['response'] as Map<String, dynamic>)
          : null,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert AccidentEvent to JSON
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'deviceId': deviceId,
      'detectionTime': detectionTime.toIso8601String(),
      'severity': severity.name,
      'location': location.toJson(),
      'parameterHistory': parameterHistory.map((param) => param.toJson()).toList(),
      'analysis': analysis.toJson(),
      'response': response?.toJson(),
      'metadata': metadata,
    };
  }

  /// Create AccidentEvent from JSON string
  factory AccidentEvent.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return AccidentEvent.fromJson(json);
  }

  /// Convert AccidentEvent to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Get the most recent vehicle parameters
  VehicleParameters? get latestParameters {
    if (parameterHistory.isEmpty) return null;
    return parameterHistory.last;
  }

  /// Get maximum impact force from parameter history
  double get maxImpactForce {
    if (parameterHistory.isEmpty) return 0.0;
    return parameterHistory
        .map((param) => param.impactForce)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Get maximum acceleration from parameter history
  double get maxAcceleration {
    if (parameterHistory.isEmpty) return 0.0;
    return parameterHistory
        .map((param) => param.totalAcceleration)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Get speed at time of accident
  double get speedAtImpact {
    if (parameterHistory.isEmpty) return 0.0;
    // Find the parameter with highest impact force
    final impactParam = parameterHistory.reduce(
      (a, b) => a.impactForce > b.impactForce ? a : b,
    );
    return impactParam.speed;
  }

  /// Check if emergency response has been initiated
  bool get hasEmergencyResponse {
    return response != null;
  }

  /// Get time elapsed since detection
  Duration get timeSinceDetection {
    return DateTime.now().difference(detectionTime);
  }

  /// Create a copy with updated values
  AccidentEvent copyWith({
    String? eventId,
    String? deviceId,
    DateTime? detectionTime,
    AccidentSeverity? severity,
    GpsLocation? location,
    List<VehicleParameters>? parameterHistory,
    AccidentAnalysis? analysis,
    EmergencyResponse? response,
    Map<String, dynamic>? metadata,
  }) {
    return AccidentEvent(
      eventId: eventId ?? this.eventId,
      deviceId: deviceId ?? this.deviceId,
      detectionTime: detectionTime ?? this.detectionTime,
      severity: severity ?? this.severity,
      location: location ?? this.location,
      parameterHistory: parameterHistory ?? this.parameterHistory,
      analysis: analysis ?? this.analysis,
      response: response ?? this.response,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create summary for emergency services
  Map<String, dynamic> createEmergencySummary() {
    return {
      'eventId': eventId,
      'severity': severity.displayName,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'address': metadata['address'] ?? 'Unknown location',
      },
      'vehicleInfo': {
        'speed': speedAtImpact,
        'maxImpact': maxImpactForce,
        'maxAcceleration': maxAcceleration,
      },
      'timestamp': detectionTime.toIso8601String(),
      'confidence': analysis.probabilityScore,
      'factors': analysis.triggeredFactors,
    };
  }

  @override
  String toString() {
    return 'AccidentEvent(id: $eventId, severity: ${severity.displayName}, '
           'location: $location, time: $detectionTime, '
           'confidence: ${(analysis.probabilityScore * 100).toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccidentEvent &&
        other.eventId == eventId &&
        other.deviceId == deviceId &&
        other.detectionTime == detectionTime &&
        other.severity == severity &&
        other.location == location;
  }

  @override
  int get hashCode {
    return eventId.hashCode ^
        deviceId.hashCode ^
        detectionTime.hashCode ^
        severity.hashCode ^
        location.hashCode;
  }
}

/// Extension for accident event utilities
extension AccidentEventExtension on AccidentEvent {
  /// Generate incident report for insurance
  Map<String, dynamic> generateIncidentReport() {
    return {
      'incidentId': eventId,
      'dateTime': detectionTime.toIso8601String(),
      'location': {
        'coordinates': '${location.latitude}, ${location.longitude}',
        'address': metadata['address'] ?? 'Address not available',
      },
      'severity': severity.displayName,
      'vehicleData': {
        'speedAtImpact': '${speedAtImpact.toStringAsFixed(1)} km/h',
        'maxImpactForce': '${maxImpactForce.toStringAsFixed(2)}G',
        'maxAcceleration': '${maxAcceleration.toStringAsFixed(2)}G',
      },
      'analysis': {
        'confidence': '${(analysis.probabilityScore * 100).toStringAsFixed(1)}%',
        'triggeredFactors': analysis.triggeredFactors,
        'isFalsePositive': analysis.isFalsePositive,
      },
      'emergencyResponse': response?.toJson(),
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Check if event requires immediate attention
  bool get requiresImmediateAttention {
    return severity.requiresEmergencyResponse && 
           timeSinceDetection.inMinutes < 30 &&
           !analysis.isFalsePositive;
  }
}