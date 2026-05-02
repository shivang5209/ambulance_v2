import 'dart:convert';
import 'emergency_response.dart';

/// Medical information for emergency situations
class MedicalInformation {
  final String? bloodType;
  final List<String> allergies;
  final List<String> medications;
  final List<String> medicalConditions;
  final String? emergencyMedicalNotes;
  final String? doctorContact;
  final String? insuranceInfo;

  const MedicalInformation({
    this.bloodType,
    this.allergies = const [],
    this.medications = const [],
    this.medicalConditions = const [],
    this.emergencyMedicalNotes,
    this.doctorContact,
    this.insuranceInfo,
  });

  /// Create MedicalInformation from JSON
  factory MedicalInformation.fromJson(Map<String, dynamic> json) {
    return MedicalInformation(
      bloodType: json['bloodType'] as String?,
      allergies: List<String>.from(json['allergies'] as List? ?? []),
      medications: List<String>.from(json['medications'] as List? ?? []),
      medicalConditions: List<String>.from(json['medicalConditions'] as List? ?? []),
      emergencyMedicalNotes: json['emergencyMedicalNotes'] as String?,
      doctorContact: json['doctorContact'] as String?,
      insuranceInfo: json['insuranceInfo'] as String?,
    );
  }

  /// Convert MedicalInformation to JSON
  Map<String, dynamic> toJson() {
    return {
      'bloodType': bloodType,
      'allergies': allergies,
      'medications': medications,
      'medicalConditions': medicalConditions,
      'emergencyMedicalNotes': emergencyMedicalNotes,
      'doctorContact': doctorContact,
      'insuranceInfo': insuranceInfo,
    };
  }

  /// Check if medical information has critical data
  bool get hasCriticalInfo {
    return allergies.isNotEmpty || 
           medicalConditions.isNotEmpty || 
           emergencyMedicalNotes?.isNotEmpty == true;
  }

  /// Create a copy with updated values
  MedicalInformation copyWith({
    String? bloodType,
    List<String>? allergies,
    List<String>? medications,
    List<String>? medicalConditions,
    String? emergencyMedicalNotes,
    String? doctorContact,
    String? insuranceInfo,
  }) {
    return MedicalInformation(
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      emergencyMedicalNotes: emergencyMedicalNotes ?? this.emergencyMedicalNotes,
      doctorContact: doctorContact ?? this.doctorContact,
      insuranceInfo: insuranceInfo ?? this.insuranceInfo,
    );
  }

  @override
  String toString() {
    return 'MedicalInformation(bloodType: $bloodType, allergies: ${allergies.length}, conditions: ${medicalConditions.length})';
  }
}

/// Vehicle registration information
class VehicleRegistration {
  final String vehicleId;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? vin;
  final String color;
  final String? deviceId; // Associated IoT device
  final bool isActive;
  final DateTime registeredAt;
  final Map<String, dynamic> additionalInfo;

  const VehicleRegistration({
    required this.vehicleId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.vin,
    required this.color,
    this.deviceId,
    this.isActive = true,
    required this.registeredAt,
    this.additionalInfo = const {},
  });

  /// Create VehicleRegistration from JSON
  factory VehicleRegistration.fromJson(Map<String, dynamic> json) {
    return VehicleRegistration(
      vehicleId: json['vehicleId'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      licensePlate: json['licensePlate'] as String,
      vin: json['vin'] as String?,
      color: json['color'] as String,
      deviceId: json['deviceId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      additionalInfo: Map<String, dynamic>.from(
        json['additionalInfo'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert VehicleRegistration to JSON
  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'make': make,
      'model': model,
      'year': year,
      'licensePlate': licensePlate,
      'vin': vin,
      'color': color,
      'deviceId': deviceId,
      'isActive': isActive,
      'registeredAt': registeredAt.toIso8601String(),
      'additionalInfo': additionalInfo,
    };
  }

  /// Get vehicle display name
  String get displayName {
    return '$year $make $model';
  }

  /// Check if vehicle has associated IoT device
  bool get hasDevice {
    return deviceId != null && deviceId!.isNotEmpty;
  }

  /// Validate vehicle information
  bool get isValid {
    return vehicleId.isNotEmpty &&
           make.isNotEmpty &&
           model.isNotEmpty &&
           year > 1900 && year <= DateTime.now().year + 1 &&
           licensePlate.isNotEmpty &&
           color.isNotEmpty;
  }

  /// Create a copy with updated values
  VehicleRegistration copyWith({
    String? vehicleId,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? vin,
    String? color,
    String? deviceId,
    bool? isActive,
    DateTime? registeredAt,
    Map<String, dynamic>? additionalInfo,
  }) {
    return VehicleRegistration(
      vehicleId: vehicleId ?? this.vehicleId,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      licensePlate: licensePlate ?? this.licensePlate,
      vin: vin ?? this.vin,
      color: color ?? this.color,
      deviceId: deviceId ?? this.deviceId,
      isActive: isActive ?? this.isActive,
      registeredAt: registeredAt ?? this.registeredAt,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  @override
  String toString() {
    return 'VehicleRegistration($displayName - $licensePlate)';
  }
}

/// User preferences for the application
class UserPreferences {
  final bool enableNotifications;
  final bool enableLocationSharing;
  final bool enableAutoEmergencyCall;
  final String preferredLanguage;
  final String themeMode; // 'light', 'dark', 'system'
  final double sensitivityLevel; // 0.0 to 1.0
  final List<String> preferredEmergencyServices;
  final Map<String, dynamic> customSettings;

  const UserPreferences({
    this.enableNotifications = true,
    this.enableLocationSharing = true,
    this.enableAutoEmergencyCall = true,
    this.preferredLanguage = 'en',
    this.themeMode = 'system',
    this.sensitivityLevel = 0.7,
    this.preferredEmergencyServices = const [],
    this.customSettings = const {},
  });

  /// Create UserPreferences from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      enableNotifications: json['enableNotifications'] as bool? ?? true,
      enableLocationSharing: json['enableLocationSharing'] as bool? ?? true,
      enableAutoEmergencyCall: json['enableAutoEmergencyCall'] as bool? ?? true,
      preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
      themeMode: json['themeMode'] as String? ?? 'system',
      sensitivityLevel: (json['sensitivityLevel'] as num?)?.toDouble() ?? 0.7,
      preferredEmergencyServices: List<String>.from(
        json['preferredEmergencyServices'] as List? ?? [],
      ),
      customSettings: Map<String, dynamic>.from(
        json['customSettings'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert UserPreferences to JSON
  Map<String, dynamic> toJson() {
    return {
      'enableNotifications': enableNotifications,
      'enableLocationSharing': enableLocationSharing,
      'enableAutoEmergencyCall': enableAutoEmergencyCall,
      'preferredLanguage': preferredLanguage,
      'themeMode': themeMode,
      'sensitivityLevel': sensitivityLevel,
      'preferredEmergencyServices': preferredEmergencyServices,
      'customSettings': customSettings,
    };
  }

  /// Create a copy with updated values
  UserPreferences copyWith({
    bool? enableNotifications,
    bool? enableLocationSharing,
    bool? enableAutoEmergencyCall,
    String? preferredLanguage,
    String? themeMode,
    double? sensitivityLevel,
    List<String>? preferredEmergencyServices,
    Map<String, dynamic>? customSettings,
  }) {
    return UserPreferences(
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableLocationSharing: enableLocationSharing ?? this.enableLocationSharing,
      enableAutoEmergencyCall: enableAutoEmergencyCall ?? this.enableAutoEmergencyCall,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      themeMode: themeMode ?? this.themeMode,
      sensitivityLevel: sensitivityLevel ?? this.sensitivityLevel,
      preferredEmergencyServices: preferredEmergencyServices ?? this.preferredEmergencyServices,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// User Profile model containing all user information
class UserProfile {
  final String userId;
  final String name;
  final String phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;
  final String? profileImageUrl;
  final List<EmergencyContact> emergencyContacts;
  final List<VehicleRegistration> vehicles;
  final UserPreferences preferences;
  final MedicalInformation medicalInfo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const UserProfile({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.profileImageUrl,
    this.emergencyContacts = const [],
    this.vehicles = const [],
    required this.preferences,
    required this.medicalInfo,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  /// Create UserProfile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      dateOfBirth: json['dateOfBirth'] != null 
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      profileImageUrl: json['profileImageUrl'] as String?,
      emergencyContacts: (json['emergencyContacts'] as List? ?? [])
          .map((contact) => EmergencyContact.fromJson(contact as Map<String, dynamic>))
          .toList(),
      vehicles: (json['vehicles'] as List? ?? [])
          .map((vehicle) => VehicleRegistration.fromJson(vehicle as Map<String, dynamic>))
          .toList(),
      preferences: UserPreferences.fromJson(
        json['preferences'] as Map<String, dynamic>? ?? {},
      ),
      medicalInfo: MedicalInformation.fromJson(
        json['medicalInfo'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert UserProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'emergencyContacts': emergencyContacts.map((contact) => contact.toJson()).toList(),
      'vehicles': vehicles.map((vehicle) => vehicle.toJson()).toList(),
      'preferences': preferences.toJson(),
      'medicalInfo': medicalInfo.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create UserProfile from JSON string
  factory UserProfile.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return UserProfile.fromJson(json);
  }

  /// Convert UserProfile to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Validate required fields for profile completeness
  bool get isComplete {
    return userId.isNotEmpty &&
           name.isNotEmpty &&
           phoneNumber.isNotEmpty &&
           _isValidPhoneNumber(phoneNumber) &&
           emergencyContacts.isNotEmpty &&
           emergencyContacts.every((contact) => contact.isValid);
  }

  /// Check if phone number format is valid
  bool _isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,15}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Get primary emergency contact
  EmergencyContact? get primaryEmergencyContact {
    try {
      return emergencyContacts.firstWhere((contact) => contact.isPrimary);
    } catch (e) {
      return emergencyContacts.isNotEmpty ? emergencyContacts.first : null;
    }
  }

  /// Get active vehicles (with IoT devices)
  List<VehicleRegistration> get activeVehicles {
    return vehicles.where((vehicle) => vehicle.isActive && vehicle.hasDevice).toList();
  }

  /// Get all device IDs from vehicles
  List<String> get deviceIds {
    return vehicles
        .where((vehicle) => vehicle.hasDevice)
        .map((vehicle) => vehicle.deviceId!)
        .toList();
  }

  /// Check if user has any registered vehicles
  bool get hasVehicles {
    return vehicles.isNotEmpty;
  }

  /// Check if user has emergency contacts
  bool get hasEmergencyContacts {
    return emergencyContacts.isNotEmpty;
  }

  /// Add emergency contact
  UserProfile addEmergencyContact(EmergencyContact contact) {
    final updatedContacts = List<EmergencyContact>.from(emergencyContacts)..add(contact);
    return copyWith(
      emergencyContacts: updatedContacts,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove emergency contact
  UserProfile removeEmergencyContact(String contactId) {
    final updatedContacts = emergencyContacts
        .where((contact) => contact.id != contactId)
        .toList();
    return copyWith(
      emergencyContacts: updatedContacts,
      updatedAt: DateTime.now(),
    );
  }

  /// Update emergency contact
  UserProfile updateEmergencyContact(String contactId, EmergencyContact updatedContact) {
    final updatedContacts = emergencyContacts.map((contact) {
      return contact.id == contactId ? updatedContact : contact;
    }).toList();
    return copyWith(
      emergencyContacts: updatedContacts,
      updatedAt: DateTime.now(),
    );
  }

  /// Add vehicle
  UserProfile addVehicle(VehicleRegistration vehicle) {
    final updatedVehicles = List<VehicleRegistration>.from(vehicles)..add(vehicle);
    return copyWith(
      vehicles: updatedVehicles,
      updatedAt: DateTime.now(),
    );
  }

  /// Remove vehicle
  UserProfile removeVehicle(String vehicleId) {
    final updatedVehicles = vehicles
        .where((vehicle) => vehicle.vehicleId != vehicleId)
        .toList();
    return copyWith(
      vehicles: updatedVehicles,
      updatedAt: DateTime.now(),
    );
  }

  /// Update vehicle
  UserProfile updateVehicle(String vehicleId, VehicleRegistration updatedVehicle) {
    final updatedVehicles = vehicles.map((vehicle) {
      return vehicle.vehicleId == vehicleId ? updatedVehicle : vehicle;
    }).toList();
    return copyWith(
      vehicles: updatedVehicles,
      updatedAt: DateTime.now(),
    );
  }

  /// Create a copy with updated values
  UserProfile copyWith({
    String? userId,
    String? name,
    String? phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    String? profileImageUrl,
    List<EmergencyContact>? emergencyContacts,
    List<VehicleRegistration>? vehicles,
    UserPreferences? preferences,
    MedicalInformation? medicalInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      vehicles: vehicles ?? this.vehicles,
      preferences: preferences ?? this.preferences,
      medicalInfo: medicalInfo ?? this.medicalInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $userId, name: $name, vehicles: ${vehicles.length}, contacts: ${emergencyContacts.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.userId == userId &&
        other.name == name &&
        other.phoneNumber == phoneNumber &&
        other.email == email;
  }

  @override
  int get hashCode {
    return userId.hashCode ^ name.hashCode ^ phoneNumber.hashCode ^ email.hashCode;
  }
}

/// Extension for user profile utilities
extension UserProfileExtension on UserProfile {
  /// Generate emergency summary for first responders
  Map<String, dynamic> generateEmergencySummary() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'emergencyContacts': emergencyContacts.map((contact) => {
        'name': contact.name,
        'phone': contact.phoneNumber,
        'relationship': contact.relationship,
      }).toList(),
      'medicalInfo': {
        'bloodType': medicalInfo.bloodType,
        'allergies': medicalInfo.allergies,
        'conditions': medicalInfo.medicalConditions,
        'medications': medicalInfo.medications,
        'notes': medicalInfo.emergencyMedicalNotes,
      },
      'vehicles': activeVehicles.map((vehicle) => {
        'make': vehicle.make,
        'model': vehicle.model,
        'year': vehicle.year,
        'licensePlate': vehicle.licensePlate,
        'color': vehicle.color,
      }).toList(),
    };
  }

  /// Check if profile needs attention (incomplete or outdated)
  bool get needsAttention {
    final daysSinceUpdate = DateTime.now().difference(updatedAt).inDays;
    return !isComplete || daysSinceUpdate > 90; // 3 months
  }
}