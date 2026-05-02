import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/esp32_service.dart';
import '../services/esp32_simulator.dart';
import '../theme/app_colors.dart';
import '../widgets/max_width_container.dart';
import 'esp32_management_screen.dart';
import 'initial_login_screen.dart';
import 'role_home_shell.dart';
import 'role_selection_screen.dart';

class AdminRoleShellScreen extends StatefulWidget {
  const AdminRoleShellScreen({super.key});

  @override
  State<AdminRoleShellScreen> createState() => _AdminRoleShellScreenState();
}

class _AdminRoleShellScreenState extends State<AdminRoleShellScreen> {
  late final ESP32Service _esp32Service;
  final ESP32Simulator _simulator = ESP32Simulator();
  StreamSubscription? _dataSubscription;
  StreamSubscription? _simulatorSubscription;

  dynamic _latestData;
  bool _isDemoMode = false;

  @override
  void initState() {
    super.initState();
    _esp32Service = context.read<ESP32Service>();
    _dataSubscription = _esp32Service.dataStream.listen((data) {
      if (mounted) setState(() => _latestData = data);
    });
    _simulatorSubscription = _simulator.simulatedDataStream.listen((data) {
      if (_isDemoMode && mounted) {
        setState(() => _latestData = data);
        _esp32Service.injectData(data);
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _simulatorSubscription?.cancel();
    _simulator.dispose();
    super.dispose();
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

  void _toggleDemo() {
    setState(() {
      _isDemoMode = !_isDemoMode;
      if (!_isDemoMode) _latestData = null;
    });
  }

  void _openManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ESP32ManagementScreen()),
    );
  }

  void _showConnectDialog() {
    final ipController = TextEditingController();
    final idController = TextEditingController(text: 'ESP32-ACCIDENT-001');
    bool isConnecting = false;
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Connect Device'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: idController,
                      decoration:
                          const InputDecoration(labelText: 'Device ID')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: ipController,
                      decoration:
                          const InputDecoration(labelText: 'IP Address')),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.error)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isConnecting
                      ? null
                      : () async {
                          final ok = await _esp32Service.connectToDevice(
                              idController.text.trim(),
                              ipController.text.trim());
                          if (!mounted) return;
                          if (ok) {
                            Navigator.of(dialogContext).pop();
                            setState(() {});
                          } else {
                            setDialogState(() {
                              error = 'Could not reach device right now.';
                              isConnecting = false;
                            });
                          }
                        },
                  child: Text(isConnecting ? 'Connecting...' : 'Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedCount = _esp32Service.connectedDevices.length;
    final device =
        connectedCount > 0 ? _esp32Service.connectedDevices.first : null;
    final impact = _latestData?.impactForce ?? 0.0;
    final totalAccel = _latestData?.totalAcceleration ?? 0.0;
    final riskState = totalAccel > 3.0 || impact > 3.0;

    return RoleShellScaffold(
      title: 'System Admin',
      subtitle: 'Shared operations shell',
      actions: [
        IconButton(
            onPressed: _showConnectDialog,
            icon: const Icon(Icons.wifi_tethering_rounded)),
      ],
      tabs: [
        RoleShellTab(
            label: 'Dashboard',
            icon: Icons.dashboard_customize_rounded,
            child:
                ShellPage(child: _buildDashboard(connectedCount, riskState))),
        RoleShellTab(
            label: 'Map',
            icon: Icons.map_rounded,
            child: ShellPage(child: _buildMap(device))),
        RoleShellTab(
            label: 'Activity',
            icon: Icons.monitor_heart_rounded,
            child:
                ShellPage(child: _buildActivity(device, impact, totalAccel))),
        RoleShellTab(
            label: 'Settings',
            icon: Icons.settings_rounded,
            child: ShellPage(child: _buildSettings())),
      ],
    );
  }

  Widget _buildDashboard(int connectedCount, bool riskState) {
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(children: [
        _sectionCard(
          title: riskState
              ? 'Crash-risk spike detected'
              : 'Fleet monitoring healthy',
          subtitle: riskState
              ? 'Escalate response, validate device state, and keep operations focused on the live stream.'
              : 'Driver/Admin shell is redesigned while hardware setup stays untouched.',
          tone: riskState ? AppColors.error : AppColors.primary,
          child: Row(children: [
            _statusChip(_isDemoMode ? 'Demo mode' : 'Operations live',
                _isDemoMode ? AppColors.warning : AppColors.success)
          ]),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _metricCard('Connected Devices', '$connectedCount',
              Icons.memory_rounded, AppColors.primary),
          _metricCard(
              'Telemetry',
              _latestData != null ? 'Live' : 'Waiting',
              Icons.sensors_rounded,
              _latestData != null ? AppColors.success : AppColors.warning),
          _metricCard(
              'Demo Mode',
              _isDemoMode ? 'Active' : 'Off',
              Icons.computer_rounded,
              _isDemoMode ? AppColors.warning : AppColors.primary),
          _metricCard(
              'ESP32 Tools', 'Ready', Icons.tune_rounded, AppColors.success),
        ]),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _QuickAction(
              label: _isDemoMode ? 'Exit Demo' : 'Demo Mode',
              icon: Icons.computer_rounded,
              tone: AppColors.warning,
              onTap: _toggleDemo),
          _QuickAction(
              label: 'Connect Device',
              icon: Icons.wifi_tethering_rounded,
              tone: AppColors.primary,
              onTap: _showConnectDialog),
          _QuickAction(
              label: 'ESP32 Tools',
              icon: Icons.tune_rounded,
              tone: AppColors.success,
              onTap: _openManagement),
        ]),
      ]),
    );
  }

  Widget _buildMap(dynamic device) {
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(children: [
        _sectionCard(
          title: 'Fleet Coverage',
          subtitle:
              'Map tab is structurally ready for live fleet and hospital overlays.',
          child: Column(children: [
            _infoRow('Connected Device', device?.name ?? 'No active device'),
            _infoRow('Dispatch Priority',
                _latestData != null ? 'Live monitoring' : 'No live feed'),
            _infoRow(
                'Coverage Zone',
                _latestData != null
                    ? 'Central Delhi'
                    : 'Waiting for telemetry'),
          ]),
        ),
      ]),
    );
  }

  Widget _buildActivity(dynamic device, double impact, double totalAccel) {
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(children: [
        _sectionCard(
          title: 'Latest Sensor Snapshot',
          subtitle: 'Cleaner admin triage view for telemetry and device state.',
          child: Column(children: [
            _infoRow('Device', device?.name ?? 'No device connected'),
            _infoRow(
                'Last Packet',
                _latestData != null
                    ? _formatClock(_latestData.timestamp)
                    : 'Awaiting telemetry'),
            _infoRow('Impact',
                _latestData != null ? '${impact.toStringAsFixed(2)}G' : '—'),
            _infoRow(
                'Total Acceleration',
                _latestData != null
                    ? '${totalAccel.toStringAsFixed(2)}G'
                    : '—'),
            _infoRow(
                'GPS Accuracy',
                _latestData != null
                    ? '${_latestData.location.accuracy.toStringAsFixed(1)} m'
                    : '—'),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Operations Timeline',
          subtitle: 'Live activity designed for quick scanning.',
          child: Column(children: [
            _TimelineEntry(
                title: _isDemoMode ? 'Demo Stream Active' : 'System Online',
                subtitle: _isDemoMode
                    ? 'Simulated telemetry'
                    : 'Awaiting next packet',
                icon: Icons.cloud_done_rounded,
                tone: _isDemoMode ? AppColors.warning : AppColors.success),
            _TimelineEntry(
                title:
                    device != null ? 'Device Connected' : 'No Device Connected',
                subtitle:
                    device?.ipAddress ?? 'Open settings to attach hardware',
                icon: Icons.network_check_rounded,
                tone: device != null ? AppColors.primary : AppColors.warning),
            _TimelineEntry(
                title: totalAccel > 3.0 || impact > 3.0
                    ? 'High-Risk Event Flagged'
                    : 'No Critical Event',
                subtitle: totalAccel > 3.0 || impact > 3.0
                    ? 'Admin review required'
                    : 'Monitoring continues',
                icon: Icons.warning_amber_rounded,
                tone: totalAccel > 3.0 || impact > 3.0
                    ? AppColors.error
                    : AppColors.success),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSettings() {
    return MaxWidthContainer(
      maxWidth: 1100,
      child: Column(children: [
        _sectionCard(
          title: 'Admin Controls',
          subtitle:
              'Critical controls stay accessible without changing setup behavior.',
          child: Column(children: [
            SwitchListTile.adaptive(
              value: _isDemoMode,
              contentPadding: EdgeInsets.zero,
              title: const Text('Demo Mode'),
              subtitle: const Text(
                  'Inject simulator data into the shared telemetry stream.'),
              onChanged: (_) => _toggleDemo(),
            ),
            _infoRow('Hardware Setup', 'Preserved outside redesign scope'),
            _infoRow('ESP32 Management', 'Available from this shell'),
            _infoRow('Accident Threshold', '3.0G'),
          ]),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _QuickAction(
              label: 'ESP32 Tools',
              icon: Icons.memory_rounded,
              tone: AppColors.primary,
              onTap: _openManagement),
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
        ]),
      ]),
    );
  }

  Widget _sectionCard(
      {required String title,
      required String subtitle,
      required Widget child,
      Color? tone}) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: (tone ?? AppColors.border).withValues(alpha: 0.35))),
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

  Widget _metricCard(String label, String value, IconData icon, Color tone) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
