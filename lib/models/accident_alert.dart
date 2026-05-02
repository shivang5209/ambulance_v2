import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'position.dart';

part 'accident_alert.g.dart';

enum AccidentSeverity {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('critical')
  critical,
}

enum AccidentStatus {
  @JsonValue('reported')
  reported,
  @JsonValue('dispatched')
  dispatched,
  @JsonValue('en_route')
  enRoute,
  @JsonValue('at_scene')
  atScene,
  @JsonValue('resolved')
  resolved,
  @JsonValue('cancelled')
  cancelled,
}

@JsonSerializable()
class AccidentAlert extends Equatable {
  final String id;
  final Position location;
  final AccidentSeverity severity;
  final AccidentStatus status;
  final DateTime timestamp;
  final String? description;
  final List<String> attachedImages;
  final String? reportedBy;
  final String? assignedAmbulanceId;
  final String? assignedHospitalId;
  final int? estimatedVictims;
  final Map<String, dynamic> additionalInfo;
  final DateTime? responseTime;
  final DateTime? arrivalTime;
  final DateTime? resolvedTime;

  const AccidentAlert({
    required this.id,
    required this.location,
    required this.severity,
    required this.status,
    required this.timestamp,
    this.description,
    this.attachedImages = const [],
    this.reportedBy,
    this.assignedAmbulanceId,
    this.assignedHospitalId,
    this.estimatedVictims,
    this.additionalInfo = const {},
    this.responseTime,
    this.arrivalTime,
    this.resolvedTime,
  });

  factory AccidentAlert.fromJson(Map<String, dynamic> json) => _$AccidentAlertFromJson(json);
  Map<String, dynamic> toJson() => _$AccidentAlertToJson(this);

  AccidentAlert copyWith({
    String? id,
    Position? location,
    AccidentSeverity? severity,
    AccidentStatus? status,
    DateTime? timestamp,
    String? description,
    List<String>? attachedImages,
    String? reportedBy,
    String? assignedAmbulanceId,
    String? assignedHospitalId,
    int? estimatedVictims,
    Map<String, dynamic>? additionalInfo,
    DateTime? responseTime,
    DateTime? arrivalTime,
    DateTime? resolvedTime,
  }) {
    return AccidentAlert(
      id: id ?? this.id,
      location: location ?? this.location,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      attachedImages: attachedImages ?? this.attachedImages,
      reportedBy: reportedBy ?? this.reportedBy,
      assignedAmbulanceId: assignedAmbulanceId ?? this.assignedAmbulanceId,
      assignedHospitalId: assignedHospitalId ?? this.assignedHospitalId,
      estimatedVictims: estimatedVictims ?? this.estimatedVictims,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      responseTime: responseTime ?? this.responseTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      resolvedTime: resolvedTime ?? this.resolvedTime,
    );
  }

  String get severityDisplayName {
    switch (severity) {
      case AccidentSeverity.low:
        return 'Low';
      case AccidentSeverity.medium:
        return 'Medium';
      case AccidentSeverity.high:
        return 'High';
      case AccidentSeverity.critical:
        return 'Critical';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case AccidentStatus.reported:
        return 'Reported';
      case AccidentStatus.dispatched:
        return 'Dispatched';
      case AccidentStatus.enRoute:
        return 'En Route';
      case AccidentStatus.atScene:
        return 'At Scene';
      case AccidentStatus.resolved:
        return 'Resolved';
      case AccidentStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive => status != AccidentStatus.resolved && 
                       status != AccidentStatus.cancelled;

  bool get isAssigned => assignedAmbulanceId != null;

  /// Calculate age of the accident in minutes
  int get ageInMinutes {
    return DateTime.now().difference(timestamp).inMinutes;
  }

  /// Calculate response time in minutes (if ambulance was dispatched)
  int? get responseTimeInMinutes {
    if (responseTime == null) return null;
    return responseTime!.difference(timestamp).inMinutes;
  }

  /// Calculate arrival time in minutes (if ambulance arrived)
  int? get arrivalTimeInMinutes {
    if (arrivalTime == null || responseTime == null) return null;
    return arrivalTime!.difference(responseTime!).inMinutes;
  }

  /// Calculate total resolution time in minutes
  int? get totalResolutionTimeInMinutes {
    if (resolvedTime == null) return null;
    return resolvedTime!.difference(timestamp).inMinutes;
  }

  /// Get priority score for sorting (higher = more urgent)
  int get priorityScore {
    int score = 0;
    
    // Severity scoring
    switch (severity) {
      case AccidentSeverity.critical:
        score += 100;
        break;
      case AccidentSeverity.high:
        score += 75;
        break;
      case AccidentSeverity.medium:
        score += 50;
        break;
      case AccidentSeverity.low:
        score += 25;
        break;
    }
    
    // Age penalty (older accidents get lower priority)
    score -= ageInMinutes;
    
    // Unassigned accidents get higher priority
    if (!isAssigned) score += 20;
    
    return score;
  }

  @override
  List<Object?> get props => [
        id,
        location,
        severity,
        status,
        timestamp,
        description,
        attachedImages,
        reportedBy,
        assignedAmbulanceId,
        assignedHospitalId,
        estimatedVictims,
        additionalInfo,
        responseTime,
        arrivalTime,
        resolvedTime,
      ];

  @override
  String toString() {
    return 'AccidentAlert(id: $id, severity: $severity, status: $status, timestamp: $timestamp)';
  }
}