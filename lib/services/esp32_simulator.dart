import 'dart:async';
import 'dart:math';
import '../models/models.dart';
import 'esp32_service.dart';

/// ESP32 Simulator for testing and demonstration
/// Simulates ESP32 devices and sensor data when no real devices are available
class ESP32Simulator {
  static const List<String> _simulatedDeviceIds = [
    'ESP32-SIM-001',
    'ESP32-SIM-002',
    'ESP32-SIM-003',
  ];

  static const List<String> _simulatedIPs = [
    '192.168.1.100',
    '192.168.1.101',
    '192.168.1.102',
  ];

  final Random _random = Random();
  Timer? _dataGenerationTimer;
  final StreamController<VehicleParameters> _simulatedDataController = 
      StreamController<VehicleParameters>.broadcast();

  /// Stream of simulated sensor data
  Stream<VehicleParameters> get simulatedDataStream => _simulatedDataController.stream;

  /// Generate simulated ESP32 devices for testing
  List<ESP32Device> generateSimulatedDevices() {
    return List.generate(_simulatedDeviceIds.length, (index) {
      return ESP32Device(
        id: _simulatedDeviceIds[index],
        ipAddress: _simulatedIPs[index],
        name: 'Simulated ESP32 ${index + 1}',
        isConnected: true,
        lastSeen: DateTime.now(),
        firmwareVersion: '2.1.${_random.nextInt(10)}',
        batteryLevel: 60 + _random.nextInt(40), // 60-100%
        signalStrength: -30 - _random.nextInt(40), // -30 to -70 dBm
      );
    });
  }

  /// Start generating simulated sensor data
  void startSimulation() {
    _dataGenerationTimer?.cancel();
    _dataGenerationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _generateSimulatedData();
    });
  }

  /// Stop simulation
  void stopSimulation() {
    _dataGenerationTimer?.cancel();
  }

  void _generateSimulatedData() {
    for (final deviceId in _simulatedDeviceIds) {
      final simulatedData = _generateVehicleParameters(deviceId);
      _simulatedDataController.add(simulatedData);
    }
  }

  VehicleParameters _generateVehicleParameters(String deviceId) {
    // Simulate different driving scenarios
    final scenario = _random.nextInt(100);
    
    double accelX, accelY, accelZ, speed, impactForce;
    
    if (scenario < 70) {
      // Normal driving (70% of the time)
      accelX = -0.5 + _random.nextDouble() * 1.0; // -0.5 to 0.5 G
      accelY = -0.3 + _random.nextDouble() * 0.6; // -0.3 to 0.3 G
      accelZ = 9.8 + (-0.2 + _random.nextDouble() * 0.4); // ~9.8 G (gravity)
      speed = 30 + _random.nextDouble() * 50; // 30-80 km/h
      impactForce = 0.1 + _random.nextDouble() * 0.5; // Low impact
    } else if (scenario < 90) {
      // Aggressive driving (20% of the time)
      accelX = -2.0 + _random.nextDouble() * 4.0; // -2 to 2 G
      accelY = -1.5 + _random.nextDouble() * 3.0; // -1.5 to 1.5 G
      accelZ = 9.8 + (-1.0 + _random.nextDouble() * 2.0);
      speed = 60 + _random.nextDouble() * 60; // 60-120 km/h
      impactForce = 1.0 + _random.nextDouble() * 2.0; // Medium impact
    } else {
      // Accident simulation (10% of the time)
      accelX = -8.0 + _random.nextDouble() * 16.0; // -8 to 8 G
      accelY = -6.0 + _random.nextDouble() * 12.0; // -6 to 6 G
      accelZ = 9.8 + (-4.0 + _random.nextDouble() * 8.0);
      speed = _random.nextDouble() * 30; // Sudden speed reduction
      impactForce = 4.0 + _random.nextDouble() * 6.0; // High impact
    }

    return VehicleParameters(
      deviceId: deviceId,
      timestamp: DateTime.now(),
      accelerationX: accelX,
      accelerationY: accelY,
      accelerationZ: accelZ,
      speed: speed,
      location: _generateRandomLocation(),
      orientation: _random.nextDouble() * 360,
      impactForce: impactForce,
      additionalSensors: {
        'temperature': 20.0 + _random.nextDouble() * 15.0, // 20-35°C
        'humidity': 40.0 + _random.nextDouble() * 40.0, // 40-80%
        'pressure': 1000.0 + _random.nextDouble() * 50.0, // 1000-1050 hPa
        'battery_voltage': 3.3 + _random.nextDouble() * 0.7, // 3.3-4.0V
      },
    );
  }

  GpsLocation _generateRandomLocation() {
    // Simulate movement around a central location (example: San Francisco area)
    const baseLat = 37.7749;
    const baseLng = -122.4194;
    const radius = 0.01; // ~1km radius
    
    final lat = baseLat + (-radius + _random.nextDouble() * 2 * radius);
    final lng = baseLng + (-radius + _random.nextDouble() * 2 * radius);
    
    return GpsLocation(
      latitude: lat,
      longitude: lng,
      altitude: 50.0 + _random.nextDouble() * 100.0, // 50-150m
      accuracy: 2.0 + _random.nextDouble() * 8.0, // 2-10m accuracy
      timestamp: DateTime.now(),
    );
  }

  /// Simulate device configuration response
  Map<String, dynamic> getSimulatedDeviceConfig() {
    return {
      'sampling_rate': 10 + _random.nextInt(90), // 10-100 Hz
      'sensitivity': 0.5 + _random.nextDouble() * 4.5, // 0.5-5.0x
      'sensors': {
        'accelerometer': true,
        'gyroscope': true,
        'gps': true,
        'temperature': _random.nextBool(),
        'humidity': _random.nextBool(),
        'pressure': _random.nextBool(),
      },
      'firmware_version': '2.1.${_random.nextInt(10)}',
      'uptime': _random.nextInt(86400), // 0-24 hours in seconds
      'free_memory': 50000 + _random.nextInt(200000), // bytes
    };
  }

  /// Simulate device status response
  Map<String, dynamic> getSimulatedDeviceStatus(String deviceId) {
    return {
      'device_id': deviceId,
      'status': 'online',
      'battery': 60 + _random.nextInt(40),
      'rssi': -30 - _random.nextInt(40),
      'uptime': _random.nextInt(86400),
      'last_restart': DateTime.now()
          .subtract(Duration(hours: _random.nextInt(24)))
          .toIso8601String(),
      'memory_usage': 30 + _random.nextInt(50), // 30-80%
      'cpu_usage': 10 + _random.nextInt(60), // 10-70%
      'temperature': 25.0 + _random.nextDouble() * 20.0, // 25-45°C
    };
  }

  /// Simulate data export
  String generateSimulatedExportData(String format) {
    final data = List.generate(100, (index) {
      return _generateVehicleParameters('ESP32-SIM-001');
    });

    if (format.toLowerCase() == 'json') {
      return '''
{
  "export_info": {
    "device_id": "ESP32-SIM-001",
    "export_time": "${DateTime.now().toIso8601String()}",
    "data_points": ${data.length},
    "time_range": "Last 24 hours (simulated)"
  },
  "sensor_data": [
    ${data.take(5).map((d) => '''
    {
      "timestamp": "${d.timestamp.toIso8601String()}",
      "acceleration": {
        "x": ${d.accelerationX.toStringAsFixed(3)},
        "y": ${d.accelerationY.toStringAsFixed(3)},
        "z": ${d.accelerationZ.toStringAsFixed(3)}
      },
      "speed": ${d.speed.toStringAsFixed(2)},
      "location": {
        "latitude": ${d.location.latitude.toStringAsFixed(6)},
        "longitude": ${d.location.longitude.toStringAsFixed(6)}
      },
      "impact_force": ${d.impactForce.toStringAsFixed(3)},
      "additional_sensors": ${d.additionalSensors.toString()}
    }''').join(',\n')}
  ]
}''';
    } else {
      // CSV format
      const csvHeader = 'timestamp,accel_x,accel_y,accel_z,speed,latitude,longitude,impact_force,temperature,humidity';
      final csvRows = data.take(10).map((d) {
        return '${d.timestamp.toIso8601String()},${d.accelerationX.toStringAsFixed(3)},${d.accelerationY.toStringAsFixed(3)},${d.accelerationZ.toStringAsFixed(3)},${d.speed.toStringAsFixed(2)},${d.location.latitude.toStringAsFixed(6)},${d.location.longitude.toStringAsFixed(6)},${d.impactForce.toStringAsFixed(3)},${d.additionalSensors['temperature']?.toStringAsFixed(1) ?? 'N/A'},${d.additionalSensors['humidity']?.toStringAsFixed(1) ?? 'N/A'}';
      }).join('\n');
      
      return '$csvHeader\n$csvRows';
    }
  }

  /// Dispose resources
  void dispose() {
    _dataGenerationTimer?.cancel();
    _simulatedDataController.close();
  }
}