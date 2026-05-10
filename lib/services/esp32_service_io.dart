import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// ESP32 IoT Device Service
/// Handles communication with ESP32 modules for sensor data
class ESP32Service {
  static const String _defaultPort = '80';
  static const List<String> _scanPorts = ['80', '5000'];
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _scanTimeout = Duration(milliseconds: 1200);
  static const Duration _dataInterval = Duration(seconds: 1);

  final Map<String, ESP32Device> _connectedDevices = {};
  final Map<String, String> _bearerTokens = {};
  final StreamController<VehicleParameters> _dataStreamController =
      StreamController<VehicleParameters>.broadcast();

  Timer? _dataTimer;
  bool _isScanning = false;
  bool _isCollecting = false;

  /// Register a bearer token for a device. All subsequent requests to that
  /// device will include [Authorization: Bearer <token>].
  void setDeviceToken(String deviceId, String token) {
    _bearerTokens[deviceId] = token;
  }

  Map<String, String> _headers(String deviceId) {
    final token = _bearerTokens[deviceId];
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Stream of real-time sensor data from all connected devices
  Stream<VehicleParameters> get dataStream => _dataStreamController.stream;

  /// Get list of connected devices
  List<ESP32Device> get connectedDevices => _connectedDevices.values.toList();

  /// Scan for ESP32 devices on the local network
  Future<List<ESP32Device>> scanForDevices({
    String subnet = '192.168.1',
    int startRange = 1,
    int endRange = 254,
  }) async {
    if (_isScanning) return [];

    _isScanning = true;
    try {
      final List<ESP32Device> foundDevices = [];
      final List<Future<void>> scanTasks = [];

      for (int i = startRange; i <= endRange; i++) {
        final host = '$subnet.$i';
        for (final port in _scanPorts) {
          scanTasks.add(_scanSingleDevice(host, port, foundDevices));
        }
      }

      await Future.wait(scanTasks);
      return foundDevices;
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _scanSingleDevice(
      String host, String port, List<ESP32Device> foundDevices) async {
    try {
      final endpoint = _endpoint(host, port: port);
      final response = await http.get(
        Uri.parse('$endpoint/info'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_scanTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final device =
            ESP32Device.fromJson(data, _addressForDevice(host, port));
        if (!foundDevices.any((item) => item.id == device.id)) {
          foundDevices.add(device);
        }
      }
    } catch (e) {
      // Device not found or not responding
    }
  }

  /// Connect to a specific ESP32 device
  Future<bool> connectToDevice(String deviceId, String ipAddress) async {
    try {
      final endpoint = _endpoint(ipAddress);

      // Test connection
      final response = await http
          .get(
            Uri.parse('$endpoint/status'),
            headers: _headers(deviceId),
          )
          .timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        final statusData = jsonDecode(response.body) as Map<String, dynamic>;
        final device = ESP32Device(
          id: deviceId,
          ipAddress: ipAddress,
          name: statusData['name'] ?? 'ESP32-$deviceId',
          isConnected: true,
          lastSeen: DateTime.now(),
          firmwareVersion: statusData['firmware'] ?? '1.0.0',
          batteryLevel: _asInt(statusData['battery'], 100),
          signalStrength: _asInt(statusData['rssi'], -50),
        );

        _connectedDevices[deviceId] = device;

        // Start data collection for this device
        _startDataCollection();

        return true;
      }
    } catch (e) {
      debugPrint('Failed to connect to device $deviceId: $e');
    }

    return false;
  }

  /// Disconnect from a device
  Future<void> disconnectDevice(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device != null) {
      try {
        final endpoint = _endpoint(device.ipAddress);
        await http
            .post(
              Uri.parse('$endpoint/disconnect'),
              headers: _headers(deviceId),
            )
            .timeout(_connectionTimeout);
      } catch (e) {
        debugPrint('Error disconnecting device $deviceId: $e');
      }

      _connectedDevices.remove(deviceId);
      _bearerTokens.remove(deviceId);
      if (_connectedDevices.isEmpty) {
        stopDataCollection();
      }
    }
  }

  /// Start collecting sensor data from connected devices
  void startDataCollection() {
    _dataTimer?.cancel();
    _dataTimer = Timer.periodic(_dataInterval, (timer) {
      _collectDataFromAllDevices();
    });
  }

  /// Stop data collection
  void stopDataCollection() {
    _dataTimer?.cancel();
    _dataTimer = null;
  }

  void _startDataCollection() {
    // Individual device data collection is handled by the main timer
    if (_dataTimer == null) {
      startDataCollection();
    }
  }

  Future<void> _collectDataFromAllDevices() async {
    if (_isCollecting) return;
    _isCollecting = true;
    final tasks =
        _connectedDevices.values.map((device) => _collectDeviceData(device));
    try {
      await Future.wait(tasks);
    } finally {
      _isCollecting = false;
    }
  }

  Future<void> _collectDeviceData(ESP32Device device) async {
    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .get(
            Uri.parse('$endpoint/sensors'),
            headers: _headers(device.id),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final sensorData = jsonDecode(response.body) as Map<String, dynamic>;
        final vehicleParams = _parseVehicleParameters(device.id, sensorData);

        // Update device status
        device.lastSeen = DateTime.now();
        device.isConnected = true;

        // Emit data to stream
        _dataStreamController.add(vehicleParams);
      }
    } catch (e) {
      // Mark device as disconnected if we can't reach it
      device.isConnected = false;
      debugPrint('Failed to collect data from ${device.id}: $e');
    }
  }

  VehicleParameters _parseVehicleParameters(
      String deviceId, Map<String, dynamic> data) {
    return VehicleParameters(
      deviceId: deviceId,
      timestamp: DateTime.now(),
      accelerationX: _asDouble(data['accel_x'], 0),
      accelerationY: _asDouble(data['accel_y'], 0),
      accelerationZ: _asDouble(data['accel_z'], 1),
      speed: _asDouble(data['speed'], 0),
      location: GpsLocation(
        latitude: _asDouble(data['lat'], 0),
        longitude: _asDouble(data['lng'], 0),
        altitude: _asDouble(data['alt'] ?? data['altitude'], 0),
        accuracy: _asDouble(data['gps_accuracy'], 5),
        timestamp: DateTime.now(),
      ),
      orientation: _asDouble(data['orientation'], 0),
      impactForce: _asDouble(data['impact'] ?? data['total_accel'], 0),
      additionalSensors: {
        'temperature': _asDouble(data['temperature'], 25),
        'humidity': _asDouble(data['humidity'], 50),
        'pressure': _asDouble(data['pressure'], 1013.25),
        'battery_voltage': _asDouble(data['battery_voltage'], 3.7),
        'mq135_ppm': _asDouble(data['mq135_ppm'] ?? data['mq135'], 0),
        'mq135': _asDouble(data['mq135_ppm'] ?? data['mq135'], 0),
        'rssi': _asInt(data['rssi'], -60),
      },
    );
  }

  Future<void> notifyRideStarted({
    required String sessionId,
    required DateTime startedAt,
  }) async {
    await _postRideEvent({
      'type': 'ride_started',
      'session_id': sessionId,
      'started_at': startedAt.toIso8601String(),
    });
  }

  Future<void> notifyRideProgress({
    required String sessionId,
    required int totalSamples,
    required int durationSeconds,
    double? speed,
    double? totalAcceleration,
  }) async {
    await _postRideEvent({
      'type': 'ride_progress',
      'session_id': sessionId,
      'total_samples': totalSamples,
      'duration_seconds': durationSeconds,
      if (speed != null) 'speed': speed,
      if (totalAcceleration != null) 'total_acceleration': totalAcceleration,
    });
  }

  Future<void> notifyRideFinished({
    required String sessionId,
    required DateTime stoppedAt,
    required int durationSeconds,
    required int totalSamples,
    bool uploadedToSupabase = false,
  }) async {
    await _postRideEvent({
      'type': 'ride_finished',
      'session_id': sessionId,
      'stopped_at': stoppedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'total_samples': totalSamples,
      'uploaded_to_supabase': uploadedToSupabase,
    });
  }

  Future<void> _postRideEvent(Map<String, dynamic> payload) async {
    final devices = _connectedDevices.values.toList(growable: false);
    await Future.wait(devices.map((device) async {
      try {
        final endpoint = _endpoint(device.ipAddress);
        final response = await http
            .post(
              Uri.parse('$endpoint/ride'),
              headers: _headers(device.id),
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          device.lastSeen = DateTime.now();
          device.isConnected = true;
        }
      } catch (e) {
        debugPrint('Failed to send ride event to ${device.id}: $e');
      }
    }));
  }

  /// Send configuration to ESP32 device
  Future<bool> configureDevice(
      String deviceId, Map<String, dynamic> config) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .post(
            Uri.parse('$endpoint/config'),
            headers: _headers(deviceId),
            body: jsonEncode(config),
          )
          .timeout(_connectionTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to configure device $deviceId: $e');
      return false;
    }
  }

  /// Get device status and diagnostics
  Future<Map<String, dynamic>?> getDeviceStatus(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return null;

    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .get(
            Uri.parse('$endpoint/status'),
            headers: _headers(deviceId),
          )
          .timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to get status for device $deviceId: $e');
    }

    return null;
  }

  /// Calibrate sensors on ESP32 device
  Future<bool> calibrateSensors(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .post(
            Uri.parse('$endpoint/calibrate'),
            headers: _headers(deviceId),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to calibrate device $deviceId: $e');
      return false;
    }
  }

  /// Restart ESP32 device
  Future<bool> restartDevice(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .post(
            Uri.parse('$endpoint/restart'),
            headers: _headers(deviceId),
          )
          .timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        // Mark device as disconnected temporarily
        device.isConnected = false;

        // Try to reconnect after a delay
        Future.delayed(const Duration(seconds: 10), () {
          connectToDevice(deviceId, device.ipAddress);
        });

        return true;
      }
    } catch (e) {
      debugPrint('Failed to restart device $deviceId: $e');
    }

    return false;
  }

  /// Update device firmware (if supported)
  Future<bool> updateFirmware(String deviceId, String firmwareUrl) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .post(
            Uri.parse('$endpoint/update'),
            headers: _headers(deviceId),
            body: jsonEncode({'firmware_url': firmwareUrl}),
          )
          .timeout(const Duration(minutes: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to update firmware for device $deviceId: $e');
      return false;
    }
  }

  /// Export device data to CSV or JSON
  Future<String?> exportDeviceData(
    String deviceId, {
    DateTime? startDate,
    DateTime? endDate,
    String format = 'json',
  }) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return null;

    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .post(
            Uri.parse('$endpoint/export'),
            headers: _headers(deviceId),
            body: jsonEncode({
              'start_date': startDate?.toIso8601String(),
              'end_date': endDate?.toIso8601String(),
              'format': format,
            }),
          )
          .timeout(const Duration(minutes: 2));

      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Failed to export data from device $deviceId: $e');
    }

    return null;
  }

  /// Get device configuration
  Future<Map<String, dynamic>?> getDeviceConfiguration(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return null;

    try {
      final endpoint = _endpoint(device.ipAddress);
      final response = await http
          .get(
            Uri.parse('$endpoint/config'),
            headers: _headers(deviceId),
          )
          .timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to get configuration for device $deviceId: $e');
    }

    return null;
  }

  /// Set device sampling rate
  Future<bool> setSamplingRate(String deviceId, int rateHz) async {
    return configureDevice(deviceId, {'sampling_rate': rateHz});
  }

  /// Set device sensitivity
  Future<bool> setSensitivity(String deviceId, double sensitivity) async {
    return configureDevice(deviceId, {'sensitivity': sensitivity});
  }

  /// Enable/disable specific sensors
  Future<bool> configureSensors(
      String deviceId, Map<String, bool> sensors) async {
    return configureDevice(deviceId, {'sensors': sensors});
  }

  /// Inject a [VehicleParameters] reading directly into the data stream.
  ///
  /// Used by Demo Mode to forward simulator data through the shared stream
  /// so the IoTDataOrchestrator receives it just like real device data.
  void injectData(VehicleParameters params) {
    _dataStreamController.add(params);
  }

  /// Dispose resources
  void dispose() {
    _dataTimer?.cancel();
    _dataStreamController.close();
  }

  String _endpoint(String address, {String? port}) {
    final trimmed = address.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
    }
    final hasPort = trimmed.contains(':');
    final resolvedPort = port ?? (hasPort ? null : _defaultPort);
    return 'http://$trimmed${resolvedPort == null ? '' : ':$resolvedPort'}';
  }

  String _addressForDevice(String host, String port) {
    return port == _defaultPort ? host : '$host:$port';
  }

  double _asDouble(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  int _asInt(Object? value, int fallback) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// ESP32 Device Model
class ESP32Device {
  final String id;
  final String ipAddress;
  final String name;
  bool isConnected;
  DateTime lastSeen;
  final String firmwareVersion;
  final int batteryLevel;
  final int signalStrength;

  ESP32Device({
    required this.id,
    required this.ipAddress,
    required this.name,
    required this.isConnected,
    required this.lastSeen,
    required this.firmwareVersion,
    required this.batteryLevel,
    required this.signalStrength,
  });

  factory ESP32Device.fromJson(Map<String, dynamic> json, String ipAddress) {
    return ESP32Device(
      id: json['device_id'] ?? 'ESP32-${DateTime.now().millisecondsSinceEpoch}',
      ipAddress: ipAddress,
      name: json['name'] ?? 'ESP32 Device',
      isConnected: true,
      lastSeen: DateTime.now(),
      firmwareVersion: json['firmware'] ?? '1.0.0',
      batteryLevel: _jsonInt(json['battery'], 100),
      signalStrength: _jsonInt(json['rssi'], -50),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ip_address': ipAddress,
      'name': name,
      'is_connected': isConnected,
      'last_seen': lastSeen.toIso8601String(),
      'firmware_version': firmwareVersion,
      'battery_level': batteryLevel,
      'signal_strength': signalStrength,
    };
  }

  /// Get connection status color
  Color get statusColor {
    if (!isConnected) return const Color(0xFFEF4444); // Red
    final timeSinceLastSeen = DateTime.now().difference(lastSeen).inMinutes;
    if (timeSinceLastSeen > 5) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFF22C55E); // Green
  }

  /// Get battery status color
  Color get batteryColor {
    if (batteryLevel > 50) return const Color(0xFF22C55E); // Green
    if (batteryLevel > 20) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  /// Get signal strength color
  Color get signalColor {
    if (signalStrength > -50) return const Color(0xFF22C55E); // Green
    if (signalStrength > -70) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }
}

int _jsonInt(Object? value, int fallback) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
