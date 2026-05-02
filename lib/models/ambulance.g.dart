// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ambulance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ambulance _$AmbulanceFromJson(Map<String, dynamic> json) => Ambulance(
  id: json['id'] as String,
  plateNumber: json['plateNumber'] as String,
  driverName: json['driverName'] as String?,
  driverId: json['driverId'] as String?,
  currentLocation: json['currentLocation'] == null
      ? null
      : Position.fromJson(json['currentLocation'] as Map<String, dynamic>),
  status: $enumDecode(_$AmbulanceStatusEnumMap, json['status']),
  assignedHospitalId: json['assignedHospitalId'] as String?,
  currentIncidentId: json['currentIncidentId'] as String?,
  lastUpdate: DateTime.parse(json['lastUpdate'] as String),
  equipment: json['equipment'] as Map<String, dynamic>? ?? const {},
  fuelLevel: (json['fuelLevel'] as num?)?.toDouble(),
  vehicleType: json['vehicleType'] as String?,
  capacity: (json['capacity'] as num?)?.toInt(),
);

Map<String, dynamic> _$AmbulanceToJson(Ambulance instance) => <String, dynamic>{
  'id': instance.id,
  'plateNumber': instance.plateNumber,
  'driverName': instance.driverName,
  'driverId': instance.driverId,
  'currentLocation': instance.currentLocation,
  'status': _$AmbulanceStatusEnumMap[instance.status]!,
  'assignedHospitalId': instance.assignedHospitalId,
  'currentIncidentId': instance.currentIncidentId,
  'lastUpdate': instance.lastUpdate.toIso8601String(),
  'equipment': instance.equipment,
  'fuelLevel': instance.fuelLevel,
  'vehicleType': instance.vehicleType,
  'capacity': instance.capacity,
};

const _$AmbulanceStatusEnumMap = {
  AmbulanceStatus.available: 'available',
  AmbulanceStatus.busy: 'busy',
  AmbulanceStatus.offline: 'offline',
  AmbulanceStatus.enRoute: 'en_route',
  AmbulanceStatus.atScene: 'at_scene',
  AmbulanceStatus.toHospital: 'to_hospital',
  AmbulanceStatus.maintenance: 'maintenance',
};
