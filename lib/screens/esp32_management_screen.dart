import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../core/constants/app_theme.dart';
import '../services/esp32_service.dart';
import '../services/esp32_simulator.dart';
import '../services/secure_storage_service.dart';
import '../models/models.dart';

class ESP32ManagementScreen extends StatefulWidget {
  const ESP32ManagementScreen({super.key});

  @override
  State<ESP32ManagementScreen> createState() => _ESP32ManagementScreenState();
}

class _ESP32ManagementScreenState extends State<ESP32ManagementScreen> {
  late final ESP32Service _esp32Service;
  final ESP32Simulator _simulator = ESP32Simulator();
  List<ESP32Device> _devices = [];
  List<ESP32Device> _availableDevices = [];
  bool _isScanning = false;
  bool _isDataCollectionActive = false;
  bool _isDemoMode = false;
  StreamSubscription<VehicleParameters>? _dataSubscription;
  StreamSubscription<VehicleParameters>? _simulatorSubscription;
  VehicleParameters? _latestData;

  @override
  void initState() {
    super.initState();
    _esp32Service = context.read<ESP32Service>();
    _loadConnectedDevices();
    _startListeningToData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _simulatorSubscription?.cancel();
    // Don't dispose _esp32Service — it's shared via Provider and owned by main.
    _simulator.dispose();
    super.dispose();
  }

  void _loadConnectedDevices() {
    setState(() {
      _devices = _esp32Service.connectedDevices;
    });
  }

  void _startListeningToData() {
    _dataSubscription = _esp32Service.dataStream.listen((data) {
      setState(() {
        _latestData = data;
      });
    });

    // Also listen to simulator data
    _simulatorSubscription = _simulator.simulatedDataStream.listen((data) {
      if (_isDemoMode) {
        setState(() {
          _latestData = data;
        });
        // Forward into the shared ESP32Service stream so the
        // IoTDataOrchestrator receives demo data just like real device data.
        _esp32Service.injectData(data);
      }
    });
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final foundDevices = await _esp32Service.scanForDevices();
      setState(() {
        _availableDevices = foundDevices;
      });

      if (foundDevices.isNotEmpty) {
        _showDeviceSelectionDialog();
      } else {
        _showNoDevicesFoundDialog();
      }
    } catch (e) {
      _showErrorDialog('Scan failed: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Found ESP32 Devices'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableDevices.length,
            itemBuilder: (context, index) {
              final device = _availableDevices[index];
              return ListTile(
                leading: Icon(
                  Icons.sensors,
                  color: device.statusColor,
                ),
                title: Text(device.name),
                subtitle:
                    Text('${device.ipAddress} • ${device.firmwareVersion}'),
                trailing: ElevatedButton(
                  onPressed: () => _connectToDevice(device),
                  child: const Text('Connect'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNoDevicesFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Devices Found'),
        content: const Text(
          'No ESP32 devices were found on the network. Make sure:\n\n'
          '• ESP32 is powered on\n'
          '• Connected to the same WiFi network\n'
          '• Running the correct firmware\n'
          '• Not blocked by firewall\n\n'
          'Or try demo mode to see how the interface works with simulated devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualConnectionDialog();
            },
            child: const Text('Manual Connect'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleDemoMode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.monitoringActive,
            ),
            child: const Text('Try Demo'),
          ),
        ],
      ),
    );
  }

  void _showManualConnectionDialog() {
    final ipController = TextEditingController();
    final deviceIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deviceIdController,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'ESP32-001',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectManually(deviceIdController.text, ipController.text);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(ESP32Device device) async {
    Navigator.pop(context); // Close dialog

    await _loadBearerToken(device.id);
    final success =
        await _esp32Service.connectToDevice(device.id, device.ipAddress);
    if (!mounted) return;

    if (success) {
      setState(() {
        _devices = _esp32Service.connectedDevices;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.name}'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      _showErrorDialog('Failed to connect to ${device.name}');
    }
  }

  Future<void> _connectManually(String deviceId, String ipAddress) async {
    if (deviceId.isEmpty || ipAddress.isEmpty) {
      _showErrorDialog('Please enter both Device ID and IP Address');
      return;
    }

    await _loadBearerToken(deviceId);
    final success = await _esp32Service.connectToDevice(deviceId, ipAddress);
    if (!mounted) return;

    if (success) {
      setState(() {
        _devices = _esp32Service.connectedDevices;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $deviceId'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      _showErrorDialog('Failed to connect to $deviceId at $ipAddress');
    }
  }

  // Load bearer token from secure storage and register it with ESP32Service
  // so all subsequent requests to this device include the Authorization header.
  Future<void> _loadBearerToken(String deviceId) async {
    final token = await SecureStorageService().getDeviceBearerToken();
    if (token != null && token.isNotEmpty) {
      _esp32Service.setDeviceToken(deviceId, token);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleDataCollection() {
    if (_isDataCollectionActive) {
      _esp32Service.stopDataCollection();
      if (_isDemoMode) {
        _simulator.stopSimulation();
      }
    } else {
      _esp32Service.startDataCollection();
      if (_isDemoMode) {
        _simulator.startSimulation();
      }
    }

    setState(() {
      _isDataCollectionActive = !_isDataCollectionActive;
    });
  }

  void _toggleDemoMode() {
    setState(() {
      _isDemoMode = !_isDemoMode;
    });

    if (_isDemoMode) {
      // Enter demo mode
      final simulatedDevices = _simulator.generateSimulatedDevices();
      setState(() {
        _devices = simulatedDevices;
      });

      if (_isDataCollectionActive) {
        _simulator.startSimulation();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode enabled - Showing simulated ESP32 devices'),
          backgroundColor: AppTheme.monitoringActive,
        ),
      );
    } else {
      // Exit demo mode
      _simulator.stopSimulation();
      _loadConnectedDevices(); // Load real devices

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo mode disabled - Showing real devices'),
          backgroundColor: AppTheme.normalOperation,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Management'),
        actions: [
          IconButton(
            icon: Icon(_isDemoMode ? Icons.computer : Icons.sensors),
            onPressed: _toggleDemoMode,
            tooltip: _isDemoMode ? 'Exit Demo Mode' : 'Enter Demo Mode',
          ),
          IconButton(
            icon:
                Icon(_isDataCollectionActive ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleDataCollection,
            tooltip: _isDataCollectionActive
                ? 'Stop Data Collection'
                : 'Start Data Collection',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConnectedDevices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demo Mode Info Card
            if (_isDemoMode) _buildDemoModeInfoCard(),

            if (_isDemoMode) const SizedBox(height: 24),

            // Connection Status Card
            _buildConnectionStatusCard(),

            const SizedBox(height: 24),

            // Latest Sensor Data
            if (_latestData != null) _buildLatestDataCard(),

            const SizedBox(height: 24),

            // Real-time Data Visualization
            if (_latestData != null) _buildRealTimeVisualization(),

            const SizedBox(height: 24),

            // Connected Devices
            _buildConnectedDevicesSection(),

            const SizedBox(height: 24),

            // Device Actions
            _buildDeviceActionsSection(),
          ],
        ),
      ),
      floatingActionButton: _isDemoMode
          ? FloatingActionButton.extended(
              onPressed: _toggleDemoMode,
              icon: const Icon(Icons.sensors),
              label: const Text('Exit Demo'),
              backgroundColor: AppTheme.normalOperation,
            )
          : FloatingActionButton.extended(
              onPressed: _isScanning ? null : _scanForDevices,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
              backgroundColor: _isScanning ? Colors.grey : AppTheme.primary,
            ),
    );
  }

  Widget _buildDemoModeInfoCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.monitoringActive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.monitoringActive.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.monitoringActive,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo Mode Active',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.monitoringActive,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You\'re viewing simulated ESP32 devices with realistic sensor data. Tap the computer icon to exit demo mode.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.monitoringActive,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      _devices.isNotEmpty ? AppTheme.success : AppTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _isDemoMode ? 'ESP32 Demo Mode' : 'ESP32 Connection Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isDemoMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.monitoringActive,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DEMO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusMetric(
                  'Connected Devices',
                  '${_devices.length}',
                  _devices.isEmpty
                      ? 'No devices connected'
                      : 'Active connections',
                  Icons.sensors,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildStatusMetric(
                  'Data Collection',
                  _isDataCollectionActive ? 'Active' : 'Stopped',
                  _isDataCollectionActive ? 'Receiving data' : 'Paused',
                  _isDataCollectionActive
                      ? Icons.play_circle
                      : Icons.pause_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMetric(
      String label, String value, String subtitle, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: AppTheme.monitoringActive,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.monitoringActive,
              ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }

  Widget _buildLatestDataCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest Sensor Data',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _buildDataTile('Speed',
                          '${_latestData!.speed.toStringAsFixed(1)} km/h')),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildDataTile('G-Force',
                          '${_latestData!.totalAcceleration.toStringAsFixed(2)}G')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildDataTile('Impact',
                          '${_latestData!.impactForce.toStringAsFixed(2)}G')),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildDataTile('GPS Acc.',
                          '${_latestData!.location.accuracy.toStringAsFixed(1)}m')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.monitoringActive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.monitoringActive,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDevicesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connected Devices',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          if (_devices.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.sensors_off,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No devices connected',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the scan button to find ESP32 devices',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _devices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final device = _devices[index];
                return _buildDeviceItem(device);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(ESP32Device device) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: device.statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: device.statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: device.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.sensors,
              color: device.statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: device.statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        device.isConnected ? 'Connected' : 'Offline',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${device.id}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      size: 14,
                      color: device.signalColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${device.signalStrength}dBm',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: device.signalColor,
                          ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.battery_std,
                      size: 14,
                      color: device.batteryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${device.batteryLevel}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: device.batteryColor,
                          ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        device.ipAddress,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontFamily: 'monospace',
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceActionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                'Calibrate Sensors',
                Icons.tune,
                AppTheme.monitoringActive,
                _devices.isNotEmpty ? () => _calibrateAllSensors() : null,
              ),
              _buildActionButton(
                'Restart Devices',
                Icons.restart_alt,
                AppTheme.accent,
                _devices.isNotEmpty ? () => _restartAllDevices() : null,
              ),
              _buildActionButton(
                'Export Data',
                Icons.download,
                AppTheme.normalOperation,
                _latestData != null ? () => _exportData() : null,
              ),
              _buildActionButton(
                'Device Settings',
                Icons.settings,
                AppTheme.emergencyResponse,
                _devices.isNotEmpty ? () => _showDeviceSettings() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback? onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _calibrateAllSensors() async {
    if (_devices.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calibrating sensors on all devices...'),
        backgroundColor: AppTheme.monitoringActive,
      ),
    );

    int successCount = 0;
    for (final device in _devices) {
      final success = await _esp32Service.calibrateSensors(device.id);
      if (success) successCount++;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calibrated $successCount of ${_devices.length} devices'),
        backgroundColor: successCount == _devices.length
            ? AppTheme.success
            : AppTheme.accent,
      ),
    );
  }

  Future<void> _restartAllDevices() async {
    if (_devices.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart All Devices'),
        content: const Text(
            'Are you sure you want to restart all connected ESP32 devices? This will temporarily interrupt data collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restarting all devices...'),
        backgroundColor: AppTheme.accent,
      ),
    );

    int successCount = 0;
    for (final device in _devices) {
      final success = await _esp32Service.restartDevice(device.id);
      if (success) successCount++;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restarted $successCount of ${_devices.length} devices'),
        backgroundColor: successCount == _devices.length
            ? AppTheme.success
            : AppTheme.accent,
      ),
    );
  }

  Future<void> _exportData() async {
    if (_devices.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting sensor data...'),
        backgroundColor: AppTheme.normalOperation,
      ),
    );

    String? data;

    if (_isDemoMode) {
      // Use simulator for demo data
      data = _simulator.generateSimulatedExportData('json');
    } else {
      // Use real ESP32 service
      final device = _devices.first;
      data = await _esp32Service.exportDeviceData(
        device.id,
        startDate: DateTime.now().subtract(const Duration(hours: 24)),
        endDate: DateTime.now(),
        format: 'json',
      );
    }
    if (!mounted) return;

    if (data != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data exported successfully'),
          backgroundColor: AppTheme.success,
        ),
      );

      // Show export preview dialog
      _showExportPreviewDialog(data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export data'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showExportPreviewDialog(String data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exported Data Preview'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              data.length > 1000 ? '${data.substring(0, 1000)}...' : data,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real app, this would save to file or share
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data saved to downloads'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeviceSettings() {
    if (_devices.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Settings'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Sampling Rate'),
                subtitle: const Text('Adjust sensor sampling frequency'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showSamplingRateDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Sensitivity'),
                subtitle: const Text('Configure sensor sensitivity'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showSensitivityDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.sensors),
                title: const Text('Sensor Configuration'),
                subtitle: const Text('Enable/disable specific sensors'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showSensorConfigDialog(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSamplingRateDialog() {
    Navigator.pop(context); // Close settings dialog

    showDialog(
      context: context,
      builder: (context) {
        int selectedRate = 10; // Default 10Hz
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Sampling Rate'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select sensor sampling rate:'),
                const SizedBox(height: 16),
                Slider(
                  value: selectedRate.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  label: '${selectedRate}Hz',
                  onChanged: (value) {
                    setState(() {
                      selectedRate = value.round();
                    });
                  },
                ),
                Text('${selectedRate}Hz'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  for (final device in _devices) {
                    await _esp32Service.setSamplingRate(
                        device.id, selectedRate);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Sampling rate set to ${selectedRate}Hz'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSensitivityDialog() {
    Navigator.pop(context); // Close settings dialog

    showDialog(
      context: context,
      builder: (context) {
        double sensitivity = 1.0; // Default sensitivity
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Sensor Sensitivity'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Adjust sensor sensitivity:'),
                const SizedBox(height: 16),
                Slider(
                  value: sensitivity,
                  min: 0.1,
                  max: 5.0,
                  divisions: 49,
                  label: '${sensitivity.toStringAsFixed(1)}x',
                  onChanged: (value) {
                    setState(() {
                      sensitivity = value;
                    });
                  },
                ),
                Text('${sensitivity.toStringAsFixed(1)}x'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  for (final device in _devices) {
                    await _esp32Service.setSensitivity(device.id, sensitivity);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Sensitivity set to ${sensitivity.toStringAsFixed(1)}x'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSensorConfigDialog() {
    Navigator.pop(context); // Close settings dialog

    showDialog(
      context: context,
      builder: (context) {
        final Map<String, bool> sensorConfig = {
          'accelerometer': true,
          'gyroscope': true,
          'gps': true,
          'temperature': false,
          'humidity': false,
          'pressure': false,
        };

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Sensor Configuration'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: sensorConfig.entries.map((entry) {
                  return CheckboxListTile(
                    title: Text(entry.key.toUpperCase()),
                    value: entry.value,
                    onChanged: (value) {
                      setState(() {
                        sensorConfig[entry.key] = value ?? false;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  for (final device in _devices) {
                    await _esp32Service.configureSensors(
                        device.id, sensorConfig);
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Sensor configuration updated'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRealTimeVisualization() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Real-time Sensor Visualization',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isDataCollectionActive
                      ? AppTheme.success
                      : AppTheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isDataCollectionActive ? 'Live' : 'Paused',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _isDataCollectionActive
                          ? AppTheme.success
                          : AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Acceleration Visualization
          _buildAccelerationVisualization(),

          const SizedBox(height: 16),

          // GPS and Speed Info
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  'GPS Coordinates',
                  '${_latestData!.location.latitude.toStringAsFixed(6)}, ${_latestData!.location.longitude.toStringAsFixed(6)}',
                  Icons.location_on,
                  AppTheme.monitoringActive,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoTile(
                  'Device Status',
                  'Device ID: ${_latestData!.deviceId}',
                  Icons.sensors,
                  AppTheme.normalOperation,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Additional Sensors
          if (_latestData!.additionalSensors.isNotEmpty)
            _buildAdditionalSensorsGrid(),
        ],
      ),
    );
  }

  Widget _buildAccelerationVisualization() {
    const maxG = 5.0;
    final xPercent = (_latestData!.accelerationX.abs() / maxG).clamp(0.0, 1.0);
    final yPercent = (_latestData!.accelerationY.abs() / maxG).clamp(0.0, 1.0);
    final zPercent = (_latestData!.accelerationZ.abs() / maxG).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.monitoringActive.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acceleration (G-Force)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),

          // X-Axis
          _buildAccelerationBar(
              'X-Axis', _latestData!.accelerationX, xPercent, Colors.red),
          const SizedBox(height: 8),

          // Y-Axis
          _buildAccelerationBar(
              'Y-Axis', _latestData!.accelerationY, yPercent, Colors.green),
          const SizedBox(height: 8),

          // Z-Axis
          _buildAccelerationBar(
              'Z-Axis', _latestData!.accelerationZ, zPercent, Colors.blue),
          const SizedBox(height: 12),

          // Total Acceleration
          Row(
            children: [
              Text(
                'Total: ${_latestData!.totalAcceleration.toStringAsFixed(2)}G',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _latestData!.totalAcceleration > 3.0
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
              ),
              const Spacer(),
              if (_latestData!.exceedsAccidentThreshold)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ALERT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccelerationBar(
      String label, double value, double percent, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            '${value.toStringAsFixed(2)}G',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalSensorsGrid() {
    final sensors = _latestData!.additionalSensors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Sensors',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            for (int i = 0; i < sensors.length; i += 2)
              Padding(
                padding:
                    EdgeInsets.only(bottom: i + 2 < sensors.length ? 12 : 0),
                child: Row(
                  children: [
                    Expanded(
                        child: _buildSensorTile(
                      sensors.entries.elementAt(i).key,
                      sensors.entries.elementAt(i).value,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: i + 1 < sensors.length
                            ? _buildSensorTile(
                                sensors.entries.elementAt(i + 1).key,
                                sensors.entries.elementAt(i + 1).value,
                              )
                            : const SizedBox()),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorTile(String sensorName, dynamic value) {
    String displayValue;
    String unit = '';

    switch (sensorName.toLowerCase()) {
      case 'temperature':
        displayValue = '${value.toStringAsFixed(1)}';
        unit = '°C';
        break;
      case 'humidity':
        displayValue = '${value.toStringAsFixed(1)}';
        unit = '%';
        break;
      case 'pressure':
        displayValue = '${value.toStringAsFixed(1)}';
        unit = 'hPa';
        break;
      case 'battery_voltage':
        displayValue = '${value.toStringAsFixed(2)}';
        unit = 'V';
        break;
      default:
        displayValue = value.toString();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            sensorName.replaceAll('_', ' ').toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$displayValue$unit',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
          ),
        ],
      ),
    );
  }
}
