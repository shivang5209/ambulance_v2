import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/app_theme.dart';
import '../models/models.dart';
import '../widgets/responsive_grid.dart';
import 'ride_test_screen.dart';
import 'role_selection_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  // Mock sensor data
  VehicleParameters? _currentParameters;
  bool _isMonitoring = true;
  final String _deviceStatus = 'Connected';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _generateMockData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _generateMockData() {
    // Generate realistic sensor data
    final random = math.Random();
    _currentParameters = VehicleParameters(
      deviceId: 'IOT_001',
      timestamp: DateTime.now(),
      accelerationX: (random.nextDouble() - 0.5) * 2, // -1 to 1 G
      accelerationY: (random.nextDouble() - 0.5) * 2,
      accelerationZ: 9.8 + (random.nextDouble() - 0.5) * 0.5, // ~9.8 G
      speed: 45 + random.nextDouble() * 30, // 45-75 km/h
      location: GpsLocation(
        latitude: 28.6139 + (random.nextDouble() - 0.5) * 0.01,
        longitude: 77.2090 + (random.nextDouble() - 0.5) * 0.01,
        altitude: 200 + random.nextDouble() * 50,
        accuracy: 3 + random.nextDouble() * 2,
        timestamp: DateTime.now(),
      ),
      orientation: random.nextDouble() * 360,
      impactForce: 0.8 + random.nextDouble() * 0.4, // Normal driving
    );

    // Update every 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _generateMockData();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Vehicle Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.route),
            tooltip: 'Ride Test',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RideTestScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isMonitoring = !_isMonitoring;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'switch_role') {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'switch_role',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20),
                    SizedBox(width: 12),
                    Text('Switch Role'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Monitoring Card
            _buildHeroMonitoringCard(),

            const SizedBox(height: 24),

            // Quick Stats Grid
            _buildQuickStatsGrid(),

            const SizedBox(height: 24),

            // Sensor Details
            _buildSensorDetails(),

            const SizedBox(height: 24),

            // Recent Activity
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMonitoringCard() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: AppTheme.glassmorphicDecoration(
        color: _isMonitoring ? AppTheme.normalOperation : AppTheme.accent,
        borderRadius: 24,
      ),
      child: Stack(
        children: [
          // Animated border
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: (_isMonitoring
                            ? AppTheme.normalOperation
                            : AppTheme.accent)
                        .withValues(alpha: 0.3 + 0.4 * _pulseController.value),
                    width: 2,
                  ),
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.all(24),
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
                            _isMonitoring ? AppTheme.success : AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _deviceStatus,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      'IOT Device',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Speed Display
                Row(
                  children: [
                    Text(
                      _currentParameters?.speed.toStringAsFixed(0) ?? '--',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'km/h',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  'Current Speed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),

                const Spacer(),

                // Status Indicators
                Row(
                  children: [
                    _buildStatusIndicator(
                      'G-Force',
                      '${_currentParameters?.totalAcceleration.toStringAsFixed(1) ?? '--'}G',
                      _currentParameters?.exceedsAccidentThreshold == true
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
                    const SizedBox(width: 24),
                    _buildStatusIndicator(
                      'Impact',
                      '${_currentParameters?.impactForce.toStringAsFixed(1) ?? '--'}G',
                      (_currentParameters?.impactForce ?? 0) > 2.0
                          ? AppTheme.accent
                          : AppTheme.success,
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

  Widget _buildStatusIndicator(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 4),
        Row(
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
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStatsGrid() {
    return ResponsiveGrid(
      mobileColumns: 2,
      tabletColumns: 3,
      desktopColumns: 4,
      spacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'Acceleration X',
          '${_currentParameters?.accelerationX.toStringAsFixed(2) ?? '--'}G',
          Icons.trending_up,
          AppTheme.monitoringActive,
        ),
        _buildStatCard(
          'Acceleration Y',
          '${_currentParameters?.accelerationY.toStringAsFixed(2) ?? '--'}G',
          Icons.trending_flat,
          AppTheme.accent,
        ),
        _buildStatCard(
          'Orientation',
          '${_currentParameters?.orientation.toStringAsFixed(0) ?? '--'}°',
          Icons.explore,
          AppTheme.normalOperation,
        ),
        _buildStatCard(
          'GPS Accuracy',
          '${_currentParameters?.location.accuracy.toStringAsFixed(1) ?? '--'}m',
          Icons.gps_fixed,
          AppTheme.success,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDetails() {
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
            'Sensor Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          _buildSensorRow('Device ID', _currentParameters?.deviceId ?? '--'),
          _buildSensorRow(
              'Timestamp',
              _currentParameters?.timestamp.toString().substring(11, 19) ??
                  '--'),
          _buildSensorRow('Latitude',
              '${_currentParameters?.location.latitude.toStringAsFixed(6) ?? '--'}°'),
          _buildSensorRow('Longitude',
              '${_currentParameters?.location.longitude.toStringAsFixed(6) ?? '--'}°'),
          _buildSensorRow('Altitude',
              '${_currentParameters?.location.altitude.toStringAsFixed(1) ?? '--'}m'),
          _buildSensorRow('Total Acceleration',
              '${_currentParameters?.totalAcceleration.toStringAsFixed(2) ?? '--'}G'),
        ],
      ),
    );
  }

  Widget _buildSensorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
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
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            'System Started',
            '2 hours ago',
            Icons.power_settings_new,
            AppTheme.success,
          ),
          _buildActivityItem(
            'GPS Signal Acquired',
            '2 hours ago',
            Icons.gps_fixed,
            AppTheme.normalOperation,
          ),
          _buildActivityItem(
            'Monitoring Active',
            'Now',
            Icons.sensors,
            AppTheme.monitoringActive,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
      String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
