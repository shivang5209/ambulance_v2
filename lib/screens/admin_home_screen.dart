import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/esp32_service.dart';
import '../services/esp32_simulator.dart';
import '../models/vehicle_parameters.dart';
import 'esp32_management_screen.dart';
import 'initial_login_screen.dart';
import 'role_selection_screen.dart';
import '../providers/auth_provider.dart';

const _kDefaultDeviceId = 'ESP32-ACCIDENT-001';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with TickerProviderStateMixin {
  late final ESP32Service _esp32Service;
  final ESP32Simulator _simulator = ESP32Simulator();

  StreamSubscription<VehicleParameters>? _dataSubscription;
  StreamSubscription<VehicleParameters>? _simulatorSubscription;

  VehicleParameters? _latestData;
  bool _isDemoMode = false;
  bool _accelExpanded = false;

  // Accident alert animation
  late AnimationController _alertController;
  late Animation<double> _alertAnimation;

  static const double _accidentThreshold = 3.0;

  @override
  void initState() {
    super.initState();
    _esp32Service = context.read<ESP32Service>();

    _alertController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _alertAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _alertController, curve: Curves.easeInOut),
    );

    _startListening();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _simulatorSubscription?.cancel();
    _simulator.dispose();
    _alertController.dispose();
    super.dispose();
  }

  void _startListening() {
    _dataSubscription = _esp32Service.dataStream.listen((data) {
      if (mounted) {
        setState(() => _latestData = data);
      }
    });

    _simulatorSubscription = _simulator.simulatedDataStream.listen((data) {
      if (_isDemoMode && mounted) {
        setState(() => _latestData = data);
        _esp32Service.injectData(data);
      }
    });
  }

  void _toggleDemo() {
    setState(() {
      _isDemoMode = !_isDemoMode;
      if (!_isDemoMode) _latestData = null;
    });
  }

  void _showConnectDialog() {
    final ipController = TextEditingController();
    final deviceIdController =
        TextEditingController(text: _kDefaultDeviceId);
    bool isConnecting = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Connect to Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the IP address shown on your ESP32 OLED screen.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Device ID',
                  hintText: 'ESP32-ACCIDENT-001',
                  prefixIcon: Icon(Icons.memory),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.43.xxx',
                  prefixIcon: Icon(Icons.wifi),
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(
                      color: AppTheme.error, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sensors),
              label: Text(isConnecting ? 'Connecting…' : 'Connect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.monitoringActive,
                foregroundColor: Colors.white,
              ),
              onPressed: isConnecting
                  ? null
                  : () async {
                      final id = deviceIdController.text.trim();
                      final ip = ipController.text.trim();
                      if (id.isEmpty || ip.isEmpty) {
                        setDialogState(
                            () => error = 'Both fields are required');
                        return;
                      }
                      setDialogState(() {
                        isConnecting = true;
                        error = null;
                      });
                      final ok =
                          await _esp32Service.connectToDevice(id, ip);
                      if (ok) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) setState(() {});
                      } else {
                        setDialogState(() {
                          isConnecting = false;
                          error =
                              'Could not reach device.\nCheck IP and hotspot.';
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  bool get _isConnected =>
      _esp32Service.connectedDevices.isNotEmpty || _isDemoMode;

  ESP32Device? get _connectedDevice =>
      _esp32Service.connectedDevices.isNotEmpty
          ? _esp32Service.connectedDevices.first
          : null;

  bool get _accidentDetected =>
      _latestData != null &&
      (_latestData!.impactForce > _accidentThreshold ||
          _latestData!.totalAcceleration > _accidentThreshold);

  double _getAdditional(String key, [double fallback = 0.0]) {
    if (_latestData == null) return fallback;
    final val = _latestData!.additionalSensors[key];
    if (val == null) return fallback;
    return (val as num).toDouble();
  }

  Color get _gforceColor {
    final g = _latestData?.impactForce ?? 0;
    if (g >= _accidentThreshold) return AppTheme.error;
    if (g >= 1.5) return AppTheme.accent;
    return AppTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('System Admin'),
        actions: [
          // Demo mode toggle
          IconButton(
            icon: Icon(
              _isDemoMode ? Icons.computer : Icons.computer_outlined,
              color: _isDemoMode ? AppTheme.accent : null,
            ),
            tooltip: _isDemoMode ? 'Exit Demo' : 'Demo Mode',
            onPressed: _toggleDemo,
          ),
          // Settings menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: 'Settings',
            onSelected: (value) async {
              if (value == 'esp32') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ESP32ManagementScreen(),
                  ),
                );
              } else if (value == 'switch_role') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                );
              } else if (value == 'logout') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await context.read<AuthProvider>().logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const InitialLoginScreen(),
                      ),
                      (_) => false,
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'esp32',
                child: Row(
                  children: [
                    Icon(Icons.sensors, size: 20),
                    SizedBox(width: 12),
                    Text('ESP32 Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'switch_role',
                child: Row(
                  children: [
                    Icon(Icons.switch_account, size: 20),
                    SizedBox(width: 12),
                    Text('Switch Role'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: AppTheme.error),
                    SizedBox(width: 12),
                    Text('Log Out',
                        style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isConnected ? _buildMonitorBody() : _buildNotConnectedBody(),
    );
  }

  // ─── Not Connected State ─────────────────────────────────────────────────

  Widget _buildNotConnectedBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sensors_off,
                size: 48,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Device Connected',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to your ESP32 unit to start monitoring your vehicle.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showConnectDialog,
              icon: const Icon(Icons.wifi),
              label: const Text('Connect by IP'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.monitoringActive,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ESP32ManagementScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.sensors),
              label: const Text('Scan / Advanced'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _toggleDemo,
              icon: const Icon(Icons.computer),
              label: const Text('Try Demo Mode'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main Monitor Body ───────────────────────────────────────────────────

  Widget _buildMonitorBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accident alert banner
          if (_accidentDetected) _buildAccidentBanner(),

          // Connection status bar
          _buildConnectionBar(),
          const SizedBox(height: 16),

          // G-Force hero card
          _buildGForceCard(),
          const SizedBox(height: 16),

          // Temp + Humidity row
          Row(
            children: [
              Expanded(child: _buildEnvCard(
                'Temperature',
                '${_getAdditional('temperature').toStringAsFixed(1)}°C',
                Icons.thermostat,
                AppTheme.emergencyResponse,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildEnvCard(
                'Humidity',
                '${_getAdditional('humidity').toStringAsFixed(0)}%',
                Icons.water_drop,
                AppTheme.monitoringActive,
              )),
            ],
          ),
          const SizedBox(height: 16),

          // Air quality
          _buildAirQualityCard(),
          const SizedBox(height: 16),

          // Accelerometer details
          _buildAccelCard(),
          const SizedBox(height: 16),

          // Device info footer
          _buildDeviceInfoCard(),
        ],
      ),
    );
  }

  // ─── Accident Banner ─────────────────────────────────────────────────────

  Widget _buildAccidentBanner() {
    return AnimatedBuilder(
      animation: _alertAnimation,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: _alertAnimation.value * 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.error.withValues(alpha: _alertAnimation.value),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_rounded,
                  color: AppTheme.error.withValues(alpha: _alertAnimation.value),
                  size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'ACCIDENT DETECTED — HIGH IMPACT!',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Connection Bar ───────────────────────────────────────────────────────

  Widget _buildConnectionBar() {
    final device = _connectedDevice;
    final rssi = _getAdditional('rssi', -60).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isDemoMode
                  ? 'Demo Mode — Simulated Data'
                  : 'Connected: ${device?.name ?? device?.id ?? 'ESP32'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // RSSI
          Icon(
            rssi > -50
                ? Icons.signal_wifi_4_bar
                : rssi > -70
                    ? Icons.network_wifi_3_bar
                    : Icons.signal_wifi_bad,
            size: 18,
            color: rssi > -50
                ? AppTheme.success
                : rssi > -70
                    ? AppTheme.accent
                    : AppTheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            '${rssi}dBm',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          if (device != null) ...[
            const SizedBox(width: 12),
            Text(
              device.ipAddress,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.monitoringActive,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── G-Force Card ─────────────────────────────────────────────────────────

  Widget _buildGForceCard() {
    final gforce = _latestData?.impactForce ?? 0.0;
    final color = _gforceColor;
    final percent = (gforce / 5.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Text(
                'G-FORCE / IMPACT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      letterSpacing: 1.5,
                    ),
              ),
              const SizedBox(height: 40),

              // Large G-Force display (center, no obstruction)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gforce.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'G',
                    style: TextStyle(
                      fontSize: 18,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Threshold indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _accidentDetected
                        ? 'HIGH IMPACT — threshold exceeded'
                        : 'Threshold: ${_accidentThreshold.toStringAsFixed(1)}G',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ],
          ),
          // Circular gauge in top-right corner
          Positioned(
            top: 24,
            right: 24,
            child: SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      color.withValues(alpha: 0.12),
                    ),
                  ),
                  CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Environment Cards ────────────────────────────────────────────────────

  Widget _buildEnvCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        letterSpacing: 1.2,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Air Quality Card ─────────────────────────────────────────────────────

  Widget _buildAirQualityCard() {
    final ppm = _getAdditional('mq135_ppm', _getAdditional('mq135'));
    final isSafe = ppm < 200; // matches GAS_THRESHOLD in firmware
    final barFraction = (ppm / 1000.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.air, color: isSafe ? AppTheme.success : AppTheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'AIR QUALITY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      letterSpacing: 1.5,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSafe
                      ? AppTheme.success.withValues(alpha: 0.12)
                      : AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSafe ? 'SAFE' : 'UNSAFE',
                  style: TextStyle(
                    color: isSafe ? AppTheme.success : AppTheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${ppm.toStringAsFixed(0)} PPM',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isSafe ? AppTheme.success : AppTheme.error,
            ),
          ),
          const SizedBox(height: 12),
          // Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 8,
              backgroundColor:
                  (isSafe ? AppTheme.success : AppTheme.error).withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                  isSafe ? AppTheme.success : AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Accelerometer Card ───────────────────────────────────────────────────

  Widget _buildAccelCard() {
    final ax = _latestData?.accelerationX ?? 0.0;
    final ay = _latestData?.accelerationY ?? 0.0;
    final az = _latestData?.accelerationZ ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: Column(
        children: [
          // Header (tappable to expand)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _accelExpanded = !_accelExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.vibration, size: 20, color: AppTheme.monitoringActive),
                  const SizedBox(width: 8),
                  Text(
                    'ACCELEROMETER',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          letterSpacing: 1.5,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_latestData?.totalAcceleration ?? 0).toStringAsFixed(2)}G total',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.monitoringActive,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _accelExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_accelExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _buildAxisRow('X', ax, AppTheme.error),
                  const SizedBox(height: 10),
                  _buildAxisRow('Y', ay, AppTheme.success),
                  const SizedBox(height: 10),
                  _buildAxisRow('Z', az, AppTheme.monitoringActive),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAxisRow(String axis, double value, Color color) {
    final fraction = (value.abs() / 5.0).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            axis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
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

  // ─── Device Info Footer ───────────────────────────────────────────────────

  Widget _buildDeviceInfoCard() {
    final device = _connectedDevice;
    final battery = _getAdditional('battery_voltage');
    final lastSeen = _latestData?.timestamp;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEVICE INFO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.memory, 'Device',
              _isDemoMode ? 'Demo ESP32' : (device?.name ?? device?.id ?? '—')),
          _buildInfoRow(Icons.battery_charging_full, 'Battery',
              battery > 0 ? '${battery.toStringAsFixed(1)}V' : '—'),
          _buildInfoRow(
            Icons.info_outline,
            'Firmware',
            _isDemoMode ? 'simulator' : (device?.firmwareVersion ?? '—'),
          ),
          _buildInfoRow(
            Icons.access_time,
            'Last Data',
            lastSeen != null ? _formatTime(lastSeen) : '—',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
