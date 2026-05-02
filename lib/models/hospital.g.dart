// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hospital.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Hospital _$HospitalFromJson(Map<String, dynamic> json) => Hospital(
  id: json['id'] as String,
  name: json['name'] as String,
  address: json['address'] as String,
  phoneNumber: json['phoneNumber'] as String?,
  emergencyContact: json['emergencyContact'] as String?,
  location: Position.fromJson(json['location'] as Map<String, dynamic>),
  ambulanceIds:
      (json['ambulanceIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  facilities: json['facilities'] as Map<String, dynamic>? ?? const {},
  bedCapacity: (json['bedCapacity'] as num?)?.toInt(),
  availableBeds: (json['availableBeds'] as num?)?.toInt(),
  isActive: json['isActive'] as bool? ?? true,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$HospitalToJson(Hospital instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'address': instance.address,
  'phoneNumber': instance.phoneNumber,
  'emergencyContact': instance.emergencyContact,
  'location': instance.location,
  'ambulanceIds': instance.ambulanceIds,
  'facilities': instance.facilities,
  'bedCapacity': instance.bedCapacity,
  'availableBeds': instance.availableBeds,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
