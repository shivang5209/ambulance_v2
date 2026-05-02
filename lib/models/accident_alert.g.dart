// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accident_alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccidentAlert _$AccidentAlertFromJson(Map<String, dynamic> json) =>
    AccidentAlert(
      id: json['id'] as String,
      location: Position.fromJson(json['location'] as Map<String, dynamic>),
      severity: $enumDecode(_$AccidentSeverityEnumMap, json['severity']),
      status: $enumDecode(_$AccidentStatusEnumMap, json['status']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      description: json['description'] as String?,
      attachedImages:
          (json['attachedImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      reportedBy: json['reportedBy'] as String?,
      assignedAmbulanceId: json['assignedAmbulanceId'] as String?,
      assignedHospitalId: json['assignedHospitalId'] as String?,
      estimatedVictims: (json['estimatedVictims'] as num?)?.toInt(),
      additionalInfo:
          json['additionalInfo'] as Map<String, dynamic>? ?? const {},
      responseTime: json['responseTime'] == null
          ? null
          : DateTime.parse(json['responseTime'] as String),
      arrivalTime: json['arrivalTime'] == null
          ? null
          : DateTime.parse(json['arrivalTime'] as String),
      resolvedTime: json['resolvedTime'] == null
          ? null
          : DateTime.parse(json['resolvedTime'] as String),
    );

Map<String, dynamic> _$AccidentAlertToJson(AccidentAlert instance) =>
    <String, dynamic>{
      'id': instance.id,
      'location': instance.location,
      'severity': _$AccidentSeverityEnumMap[instance.severity]!,
      'status': _$AccidentStatusEnumMap[instance.status]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'description': instance.description,
      'attachedImages': instance.attachedImages,
      'reportedBy': instance.reportedBy,
      'assignedAmbulanceId': instance.assignedAmbulanceId,
      'assignedHospitalId': instance.assignedHospitalId,
      'estimatedVictims': instance.estimatedVictims,
      'additionalInfo': instance.additionalInfo,
      'responseTime': instance.responseTime?.toIso8601String(),
      'arrivalTime': instance.arrivalTime?.toIso8601String(),
      'resolvedTime': instance.resolvedTime?.toIso8601String(),
    };

const _$AccidentSeverityEnumMap = {
  AccidentSeverity.low: 'low',
  AccidentSeverity.medium: 'medium',
  AccidentSeverity.high: 'high',
  AccidentSeverity.critical: 'critical',
};

const _$AccidentStatusEnumMap = {
  AccidentStatus.reported: 'reported',
  AccidentStatus.dispatched: 'dispatched',
  AccidentStatus.enRoute: 'en_route',
  AccidentStatus.atScene: 'at_scene',
  AccidentStatus.resolved: 'resolved',
  AccidentStatus.cancelled: 'cancelled',
};
