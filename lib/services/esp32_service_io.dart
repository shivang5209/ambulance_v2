import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// ESP32 IoT Device Service
/// Handles communication with ESP32 modules for sensor data
class ESP32Service {
  static const String _defaultPort = '80';
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _dataInterval = Duration(seconds: 1);

  final Map<String, ESP32Device> _connectedDevices = {};
  final StreamController<VehicleParameters> _dataStreamController =
      StreamController<VehicleParameters>.broadcast();

  Timer? _dataTimer;
  bool _isScanning = false;

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
    final List<ESP32Device> foundDevices = [];
    final List<Future<void>> scanTasks = [];

    for (int i = startRange; i <= endRange; i++) {
      final ip = '$subnet.$i';
      scanTasks.add(_scanSingleDevice(ip, foundDevices));
    }

    await Future.wait(scanTasks);
    _isScanning = false;

    return foundDevices;
  }

  Future<void> _scanSingleDevice(
      String ip, List<ESP32Device> foundDevices) async {
    try {
      final response = await http.get(
        Uri.parse('http://$ip:$_defaultPort/info'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final device = ESP32Device.fromJson(data, ip);
        foundDevices.add(device);
      }
    } catch (e) {
      // Device not found or not responding
    }
  }

  /// Connect to a specific ESP32 device
  Future<bool> connectToDevice(String deviceId, String ipAddress) async {
    try {
      // Test connection
      final response = await http.get(
        Uri.parse('http://$ipAddress:$_defaultPort/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        final statusData = jsonDecode(response.body);
        final device = ESP32Device(
          id: deviceId,
          ipAddress: ipAddress,
          name: statusData['name'] ?? 'ESP32-$deviceId',
          isConnected: true,
          lastSeen: DateTime.now(),
          firmwareVersion: statusData['firmware'] ?? '1.0.0',
          batteryLevel: statusData['battery'] ?? 100,
          signalStrength: statusData['rssi'] ?? -50,
        );

        _connectedDevices[deviceId] = device;

        // Start data collection for this device
        _startDataCollection(device);

        return true;
      }
    } catch (e) {
      print('Failed to connect to device $deviceId: $e');
    }

    return false;
  }

  /// Disconnect from a device
  Future<void> disconnectDevice(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device != null) {
      try {
        // Send disconnect command to ESP32
        await http.post(
          Uri.parse('http://${device.ipAddress}:$_defaultPort/disconnect'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(_connectionTimeout);
      } catch (e) {
        print('Error disconnecting device $deviceId: $e');
      }

      _connectedDevices.remove(deviceId);
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

  void _startDataCollection(ESP32Device device) {
    // Individual device data collection is handled by the main timer
    if (_dataTimer == null) {
      startDataCollection();
    }
  }

  Future<void> _collectDataFromAllDevices() async {
    final tasks =
        _connectedDevices.values.map((device) => _collectDeviceData(device));
    await Future.wait(tasks);
  }

  Future<void> _collectDeviceData(ESP32Device device) async {
    try {
      final response = await http.get(
        Uri.parse('http://${device.ipAddress}:$_defaultPort/sensors'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final sensorData = jsonDecode(response.body);
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
      print('Failed to collect data from ${device.id}: $e');
    }
  }

  VehicleParameters _parseVehicleParameters(
      String deviceId, Map<String, dynamic> data) {
    return VehicleParameters(
      deviceId: deviceId,
      timestamp: DateTime.now(),
      accelerationX: (data['accel_x'] ?? 0.0).toDouble(),
      accelerationY: (data['accel_y'] ?? 0.0).toDouble(),
      accelerationZ: (data['accel_z'] ?? 9.8).toDouble(),
      speed: (data['speed'] ?? 0.0).toDouble(),
      location: GpsLocation(
        latitude: (data['lat'] ?? 0.0).toDouble(),
        longitude: (data['lng'] ?? 0.0).toDouble(),
        altitude: (data['alt'] ?? 0.0).toDouble(),
        accuracy: (data['gps_accuracy'] ?? 5.0).toDouble(),
        timestamp: DateTime.now(),
      ),
      orientation: (data['orientation'] ?? 0.0).toDouble(),
      impactForce: (data['impact'] ?? 0.0).toDouble(),
      additionalSensors: {
        'temperature': data['temperature'] ?? 25.0,
        'humidity': data['humidity'] ?? 50.0,
        'pressure': data['pressure'] ?? 1013.25,
        'battery_voltage': data['battery_voltage'] ?? 3.7,
        'mq135_ppm': data['mq135_ppm'] ?? data['mq135'] ?? 0.0,
        'mq135': data['mq135_ppm'] ?? data['mq135'] ?? 0.0,
        'rssi': data['rssi'] ?? -60,
      },
    );
  }

  /// Send configuration to ESP32 device
  Future<bool> configureDevice(
      String deviceId, Map<String, dynamic> config) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('http://${device.ipAddress}:$_defaultPort/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(config),
          )
          .timeout(_connectionTimeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to configure device $deviceId: $e');
      return false;
    }
  }

  /// Get device status and diagnostics
  Future<Map<String, dynamic>?> getDeviceStatus(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return null;

    try {
      final response = await http.get(
        Uri.parse('http://${device.ipAddress}:$_defaultPort/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to get status for device $deviceId: $e');
    }

    return null;
  }

  /// Calibrate sensors on ESP32 device
  Future<bool> calibrateSensors(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final response = await http.post(
        Uri.parse('http://${device.ipAddress}:$_defaultPort/calibrate'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30)); // Calibration takes time

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to calibrate device $deviceId: $e');
      return false;
    }
  }

  /// Restart ESP32 device
  Future<bool> restartDevice(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final response = await http.post(
        Uri.parse('http://${device.ipAddress}:$_defaultPort/restart'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_connectionTimeout);

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
      print('Failed to restart device $deviceId: $e');
    }

    return false;
  }

  /// Update device firmware (if supported)
  Future<bool> updateFirmware(String deviceId, String firmwareUrl) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('http://${device.ipAddress}:$_defaultPort/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'firmware_url': firmwareUrl}),
          )
          .timeout(const Duration(minutes: 5)); // Firmware update takes time

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to update firmware for device $deviceId: $e');
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
      final response = await http
          .post(
            Uri.parse('http://${device.ipAddress}:$_defaultPort/export'),
            headers: {'Content-Type': 'application/json'},
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
      print('Failed to export data from device $deviceId: $e');
    }

    return null;
  }

  /// Get device configuration
  Future<Map<String, dynamic>?> getDeviceConfiguration(String deviceId) async {
    final device = _connectedDevices[deviceId];
    if (device == null) return null;

    try {
      final response = await http.get(
        Uri.parse('http://${device.ipAddress}:$_defaultPort/config'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to get configuration for device $deviceId: $e');
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
      batteryLevel: json['battery'] ?? 100,
      signalStrength: json['rssi'] ?? -50,
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
