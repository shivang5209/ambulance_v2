import 'dart:convert';

/// Service provider types
enum ServiceProvider {
  ambulance('Ambulance', 'medical'),
  police('Police', 'law_enforcement'),
  fireService('Fire Service', 'fire_rescue'),
  towing('Towing Service', 'vehicle_recovery'),
  insurance('Insurance', 'claims');

  const ServiceProvider(this.displayName, this.category);

  final String displayName;
  final String category;

  /// Create ServiceProvider from string
  static ServiceProvider fromString(String value) {
    return ServiceProvider.values.firstWhere(
      (provider) => provider.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ServiceProvider.ambulance,
    );
  }

  /// Get icon name for UI
  String get iconName {
    switch (this) {
      case ServiceProvider.ambulance:
        return 'local_hospital';
      case ServiceProvider.police:
        return 'local_police';
      case ServiceProvider.fireService:
        return 'local_fire_department';
      case ServiceProvider.towing:
        return 'car_repair';
      case ServiceProvider.insurance:
        return 'assignment';
    }
  }
}

/// Response status for emergency services
enum ResponseStatus {
  initiated('Initiated', 0),
  dispatched('Dispatched', 1),
  enRoute('En Route', 2),
  onScene('On Scene', 3),
  completed('Completed', 4),
  cancelled('Cancelled', -1);

  const ResponseStatus(this.displayName, this.order);

  final String displayName;
  final int order;

  /// Create ResponseStatus from string
  static ResponseStatus fromString(String value) {
    return ResponseStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ResponseStatus.initiated,
    );
  }

  /// Get color for status
  int get colorValue {
    switch (this) {
      case ResponseStatus.initiated:
        return 0xFFF59E0B; // Amber
      case ResponseStatus.dispatched:
        return 0xFF3B82F6; // Blue
      case ResponseStatus.enRoute:
        return 0xFFF97316; // Orange
      case ResponseStatus.onScene:
        return 0xFF10B981; // Green
      case ResponseStatus.completed:
        return 0xFF22C55E; // Success Green
      case ResponseStatus.cancelled:
        return 0xFF64748B; // Gray
    }
  }

  /// Check if status is active (not completed or cancelled)
  bool get isActive {
    return this != ResponseStatus.completed && this != ResponseStatus.cancelled;
  }
}

/// Service status for individual service providers
class ServiceStatus {
  final ServiceProvider provider;
  final ResponseStatus status;
  final DateTime timestamp;
  final String? contactInfo;
  final String? estimatedArrival;
  final Map<String, dynamic> additionalInfo;

  const ServiceStatus({
    required this.provider,
    required this.status,
    required this.timestamp,
    this.contactInfo,
    this.estimatedArrival,
    this.additionalInfo = const {},
  });

  /// Create ServiceStatus from JSON
  factory ServiceStatus.fromJson(Map<String, dynamic> json) {
    return ServiceStatus(
      provider: ServiceProvider.fromString(json['provider'] as String),
      status: ResponseStatus.fromString(json['status'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      contactInfo: json['contactInfo'] as String?,
      estimatedArrival: json['estimatedArrival'] as String?,
      additionalInfo: Map<String, dynamic>.from(
        json['additionalInfo'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert ServiceStatus to JSON
  Map<String, dynamic> toJson() {
    return {
      'provider': provider.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'contactInfo': contactInfo,
      'estimatedArrival': estimatedArrival,
      'additionalInfo': additionalInfo,
    };
  }

  /// Create a copy with updated values
  ServiceStatus copyWith({
    ServiceProvider? provider,
    ResponseStatus? status,
    DateTime? timestamp,
    String? contactInfo,
    String? estimatedArrival,
    Map<String, dynamic>? additionalInfo,
  }) {
    return ServiceStatus(
      provider: provider ?? this.provider,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      contactInfo: contactInfo ?? this.contactInfo,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  @override
  String toString() {
    return 'ServiceStatus(${provider.displayName}: ${status.displayName})';
  }
}

/// Emergency Contact information
class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String relationship;
  final bool isPrimary;
  final Map<String, dynamic> additionalInfo;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.relationship,
    this.isPrimary = false,
    this.additionalInfo = const {},
  });

  /// Create EmergencyContact from JSON
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      relationship: json['relationship'] as String,
      isPrimary: json['isPrimary'] as bool? ?? false,
      additionalInfo: Map<String, dynamic>.from(
        json['additionalInfo'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert EmergencyContact to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'additionalInfo': additionalInfo,
    };
  }

  /// Validate contact information
  bool get isValid {
    return name.isNotEmpty && 
           phoneNumber.isNotEmpty && 
           relationship.isNotEmpty &&
           _isValidPhoneNumber(phoneNumber);
  }

  /// Check if phone number format is valid
  bool _isValidPhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,15}$');
    return phoneRegex.hasMatch(phone);
  }

  @override
  String toString() {
    return 'EmergencyContact($name - $relationship: $phoneNumber)';
  }
}

/// Emergency Response model containing response coordination information
class EmergencyResponse {
  final String responseId;
  final List<ServiceProvider> contactedServices;
  final List<EmergencyContact> notifiedContacts;
  final ResponseStatus status;
  final DateTime initiatedAt;
  final Map<String, ServiceStatus> serviceStatuses;
  final List<String> statusUpdates;
  final Map<String, dynamic> metadata;

  const EmergencyResponse({
    required this.responseId,
    required this.contactedServices,
    required this.notifiedContacts,
    required this.status,
    required this.initiatedAt,
    required this.serviceStatuses,
    this.statusUpdates = const [],
    this.metadata = const {},
  });

  /// Create EmergencyResponse from JSON
  factory EmergencyResponse.fromJson(Map<String, dynamic> json) {
    return EmergencyResponse(
      responseId: json['responseId'] as String,
      contactedServices: (json['contactedServices'] as List)
          .map((service) => ServiceProvider.fromString(service as String))
          .toList(),
      notifiedContacts: (json['notifiedContacts'] as List)
          .map((contact) => EmergencyContact.fromJson(contact as Map<String, dynamic>))
          .toList(),
      status: ResponseStatus.fromString(json['status'] as String),
      initiatedAt: DateTime.parse(json['initiatedAt'] as String),
      serviceStatuses: (json['serviceStatuses'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          ServiceStatus.fromJson(value as Map<String, dynamic>),
        ),
      ),
      statusUpdates: List<String>.from(json['statusUpdates'] as List? ?? []),
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert EmergencyResponse to JSON
  Map<String, dynamic> toJson() {
    return {
      'responseId': responseId,
      'contactedServices': contactedServices.map((service) => service.name).toList(),
      'notifiedContacts': notifiedContacts.map((contact) => contact.toJson()).toList(),
      'status': status.name,
      'initiatedAt': initiatedAt.toIso8601String(),
      'serviceStatuses': serviceStatuses.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'statusUpdates': statusUpdates,
      'metadata': metadata,
    };
  }

  /// Create EmergencyResponse from JSON string
  factory EmergencyResponse.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return EmergencyResponse.fromJson(json);
  }

  /// Convert EmergencyResponse to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Get active services (not completed or cancelled)
  List<ServiceStatus> get activeServices {
    return serviceStatuses.values
        .where((service) => service.status.isActive)
        .toList();
  }

  /// Get completed services
  List<ServiceStatus> get completedServices {
    return serviceStatuses.values
        .where((service) => service.status == ResponseStatus.completed)
        .toList();
  }

  /// Check if all services are completed
  bool get isCompleted {
    return serviceStatuses.values
        .every((service) => service.status == ResponseStatus.completed);
  }

  /// Get response duration
  Duration get responseDuration {
    return DateTime.now().difference(initiatedAt);
  }

  /// Add status update
  EmergencyResponse addStatusUpdate(String update) {
    final updatedStatusUpdates = List<String>.from(statusUpdates)..add(
      '${DateTime.now().toIso8601String()}: $update',
    );
    
    return copyWith(statusUpdates: updatedStatusUpdates);
  }

  /// Update service status
  EmergencyResponse updateServiceStatus(String serviceKey, ServiceStatus newStatus) {
    final updatedStatuses = Map<String, ServiceStatus>.from(serviceStatuses);
    updatedStatuses[serviceKey] = newStatus;
    
    return copyWith(serviceStatuses: updatedStatuses);
  }

  /// Create a copy with updated values
  EmergencyResponse copyWith({
    String? responseId,
    List<ServiceProvider>? contactedServices,
    List<EmergencyContact>? notifiedContacts,
    ResponseStatus? status,
    DateTime? initiatedAt,
    Map<String, ServiceStatus>? serviceStatuses,
    List<String>? statusUpdates,
    Map<String, dynamic>? metadata,
  }) {
    return EmergencyResponse(
      responseId: responseId ?? this.responseId,
      contactedServices: contactedServices ?? this.contactedServices,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      status: status ?? this.status,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      serviceStatuses: serviceStatuses ?? this.serviceStatuses,
      statusUpdates: statusUpdates ?? this.statusUpdates,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'EmergencyResponse(id: $responseId, status: ${status.displayName}, '
           'services: ${contactedServices.length}, contacts: ${notifiedContacts.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyResponse &&
        other.responseId == responseId &&
        other.status == status &&
        other.initiatedAt == initiatedAt;
  }

  @override
  int get hashCode {
    return responseId.hashCode ^ status.hashCode ^ initiatedAt.hashCode;
  }
}