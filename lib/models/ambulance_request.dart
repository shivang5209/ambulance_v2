class AmbulanceRequest {
  final String patientName;
  final String phone;
  final String address;
  final String severity;
  final String notes;
  final DateTime timestamp;

  AmbulanceRequest({
    required this.patientName,
    required this.phone,
    required this.address,
    required this.severity,
    required this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'patientName': patientName,
        'phone': phone,
        'address': address,
        'severity': severity,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
      };
}

class AmbulanceResponse {
  final String ambulanceId;
  final int etaMinutes;
  final String status;
  final String routeAlgorithm;
  final List<String> routeNodePath;

  AmbulanceResponse({
    required this.ambulanceId,
    required this.etaMinutes,
    required this.status,
    this.routeAlgorithm = 'unknown',
    this.routeNodePath = const [],
  });
}
