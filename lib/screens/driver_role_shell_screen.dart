import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle_parameters.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/max_width_container.dart';
import 'initial_login_screen.dart';
import 'role_home_shell.dart';
import 'role_selection_screen.dart';

class DriverRoleShellScreen extends StatefulWidget {
  const DriverRoleShellScreen({super.key});

  @override
  State<DriverRoleShellScreen> createState() => _DriverRoleShellScreenState();
}

class _DriverRoleShellScreenState extends State<DriverRoleShellScreen> {
  final math.Random _random = math.Random();
  Timer? _timer;
  VehicleParameters? _params;
  bool _isMonitoring = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isMonitoring && mounted) {
        setState(_refreshData);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    _params = VehicleParameters(
      deviceId: 'AMB-294',
      timestamp: DateTime.now(),
      accelerationX: (_random.nextDouble() - 0.5) * 1.6,
      accelerationY: (_random.nextDouble() - 0.5) * 1.4,
      accelerationZ: 0.95 + _random.nextDouble() * 0.2,
      speed: 42 + _random.nextDouble() * 24,
      location: GpsLocation(
        latitude: 28.6139 + (_random.nextDouble() - 0.5) * 0.02,
        longitude: 77.2090 + (_random.nextDouble() - 0.5) * 0.02,
        altitude: 190 + _random.nextDouble() * 30,
        accuracy: 3 + _random.nextDouble() * 2,
        timestamp: DateTime.now(),
      ),
      orientation: 170 + _random.nextDouble() * 80,
      impactForce: 0.8 + _random.nextDouble() * 0.5,
      additionalSensors: <String, dynamic>{
        'etaMinutes': 6 + _random.nextInt(7),
        'routeProgress': 0.32 + _random.nextDouble() * 0.34,
        'hospital': 'City Trauma Center',
      },
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const InitialLoginScreen()),
      (route) => false,
    );
  }

  void _switchRole() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = _params;
    if (params == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return RoleShellScaffold(
      title: 'Driver Ops',
      subtitle: 'Ambulance shell',
      tabs: [
        RoleShellTab(
            label: 'Dashboard',
            icon: Icons.dashboard_rounded,
            child: ShellPage(child: _buildDashboard(params))),
        RoleShellTab(
            label: 'Map',
            icon: Icons.map_rounded,
            child: ShellPage(child: _buildMap(params))),
        RoleShellTab(
            label: 'Activity',
            icon: Icons.monitor_heart_rounded,
            child: ShellPage(child: _buildActivity(params))),
        RoleShellTab(
            label: 'Settings',
            icon: Icons.settings_rounded,
            child: ShellPage(child: _buildSettings(params))),
      ],
    );
  }

  Widget _buildDashboard(VehicleParameters params) {
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(
        children: [
          _heroCard(
            title: '${params.speed.toStringAsFixed(0)} km/h',
            subtitle:
                'Connected Â· ETA ${params.additionalSensors['etaMinutes']} min Â· ${params.additionalSensors['hospital']}',
            tone: _isMonitoring ? AppColors.primary : AppColors.warning,
            trailing: IconButton(
              onPressed: () => setState(() => _isMonitoring = !_isMonitoring),
              icon: Icon(_isMonitoring
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              final cardWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _metricCard(
                        'G-Force',
                        '${params.totalAcceleration.toStringAsFixed(2)}G',
                        Icons.speed_rounded,
                        params.exceedsAccidentThreshold
                            ? AppColors.error
                            : AppColors.primary),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _metricCard(
                        'Impact',
                        '${params.impactForce.toStringAsFixed(2)}G',
                        Icons.warning_amber_rounded,
                        params.impactForce > 1.3
                            ? AppColors.warning
                            : AppColors.success),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _metricCard(
                        'Orientation',
                        '${params.orientation.toStringAsFixed(0)}°',
                        Icons.explore_rounded,
                        AppColors.success),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _metricCard(
                        'GPS Accuracy',
                        '${params.location.accuracy.toStringAsFixed(1)} m',
                        Icons.gps_fixed_rounded,
                        AppColors.primary),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _sectionCard(
            title: 'Emergency Actions',
            subtitle: 'Keep critical actions close to the driver.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _QuickAction(
                    label: 'Navigate',
                    icon: Icons.navigation_rounded,
                    tone: AppColors.primary),
                _QuickAction(
                    label: 'Call Hospital',
                    icon: Icons.call_rounded,
                    tone: AppColors.warning),
                _QuickAction(
                    label: 'Share Location',
                    icon: Icons.share_location_rounded,
                    tone: AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(VehicleParameters params) {
    final progress =
        (params.additionalSensors['routeProgress'] as double).clamp(0.0, 1.0);
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(
        children: [
          _sectionCard(
            title: 'Fastest Route',
            subtitle:
                'Prepared for live map integration while keeping the new shell stable.',
            child: Column(
              children: [
                _infoRow(
                    'Destination', '${params.additionalSensors['hospital']}'),
                _infoRow('Current Corridor', 'Lodhi Rd ? Ring Rd'),
                _infoRow(
                    'ETA', '${params.additionalSensors['etaMinutes']} min'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Route progress'),
                    const Spacer(),
                    Text('${(progress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress, minHeight: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivity(VehicleParameters params) {
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(
        children: [
          _sectionCard(
            title: 'Sensor Details',
            subtitle:
                'Activity-first layout based on the new design direction.',
            child: Column(
              children: [
                _infoRow('Vehicle ID', params.deviceId),
                _infoRow('Timestamp', _formatClock(params.timestamp)),
                _infoRow('Latitude',
                    '${params.location.latitude.toStringAsFixed(6)}Â°'),
                _infoRow('Longitude',
                    '${params.location.longitude.toStringAsFixed(6)}Â°'),
                _infoRow('Altitude',
                    '${params.location.altitude.toStringAsFixed(1)} m'),
                _infoRow('Total Acceleration',
                    '${params.totalAcceleration.toStringAsFixed(2)}G'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionCard(
            title: 'Recent Activity',
            subtitle: 'Simple event timeline for fast scanning.',
            child: const Column(
              children: [
                _TimelineEntry(
                    title: 'System Started',
                    subtitle: '2 hours ago',
                    icon: Icons.power_settings_new_rounded,
                    tone: AppColors.success),
                _TimelineEntry(
                    title: 'GPS Signal Acquired',
                    subtitle: '2 hours ago',
                    icon: Icons.gps_fixed_rounded,
                    tone: AppColors.success),
                _TimelineEntry(
                    title: 'Fastest Route Locked',
                    subtitle: '5 minutes ago',
                    icon: Icons.route_rounded,
                    tone: AppColors.primary),
                _TimelineEntry(
                    title: 'Monitoring Active',
                    subtitle: 'Now',
                    icon: Icons.sensors_rounded,
                    tone: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(VehicleParameters params) {
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(
        children: [
          _sectionCard(
            title: 'Driver Preferences',
            subtitle: 'Hardware setup remains untouched in this phase.',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _isMonitoring,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Live Monitoring'),
                  subtitle: const Text(
                      'Pause telemetry updates without leaving the app shell.'),
                  onChanged: (value) => setState(() => _isMonitoring = value),
                ),
                _infoRow('Hardware Setup', 'Unchanged in this phase'),
                _infoRow('Crash Threshold', '4.0G total acceleration'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickAction(
                  label: 'Switch Role',
                  icon: Icons.swap_horiz_rounded,
                  tone: AppColors.warning,
                  onTap: _switchRole),
              _QuickAction(
                  label: 'Log Out',
                  icon: Icons.logout_rounded,
                  tone: AppColors.error,
                  onTap: _logout),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCard(
      {required String title,
      required String subtitle,
      required Color tone,
      required Widget trailing}) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _statusChip(_isMonitoring ? 'Connected' : 'Paused',
                  _isMonitoring ? AppColors.success : AppColors.warning),
              const Spacer(),
              trailing
            ]),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.darkTextSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color tone) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: tone),
            const Spacer(),
            Icon(Icons.circle, size: 10, color: tone)
          ]),
          const SizedBox(height: 24),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: tone, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.darkTextSecondary)),
        ]),
      ),
    );
  }

  Widget _sectionCard(
      {required String title,
      required String subtitle,
      required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.darkTextSecondary)),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.darkTextSecondary))),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600))
      ]),
    );
  }

  Widget _statusChip(String label, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 10, color: tone),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: tone, fontWeight: FontWeight.w700))
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color tone;
  final VoidCallback? onTap;

  const _QuickAction(
      {required this.label,
      required this.icon,
      required this.tone,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: OutlinedButton.icon(
        onPressed: onTap ?? () {},
        style: OutlinedButton.styleFrom(
            foregroundColor: tone,
            side: BorderSide(color: tone.withValues(alpha: 0.45))),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;

  const _TimelineEntry(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.tone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: tone)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.darkTextSecondary))
        ]))
      ]),
    );
  }
}

String _formatClock(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final second = dateTime.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
