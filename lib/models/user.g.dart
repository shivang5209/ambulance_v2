// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['id'] as String,
  username: json['username'] as String? ?? '',
  email: json['email'] as String?,
  firstName: json['firstName'] as String?,
  lastName: json['lastName'] as String?,
  role: $enumDecodeNullable(_$UserRoleEnumMap, json['role']) ?? UserRole.citizen,
  hospitalId: json['hospitalId'] as String?,
  preferences: json['preferences'] as Map<String, dynamic>? ?? const {},
  isActive: json['isActive'] as bool? ?? true,
  lastLogin: json['lastLogin'] == null
      ? null
      : DateTime.parse(json['lastLogin'] as String),
  createdAt: json['createdAt'] == null
      ? DateTime.now()
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? DateTime.now()
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'email': instance.email,
  'firstName': instance.firstName,
  'lastName': instance.lastName,
  'role': _$UserRoleEnumMap[instance.role]!,
  'hospitalId': instance.hospitalId,
  'preferences': instance.preferences,
  'isActive': instance.isActive,
  'lastLogin': instance.lastLogin?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$UserRoleEnumMap = {
  UserRole.driver: 'driver',
  UserRole.dispatcher: 'dispatcher',
  UserRole.hospitalStaff: 'hospital_staff',
  UserRole.admin: 'admin',
  UserRole.citizen: 'citizen',
};
