import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'position.dart';

part 'ambulance.g.dart';

enum AmbulanceStatus {
  @JsonValue('available')
  available,
  @JsonValue('busy')
  busy,
  @JsonValue('offline')
  offline,
  @JsonValue('en_route')
  enRoute,
  @JsonValue('at_scene')
  atScene,
  @JsonValue('to_hospital')
  toHospital,
  @JsonValue('maintenance')
  maintenance,
}

extension AmbulanceStatusExtension on AmbulanceStatus {
  String get statusDisplayName {
    switch (this) {
      case AmbulanceStatus.available:
        return 'Available';
      case AmbulanceStatus.busy:
        return 'Busy';
      case AmbulanceStatus.offline:
        return 'Offline';
      case AmbulanceStatus.enRoute:
        return 'En Route';
      case AmbulanceStatus.atScene:
        return 'At Scene';
      case AmbulanceStatus.toHospital:
        return 'To Hospital';
      case AmbulanceStatus.maintenance:
        return 'Maintenance';
    }
  }
}

@JsonSerializable()
class Ambulance extends Equatable {
  final String id;
  final String plateNumber;
  final String? driverName;
  final String? driverId;
  final Position? currentLocation;
  final AmbulanceStatus status;
  final String? assignedHospitalId;
  final String? currentIncidentId;
  final DateTime lastUpdate;
  final Map<String, dynamic> equipment;
  final double? fuelLevel;
  final String? vehicleType;
  final int? capacity;

  const Ambulance({
    required this.id,
    required this.plateNumber,
    this.driverName,
    this.driverId,
    this.currentLocation,
    required this.status,
    this.assignedHospitalId,
    this.currentIncidentId,
    required this.lastUpdate,
    this.equipment = const {},
    this.fuelLevel,
    this.vehicleType,
    this.capacity,
  });

  factory Ambulance.fromJson(Map<String, dynamic> json) => _$AmbulanceFromJson(json);
  Map<String, dynamic> toJson() => _$AmbulanceToJson(this);

  Ambulance copyWith({
    String? id,
    String? plateNumber,
    String? driverName,
    String? driverId,
    Position? currentLocation,
    AmbulanceStatus? status,
    String? assignedHospitalId,
    String? currentIncidentId,
    DateTime? lastUpdate,
    Map<String, dynamic>? equipment,
    double? fuelLevel,
    String? vehicleType,
    int? capacity,
  }) {
    return Ambulance(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
      currentLocation: currentLocation ?? this.currentLocation,
      status: status ?? this.status,
      assignedHospitalId: assignedHospitalId ?? this.assignedHospitalId,
      currentIncidentId: currentIncidentId ?? this.currentIncidentId,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      equipment: equipment ?? this.equipment,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      vehicleType: vehicleType ?? this.vehicleType,
      capacity: capacity ?? this.capacity,
    );
  }

  bool get isAvailable => status == AmbulanceStatus.available;
  bool get isBusy => status == AmbulanceStatus.busy || 
                     status == AmbulanceStatus.enRoute || 
                     status == AmbulanceStatus.atScene || 
                     status == AmbulanceStatus.toHospital;
  bool get isOffline => status == AmbulanceStatus.offline;
  bool get isInMaintenance => status == AmbulanceStatus.maintenance;

  String get statusDisplayName {
    switch (status) {
      case AmbulanceStatus.available:
        return 'Available';
      case AmbulanceStatus.busy:
        return 'Busy';
      case AmbulanceStatus.offline:
        return 'Offline';
      case AmbulanceStatus.enRoute:
        return 'En Route';
      case AmbulanceStatus.atScene:
        return 'At Scene';
      case AmbulanceStatus.toHospital:
        return 'To Hospital';
      case AmbulanceStatus.maintenance:
        return 'Maintenance';
    }
  }

  /// Calculate distance to a position in meters
  double? distanceTo(Position position) {
    return currentLocation?.distanceTo(position);
  }

  /// Check if ambulance location is recent (within last 5 minutes)
  bool get hasRecentLocation {
    if (currentLocation == null) return false;
    final now = DateTime.now();
    final locationAge = now.difference(currentLocation!.timestamp);
    return locationAge.inMinutes <= 5;
  }

  @override
  List<Object?> get props => [
        id,
        plateNumber,
        driverName,
        driverId,
        currentLocation,
        status,
        assignedHospitalId,
        currentIncidentId,
        lastUpdate,
        equipment,
        fuelLevel,
        vehicleType,
        capacity,
      ];

  @override
  String toString() {
    return 'Ambulance(id: $id, plate: $plateNumber, status: $status)';
  }
}