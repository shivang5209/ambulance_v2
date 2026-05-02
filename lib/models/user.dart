import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

enum UserRole {
  @JsonValue('driver')
  driver,
  @JsonValue('dispatcher')
  dispatcher,
  @JsonValue('hospital_staff')
  hospitalStaff,
  @JsonValue('admin')
  admin,
  @JsonValue('citizen')
  citizen,
}

@JsonSerializable()
class User extends Equatable {
  final String id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final UserRole role;
  final String? hospitalId;
  final Map<String, dynamic> preferences;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    required this.role,
    this.hospitalId,
    this.preferences = const {},
    this.isActive = true,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    UserRole? role,
    String? hospitalId,
    Map<String, dynamic>? preferences,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      hospitalId: hospitalId ?? this.hospitalId,
      preferences: preferences ?? this.preferences,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username;
  }

  bool get isDriver => role == UserRole.driver;
  bool get isDispatcher => role == UserRole.dispatcher;
  bool get isHospitalStaff => role == UserRole.hospitalStaff;
  bool get isAdmin => role == UserRole.admin;
  bool get isCitizen => role == UserRole.citizen;

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        firstName,
        lastName,
        role,
        hospitalId,
        preferences,
        isActive,
        lastLogin,
        createdAt,
        updatedAt,
      ];
}