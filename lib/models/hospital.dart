import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'position.dart';

part 'hospital.g.dart';

@JsonSerializable()
class Hospital extends Equatable {
  final String id;
  final String name;
  final String address;
  final String? phoneNumber;
  final String? emergencyContact;
  final Position location;
  final List<String> ambulanceIds;
  final Map<String, dynamic> facilities;
  final int? bedCapacity;
  final int? availableBeds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Hospital({
    required this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    this.emergencyContact,
    required this.location,
    this.ambulanceIds = const [],
    this.facilities = const {},
    this.bedCapacity,
    this.availableBeds,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) => _$HospitalFromJson(json);
  Map<String, dynamic> toJson() => _$HospitalToJson(this);

  Hospital copyWith({
    String? id,
    String? name,
    String? address,
    String? phoneNumber,
    String? emergencyContact,
    Position? location,
    List<String>? ambulanceIds,
    Map<String, dynamic>? facilities,
    int? bedCapacity,
    int? availableBeds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Hospital(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      location: location ?? this.location,
      ambulanceIds: ambulanceIds ?? this.ambulanceIds,
      facilities: facilities ?? this.facilities,
      bedCapacity: bedCapacity ?? this.bedCapacity,
      availableBeds: availableBeds ?? this.availableBeds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate distance to a position in meters
  double distanceTo(Position position) {
    return location.distanceTo(position);
  }

  /// Check if hospital has available beds
  bool get hasBeds {
    if (availableBeds == null || bedCapacity == null) return true;
    return availableBeds! > 0;
  }

  /// Get bed occupancy percentage
  double? get occupancyPercentage {
    if (availableBeds == null || bedCapacity == null || bedCapacity == 0) {
      return null;
    }
    final occupied = bedCapacity! - availableBeds!;
    return (occupied / bedCapacity!) * 100;
  }

  /// Check if hospital has specific facility
  bool hasFacility(String facilityName) {
    return facilities.containsKey(facilityName) && 
           facilities[facilityName] == true;
  }

  /// Get list of available facilities
  List<String> get availableFacilities {
    return facilities.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        phoneNumber,
        emergencyContact,
        location,
        ambulanceIds,
        facilities,
        bedCapacity,
        availableBeds,
        isActive,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Hospital(id: $id, name: $name, address: $address)';
  }
}