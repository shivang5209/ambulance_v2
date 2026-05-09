import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/accident_event.dart';
import '../models/hotspot_zone.dart';
import '../models/sensor_analytics.dart';
import '../models/vehicle_parameters.dart';
import '../providers/auth_provider.dart';
import '../services/esp32_service.dart';
import '../services/esp32_simulator.dart';
import '../services/hotspot_service.dart';
import '../services/supabase_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_analytics_widgets.dart';
import '../widgets/heatmap_overlay.dart';
import '../widgets/max_width_container.dart';
import '../widgets/ops_ui.dart';
import 'esp32_management_screen.dart';
import 'initial_login_screen.dart';
import 'ride_test_screen.dart';
import 'role_home_shell.dart';
import 'role_selection_screen.dart';

class AdminRoleShellScreen extends StatefulWidget {
  const AdminRoleShellScreen({super.key});

  @override
  State<AdminRoleShellScreen> createState() => _AdminRoleShellScreenState();
}

class _AdminRoleShellScreenState extends State<AdminRoleShellScreen> {
  late final ESP32Service _esp32Service;
  late final HotspotService _hotspotService;
  final ESP32Simulator _simulator = ESP32Simulator();
  final SupabaseRepository _supabaseRepository = SupabaseRepository();
  StreamSubscription? _dataSubscription;
  StreamSubscription? _simulatorSubscription;

  VehicleParameters? _latestData;
  bool _isDemoMode = false;
  bool _isMapLoading = true;
  bool _isAnalyticsLoading = true;
  List<HotspotZone> _hotspots = const [];
  List<AccidentEvent> _mapEvents = const [];
  SensorAnalyticsSummary _analytics = SensorAnalyticsSummary.empty();
  String? _analyticsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _esp32Service = context.read<ESP32Service>();
      _hotspotService = context.read<HotspotService>();

      _dataSubscription = _esp32Service.dataStream.listen((data) {
        if (mounted) setState(() => _latestData = data);
      });
      _simulatorSubscription = _simulator.simulatedDataStream.listen((data) {
        if (_isDemoMode && mounted) {
          setState(() => _latestData = data);
          _esp32Service.injectData(data);
        }
      });

      await _loadMapData();
      await _loadAnalytics();
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _simulatorSubscription?.cancel();
    _simulator.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    if (mounted) setState(() => _isMapLoading = true);

    List<HotspotZone> hotspots = const [];
    List<AccidentEvent> events = const [];

    try {
      hotspots = await _hotspotService.loadHotspots(maxAgeMinutes: 0);
    } catch (_) {}

    try {
      final snap = await FirebaseFirestore.instance
          .collection('training_data')
          .orderBy('recorded_at', descending: true)
          .limit(200)
          .get();
      events = snap.docs
          .map((doc) => _trainingDocToEvent(doc))
          .whereType<AccidentEvent>()
          .toList(growable: false);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _hotspots = hotspots;
      _mapEvents = events;
      _isMapLoading = false;
    });
  }

  Future<void> _loadAnalytics() async {
    if (mounted) {
      setState(() {
        _isAnalyticsLoading = true;
        _analyticsError = null;
      });
    }

    try {
      final analytics = await _supabaseRepository.loadSensorAnalytics();
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _isAnalyticsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analyticsError = error.toString();
        _isAnalyticsLoading = false;
      });
    }
  }

  AccidentEvent? _trainingDocToEvent(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'];
    if (location is! Map) return null;

    final lat = (location['lat'] ?? location['latitude']) as num?;
    final lng = (location['lng'] ?? location['longitude']) as num?;
    if (lat == null || lng == null) return null;

    final modelOutput = data['model_output'] as Map<String, dynamic>? ?? {};
    final probability = (modelOutput['probability'] as num?)?.toDouble() ?? 0.0;
    final severity = (modelOutput['severity'] as String?) ?? 'moderate';
    final type = (modelOutput['type'] as String?) ?? 'unknown';
    final ts = (data['recorded_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    final trueLabel = data['true_label'] as String?;

    return AccidentEvent(
      eventId: data['event_id'] as String? ?? doc.id,
      deviceId: 'training_data',
      detectionTime: ts,
      severity: _severityFromString(severity),
      location: GpsLocation(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        altitude: 0,
        accuracy: 0,
        timestamp: ts,
      ),
      parameterHistory: const [],
      analysis: AccidentAnalysis(
        probabilityScore: probability,
        triggeredFactors: [
          if (trueLabel != null) 'label:$trueLabel',
          'source:training_data',
        ],
        parameterScores: const {},
        analysisTimestamp: ts,
        isFalsePositive: trueLabel == 'false_positive',
        mlConfidence: probability,
        predictedType: type,
      ),
      metadata: {
        'source': 'training_data',
        'true_label': trueLabel,
      },
    );
  }

  AccidentSeverity _severityFromString(String value) {
    switch (value) {
      case 'critical':
        return AccidentSeverity.critical;
      case 'severe':
        return AccidentSeverity.severe;
      case 'moderate':
        return AccidentSeverity.moderate;
      default:
        return AccidentSeverity.minor;
    }
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

  void _openRideTest() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RideTestScreen()),
    );
  }

  void _showConnectDialog() {
    final ipController = TextEditingController();
    final idController = TextEditingController(text: 'ESP32-ACCIDENT-001');

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Connect device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Device ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'IP Address'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await _esp32Service.connectToDevice(
                  idController.text.trim(),
                  ipController.text.trim(),
                );
                if (!mounted || !dialogContext.mounted) return;
                if (ok) {
                  Navigator.of(dialogContext).pop();
                  setState(() {});
                }
              },
              child: const Text('Connect'),
            ),
          ],
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
      title: 'Admin',
      subtitle: 'ML operations shell',
      actions: [
        IconButton.filledTonal(
          onPressed: _openRideTest,
          icon: const Icon(Icons.route_rounded),
          tooltip: 'Ride Test',
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _showConnectDialog,
          icon: const Icon(Icons.wifi_tethering_rounded),
          tooltip: 'Connect device',
        ),
      ],
      tabs: [
        RoleShellTab(
          label: 'Overview',
          icon: Icons.dashboard_customize_rounded,
          child: ShellPage(child: _buildDashboard(connectedCount, riskState)),
        ),
        RoleShellTab(
          label: 'Map',
          icon: Icons.map_rounded,
          child: ShellPage(child: _buildMap()),
        ),
        RoleShellTab(
          label: 'Analytics',
          icon: Icons.insights_rounded,
          child: ShellPage(child: _buildAnalytics()),
        ),
        RoleShellTab(
          label: 'Activity',
          icon: Icons.monitor_heart_rounded,
          child: ShellPage(child: _buildActivity(device, impact, totalAccel)),
        ),
        RoleShellTab(
          label: 'Settings',
          icon: Icons.settings_rounded,
          child: ShellPage(child: _buildSettings()),
        ),
      ],
    );
  }

  Widget _buildDashboard(int connectedCount, bool riskState) {
    final livePackets =
        _latestData == null ? 'Waiting' : _formatClock(_latestData!.timestamp);
    final activeHotspots = _hotspots.where((zone) => zone.isActive).length;
    final impact = _latestData?.impactForce ?? 0.0;
    final totalAccel = _latestData?.totalAcceleration ?? 0.0;

    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          OpsSectionCard(
            title: riskState
                ? 'High-risk telemetry spike detected'
                : 'Fleet monitoring nominal',
            subtitle: riskState
                ? 'Heatmap, hotspot clusters, and device telemetry are ready for triage.'
                : 'Realtime fleet shell is synchronized across telemetry, heatmap, and training feedback.',
            tone: riskState ? AppColors.error : AppColors.primary,
            trailing: OpsStatusPill(
              label: _isDemoMode ? 'Demo mode' : 'Live ops',
              tone: _isDemoMode ? AppColors.warning : AppColors.success,
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OpsActionButton(
                  label: 'Refresh map',
                  icon: Icons.refresh_rounded,
                  tone: AppColors.primary,
                  onTap: _loadMapData,
                ),
                OpsActionButton(
                  label: 'Refresh analytics',
                  icon: Icons.insights_rounded,
                  tone: AppColors.primary,
                  onTap: _loadAnalytics,
                ),
                OpsActionButton(
                  label: 'Connect device',
                  icon: Icons.wifi_tethering_rounded,
                  tone: AppColors.success,
                  onTap: _showConnectDialog,
                ),
                OpsActionButton(
                  label: 'ESP32 tools',
                  icon: Icons.memory_rounded,
                  tone: AppColors.accent,
                  onTap: _openManagement,
                ),
              ],
            ),
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final width = isWide
                  ? (constraints.maxWidth - (OpsSpacing.tileGap * 3)) / 4
                  : (constraints.maxWidth - OpsSpacing.tileGap) / 2;

              return Wrap(
                spacing: OpsSpacing.tileGap,
                runSpacing: OpsSpacing.tileGap,
                children: [
                  SizedBox(
                    width: width,
                    child: OpsMetricTile(
                      label: 'Connected devices',
                      value: '$connectedCount',
                      helper: deviceLabel(connectedCount),
                      icon: Icons.devices_rounded,
                      tone: AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: OpsMetricTile(
                      label: 'Active hotspots',
                      value: '$activeHotspots',
                      helper: '${_hotspots.length} zones cached',
                      icon: Icons.location_on_rounded,
                      tone: activeHotspots > 0
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: OpsMetricTile(
                      label: 'Map events',
                      value: '${_mapEvents.length}',
                      helper: 'Recent training-data records',
                      icon: Icons.local_fire_department_rounded,
                      tone: _mapEvents.isEmpty
                          ? AppColors.primary
                          : AppColors.error,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: OpsMetricTile(
                      label: 'Telemetry state',
                      value: livePackets,
                      helper: _latestData == null
                          ? 'Awaiting latest packet'
                          : 'Last packet received',
                      icon: Icons.sync_rounded,
                      tone: _latestData == null
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 10,
                      child: OpsSectionCard(
                        title: 'Mission status',
                        subtitle:
                            'Core admin KPIs based on live telemetry and hotspot intelligence.',
                        child: Column(
                          children: [
                            OpsInfoRow(
                              label: 'Latest device',
                              value: _latestData?.deviceId ??
                                  'No device connected',
                            ),
                            OpsInfoRow(
                              label: 'Latest impact force',
                              value: _latestData == null
                                  ? '--'
                                  : '${impact.toStringAsFixed(2)} g',
                              valueColor: impact > 3 ? AppColors.error : null,
                            ),
                            OpsInfoRow(
                              label: 'Total acceleration',
                              value: _latestData == null
                                  ? '--'
                                  : '${totalAccel.toStringAsFixed(2)} G',
                              valueColor:
                                  totalAccel > 3 ? AppColors.warning : null,
                            ),
                            OpsInfoRow(
                              label: 'Demo simulator',
                              value: _isDemoMode ? 'Injecting stream' : 'Off',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: OpsSpacing.sectionGap),
                    Expanded(
                      flex: 11,
                      child: OpsSectionCard(
                        title: 'Operational strip',
                        subtitle:
                            'Realtime posture of devices, incidents, and cloud data.',
                        child: OpsOperationalStrip(
                          items: [
                            OpsOperationalItem(
                              label: 'Incident watch',
                              value: riskState ? 'Escalated' : 'Quiet',
                              helper: '${_mapEvents.length} tracked events',
                              icon: Icons.shield_outlined,
                              tone: riskState
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                            OpsOperationalItem(
                              label: 'Hotspot sync',
                              value: '${_hotspots.length}',
                              helper: 'Cached intelligence zones',
                              icon: Icons.cloud_done_rounded,
                              tone: AppColors.primary,
                            ),
                            OpsOperationalItem(
                              label: 'Devices',
                              value: '$connectedCount',
                              helper: deviceLabel(connectedCount),
                              icon: Icons.memory_rounded,
                              tone: AppColors.primary,
                            ),
                            OpsOperationalItem(
                              label: 'Mode',
                              value: _isDemoMode ? 'Demo' : 'Live',
                              helper: 'Telemetry stream source',
                              icon: Icons.analytics_rounded,
                              tone: _isDemoMode
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  OpsSectionCard(
                    title: 'Mission status',
                    subtitle:
                        'Core admin KPIs based on live telemetry and hotspot intelligence.',
                    child: Column(
                      children: [
                        OpsInfoRow(
                          label: 'Latest device',
                          value: _latestData?.deviceId ?? 'No device connected',
                        ),
                        OpsInfoRow(
                          label: 'Latest impact force',
                          value: _latestData == null
                              ? '--'
                              : '${impact.toStringAsFixed(2)} g',
                          valueColor: impact > 3 ? AppColors.error : null,
                        ),
                        OpsInfoRow(
                          label: 'Total acceleration',
                          value: _latestData == null
                              ? '--'
                              : '${totalAccel.toStringAsFixed(2)} G',
                          valueColor: totalAccel > 3 ? AppColors.warning : null,
                        ),
                        OpsInfoRow(
                          label: 'Demo simulator',
                          value: _isDemoMode ? 'Injecting stream' : 'Off',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: OpsSpacing.sectionGap),
                  OpsOperationalStrip(
                    items: [
                      OpsOperationalItem(
                        label: 'Incident watch',
                        value: riskState ? 'Escalated' : 'Quiet',
                        helper: '${_mapEvents.length} tracked events',
                        icon: Icons.shield_outlined,
                        tone: riskState ? AppColors.error : AppColors.success,
                      ),
                      OpsOperationalItem(
                        label: 'Hotspot sync',
                        value: '${_hotspots.length}',
                        helper: 'Cached intelligence zones',
                        icon: Icons.cloud_done_rounded,
                        tone: AppColors.primary,
                      ),
                      OpsOperationalItem(
                        label: 'Devices',
                        value: '$connectedCount',
                        helper: deviceLabel(connectedCount),
                        icon: Icons.memory_rounded,
                        tone: AppColors.primary,
                      ),
                      OpsOperationalItem(
                        label: 'Mode',
                        value: _isDemoMode ? 'Demo' : 'Live',
                        helper: 'Telemetry stream source',
                        icon: Icons.analytics_rounded,
                        tone:
                            _isDemoMode ? AppColors.warning : AppColors.success,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalytics() {
    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          OpsSectionCard(
            title: 'Recorded data analytics',
            subtitle:
                'Supabase-backed summary metrics, telemetry graphs, and recent readings.',
            trailing: TextButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            child: _isAnalyticsLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _analyticsError != null
                    ? _buildAnalyticsError()
                    : _buildAnalyticsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics unavailable',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'The app could not read Supabase analytics data. If you just enabled this feature, rerun the updated SQL schema so the tables have read policies for the app client.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _analyticsError ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OpsPalette.textSecondary(context),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final width = isWide
                ? (constraints.maxWidth - (OpsSpacing.tileGap * 3)) / 4
                : (constraints.maxWidth - OpsSpacing.tileGap) / 2;

            return Wrap(
              spacing: OpsSpacing.tileGap,
              runSpacing: OpsSpacing.tileGap,
              children: [
                SizedBox(
                  width: width,
                  child: OpsMetricTile(
                    label: 'Readings analysed',
                    value: '${_analytics.readingSampleCount}',
                    helper: 'Recent Supabase sample',
                    icon: Icons.dataset_rounded,
                    tone: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OpsMetricTile(
                    label: 'Active devices',
                    value: '${_analytics.activeDeviceCount}',
                    helper: _analytics.latestReadingAt == null
                        ? 'No recent data'
                        : 'Latest ${_formatDateTime(_analytics.latestReadingAt!)}',
                    icon: Icons.devices_rounded,
                    tone: AppColors.success,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OpsMetricTile(
                    label: 'Average speed',
                    value: '${_analytics.averageSpeed.toStringAsFixed(1)} km/h',
                    helper:
                        'Peak ${_analytics.peakSpeed.toStringAsFixed(1)} km/h',
                    icon: Icons.speed_rounded,
                    tone: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OpsMetricTile(
                    label: 'Peak impact',
                    value: '${_analytics.peakImpactForce.toStringAsFixed(2)} g',
                    helper:
                        'Average ${_analytics.averageImpactForce.toStringAsFixed(2)} g',
                    icon: Icons.graphic_eq_rounded,
                    tone: AppColors.accent,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OpsMetricTile(
                    label: 'Average acceleration',
                    value:
                        '${_analytics.averageAcceleration.toStringAsFixed(2)} G',
                    helper: 'Across recent readings',
                    icon: Icons.show_chart_rounded,
                    tone: AppColors.warning,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OpsMetricTile(
                    label: 'Crash events',
                    value: '${_analytics.crashEventCount}',
                    helper: 'Recent stored crash rows',
                    icon: Icons.car_crash_rounded,
                    tone: AppColors.error,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: OpsMetricTile(
                    label: 'Trip summaries',
                    value: '${_analytics.tripSummaryCount}',
                    helper:
                        '${_analytics.totalTripDistanceKm.toStringAsFixed(1)} km total distance',
                    icon: Icons.route_rounded,
                    tone: AppColors.success,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: OpsSpacing.sectionGap),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 920) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnalyticsLineChartCard(
                      title: 'Speed over recorded readings',
                      subtitle:
                          'Recent telemetry trend from Supabase sensor data.',
                      values: _analytics.speedSeries,
                      tone: AppColors.primary,
                      unit: 'km/h',
                    ),
                  ),
                  const SizedBox(width: OpsSpacing.sectionGap),
                  Expanded(
                    child: AnalyticsLineChartCard(
                      title: 'Impact force trend',
                      subtitle:
                          'Recorded impact-force behavior across recent rows.',
                      values: _analytics.impactSeries,
                      tone: AppColors.accent,
                      unit: 'g',
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                AnalyticsLineChartCard(
                  title: 'Speed over recorded readings',
                  subtitle: 'Recent telemetry trend from Supabase sensor data.',
                  values: _analytics.speedSeries,
                  tone: AppColors.primary,
                  unit: 'km/h',
                ),
                const SizedBox(height: OpsSpacing.sectionGap),
                AnalyticsLineChartCard(
                  title: 'Impact force trend',
                  subtitle:
                      'Recorded impact-force behavior across recent rows.',
                  values: _analytics.impactSeries,
                  tone: AppColors.accent,
                  unit: 'g',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: OpsSpacing.sectionGap),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 920) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnalyticsLineChartCard(
                      title: 'Acceleration trend',
                      subtitle:
                          'Total acceleration across recent stored readings.',
                      values: _analytics.accelerationSeries,
                      tone: AppColors.warning,
                      unit: 'G',
                    ),
                  ),
                  const SizedBox(width: OpsSpacing.sectionGap),
                  Expanded(
                    child: DeviceBreakdownChartCard(
                      devices: _analytics.deviceBreakdown.take(6).toList(),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                AnalyticsLineChartCard(
                  title: 'Acceleration trend',
                  subtitle: 'Total acceleration across recent stored readings.',
                  values: _analytics.accelerationSeries,
                  tone: AppColors.warning,
                  unit: 'G',
                ),
                const SizedBox(height: OpsSpacing.sectionGap),
                DeviceBreakdownChartCard(
                  devices: _analytics.deviceBreakdown.take(6).toList(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: OpsSpacing.sectionGap),
        RecentReadingsCard(readings: _analytics.recentReadings),
      ],
    );
  }

  Widget _buildMap() {
    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          OpsSectionCard(
            title: 'Hotspot intelligence map',
            subtitle:
                'Live clustered hotspots plus recent accident-training events.',
            trailing: TextButton.icon(
              onPressed: _loadMapData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OpsStatusPill(
                      label: '${_hotspots.length} hotspots',
                      tone: AppColors.warning,
                      icon: Icons.location_on_rounded,
                    ),
                    OpsStatusPill(
                      label: '${_mapEvents.length} events',
                      tone: AppColors.error,
                      icon: Icons.local_fire_department_rounded,
                    ),
                    OpsStatusPill(
                      label: _isMapLoading ? 'Refreshing' : 'Map ready',
                      tone:
                          _isMapLoading ? AppColors.warning : AppColors.success,
                      icon: Icons.sync_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 500,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: OpsPalette.border(context)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _isMapLoading
                          ? const Center(child: CircularProgressIndicator())
                          : HeatmapOverlay(
                              events: _mapEvents,
                              hotspots: _hotspots,
                              onHotspotTap: _showHotspotDetails,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHotspotDetails(HotspotZone zone) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hotspot ${zone.zoneId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Incidents: ${zone.incidentCount}'),
            Text('Severity: ${zone.avgSeverity.toStringAsFixed(1)}'),
            Text('Trend: ${zone.trend}'),
            Text('Weather: ${zone.weatherFactor}'),
            if (zone.geminiAnalysis.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(zone.geminiAnalysis),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivity(dynamic device, double impact, double totalAccel) {
    final timeline = [
      _AdminTimelineItem(
        title:
            _latestData == null ? 'Waiting for telemetry' : 'Packet ingested',
        subtitle: _latestData == null
            ? 'No live sensor packet yet'
            : 'Timestamp ${_formatClock(_latestData!.timestamp)}',
        tone: _latestData == null ? AppColors.warning : AppColors.success,
        icon: Icons.podcasts_rounded,
      ),
      _AdminTimelineItem(
        title: _isDemoMode ? 'Simulator stream active' : 'Live hardware mode',
        subtitle: _isDemoMode
            ? 'ESP32 simulator is injecting packets'
            : 'Listening for connected device payloads',
        tone: _isDemoMode ? AppColors.warning : AppColors.primary,
        icon: Icons.memory_rounded,
      ),
      _AdminTimelineItem(
        title: _hotspots.isEmpty
            ? 'Hotspots not loaded'
            : 'Hotspot intelligence ready',
        subtitle: _hotspots.isEmpty
            ? 'Run refresh to update cluster cache'
            : '${_hotspots.length} zones with ${_mapEvents.length} map events',
        tone: _hotspots.isEmpty ? AppColors.warning : AppColors.success,
        icon: Icons.location_on_rounded,
      ),
    ];

    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          OpsSectionCard(
            title: 'Latest telemetry snapshot',
            subtitle:
                'Combined device state, map intelligence, and telemetry risk markers.',
            child: Column(
              children: [
                OpsInfoRow(
                    label: 'Device',
                    value: device?.name ?? 'No device connected'),
                OpsInfoRow(
                  label: 'Last packet',
                  value: _latestData == null
                      ? 'Awaiting telemetry'
                      : _formatClock(_latestData!.timestamp),
                ),
                OpsInfoRow(
                  label: 'Impact force',
                  value: _latestData == null
                      ? '--'
                      : '${impact.toStringAsFixed(2)} G',
                  valueColor: impact > 3 ? AppColors.error : null,
                ),
                OpsInfoRow(
                  label: 'Total acceleration',
                  value: _latestData == null
                      ? '--'
                      : '${totalAccel.toStringAsFixed(2)} G',
                  valueColor: totalAccel > 3 ? AppColors.warning : null,
                ),
                OpsInfoRow(
                    label: 'Loaded hotspots', value: '${_hotspots.length}'),
              ],
            ),
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          OpsSectionCard(
            title: 'Operations timeline',
            subtitle: 'Key shell activity for incident review and fleet ops.',
            child: Column(
              children: [
                for (final item in timeline) ...[
                  _AdminTimelineTile(item: item),
                  if (item != timeline.last)
                    Divider(color: OpsPalette.border(context), height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          OpsSectionCard(
            title: 'Admin controls',
            subtitle:
                'Device management, simulator control, and map intelligence refresh.',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _isDemoMode,
                  contentPadding: const EdgeInsets.all(0),
                  title: const Text('Demo mode'),
                  subtitle: const Text(
                    'Inject simulator data into the shared telemetry stream.',
                  ),
                  onChanged: (_) => _toggleDemo(),
                ),
                const SizedBox(height: 4),
                const OpsInfoRow(
                  label: 'Map data source',
                  value: 'training_data + hotspots',
                ),
                OpsInfoRow(
                  label: 'Hotspot cache',
                  value: '${_hotspots.length} zones',
                ),
              ],
            ),
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          const OpsThemeModeSelector(),
          const SizedBox(height: OpsSpacing.sectionGap),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OpsActionButton(
                label: 'Refresh map',
                icon: Icons.refresh_rounded,
                tone: AppColors.primary,
                onTap: _loadMapData,
              ),
              OpsActionButton(
                label: 'Refresh analytics',
                icon: Icons.insights_rounded,
                tone: AppColors.primary,
                onTap: _loadAnalytics,
              ),
              OpsActionButton(
                label: 'ESP32 tools',
                icon: Icons.memory_rounded,
                tone: AppColors.success,
                onTap: _openManagement,
              ),
              OpsActionButton(
                label: 'Ride test',
                icon: Icons.route_rounded,
                tone: AppColors.accent,
                onTap: _openRideTest,
              ),
              OpsActionButton(
                label: 'Switch role',
                icon: Icons.swap_horiz_rounded,
                tone: AppColors.warning,
                onTap: _switchRole,
              ),
              OpsActionButton(
                label: 'Log out',
                icon: Icons.logout_rounded,
                tone: AppColors.error,
                onTap: _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminTimelineItem {
  final String title;
  final String subtitle;
  final Color tone;
  final IconData icon;

  const _AdminTimelineItem({
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.icon,
  });
}

class _AdminTimelineTile extends StatelessWidget {
  final _AdminTimelineItem item;

  const _AdminTimelineTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: item.tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: item.tone),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OpsPalette.textSecondary(context),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String deviceLabel(int count) {
  if (count == 0) return 'No device online';
  if (count == 1) return 'Primary unit online';
  return '$count active units';
}

String _formatClock(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final second = dateTime.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatDateTime(DateTime dateTime) {
  final date = '${dateTime.day}/${dateTime.month}';
  return '$date ${_formatClock(dateTime)}';
}
