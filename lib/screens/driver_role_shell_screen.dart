import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/accident_prediction.dart';
import '../models/hotspot_zone.dart';
import '../models/location_context.dart';
import '../models/vehicle_parameters.dart';
import '../providers/auth_provider.dart';
import '../services/hotspot_service.dart';
import '../services/location_enrichment_service.dart';
import '../services/ml_accident_detector.dart';
import '../services/training_data_service.dart';
import '../theme/app_colors.dart';
import '../widgets/accident_confirmation_dialog.dart';
import '../widgets/hotspot_warning_banner.dart';
import '../widgets/max_width_container.dart';
import '../widgets/ops_ui.dart';
import 'initial_login_screen.dart';
import 'ride_test_screen.dart';
import 'role_home_shell.dart';
import 'role_selection_screen.dart';

class DriverRoleShellScreen extends StatefulWidget {
  const DriverRoleShellScreen({super.key});

  @override
  State<DriverRoleShellScreen> createState() => _DriverRoleShellScreenState();
}

class _DriverRoleShellScreenState extends State<DriverRoleShellScreen> {
  final math.Random _random = math.Random();
  final Queue<VehicleParameters> _windowBuffer = Queue<VehicleParameters>();
  final TrainingDataService _trainingService = TrainingDataService();
  final Uuid _uuid = const Uuid();
  final List<double> _speedHistory = <double>[];
  final List<double> _impactHistory = <double>[];

  late final MLAccidentDetector _mlDetector;
  late final HotspotService _hotspotService;
  late final LocationEnrichmentService _enrichmentService;

  Timer? _timer;
  VehicleParameters? _params;
  AccidentPrediction? _latestPrediction;
  HotspotZone? _activeHotspot;
  double? _activeHotspotDistance;
  LocationContext _latestContext = LocationContext.unknown();
  bool _isMonitoring = true;
  bool _isAlertDialogOpen = false;
  DateTime? _lastAlertShownAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _mlDetector = context.read<MLAccidentDetector>();
      _hotspotService = context.read<HotspotService>();
      _enrichmentService = context.read<LocationEnrichmentService>();

      try {
        final zones = await _hotspotService.loadHotspots();
        _enrichmentService.updateHotspots(zones);
      } catch (_) {
        // Hotspot context is best effort on boot.
      }

      await _tick();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_isMonitoring && mounted) {
          await _tick();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final params = _generateMockParams();
    if (!mounted) return;

    setState(() {
      _params = params;
      _appendHistory(_speedHistory, params.speed);
      _appendHistory(_impactHistory, params.impactForce);
    });

    await _evaluateTelemetry(params);
  }

  void _appendHistory(List<double> target, double value) {
    target.add(value);
    while (target.length > 24) {
      target.removeAt(0);
    }
  }

  VehicleParameters _generateMockParams() {
    final now = DateTime.now();
    final etaMinutes = 6 + _random.nextInt(5);
    final routeProgress = 0.36 + _random.nextDouble() * 0.42;
    final riskBurst = _random.nextDouble() > 0.83;

    return VehicleParameters(
      deviceId: 'AMB-294',
      timestamp: now,
      accelerationX: (_random.nextDouble() - 0.5) * (riskBurst ? 6.0 : 2.3),
      accelerationY: (_random.nextDouble() - 0.5) * (riskBurst ? 4.8 : 1.9),
      accelerationZ: 0.95 + _random.nextDouble() * 0.4,
      speed: 46 + _random.nextDouble() * 22 + (riskBurst ? 10 : 0),
      location: GpsLocation(
        latitude: 28.6139 + (_random.nextDouble() - 0.5) * 0.02,
        longitude: 77.2090 + (_random.nextDouble() - 0.5) * 0.02,
        altitude: 190 + _random.nextDouble() * 25,
        accuracy: 2.5 + _random.nextDouble() * 2.5,
        timestamp: now,
      ),
      orientation: 160 + _random.nextDouble() * 90,
      impactForce: (riskBurst ? 2.0 : 0.55) + _random.nextDouble() * 1.2,
      additionalSensors: <String, dynamic>{
        'etaMinutes': etaMinutes,
        'routeProgress': routeProgress.clamp(0.0, 1.0),
        'hospital': 'St. Mary Emergency Center',
        'batteryVoltage': 13.6 + _random.nextDouble() * 1.1,
        'network': riskBurst ? '5G priority' : '5G strong',
      },
    );
  }

  Future<void> _evaluateTelemetry(VehicleParameters params) async {
    _windowBuffer.addLast(params);
    while (_windowBuffer.length > 5) {
      _windowBuffer.removeFirst();
    }

    final contextData = await _safeEnrichment(params.location);
    final prediction = _mlDetector.predict(_windowBuffer.toList(), contextData);
    final hotspot = _hotspotService.checkProximity(params.location);
    final hotspotDistance = hotspot == null
        ? null
        : _distanceMeters(
            params.location.latitude,
            params.location.longitude,
            hotspot.centerLat,
            hotspot.centerLng,
          );

    if (!mounted) return;
    setState(() {
      _latestPrediction = prediction;
      _activeHotspot = hotspot;
      _activeHotspotDistance = hotspotDistance;
      _latestContext = contextData;
    });

    final cooldownElapsed = _lastAlertShownAt == null ||
        DateTime.now().difference(_lastAlertShownAt!) >
            const Duration(seconds: 45);

    if (prediction.isAccident && !_isAlertDialogOpen && cooldownElapsed) {
      await _showAccidentDialog(
        params: params,
        ctx: contextData,
        prediction: prediction,
      );
    }
  }

  Future<LocationContext> _safeEnrichment(GpsLocation location) async {
    try {
      return await _enrichmentService.enrich(location);
    } catch (_) {
      return LocationContext.unknown();
    }
  }

  Future<void> _showAccidentDialog({
    required VehicleParameters params,
    required LocationContext ctx,
    required AccidentPrediction prediction,
  }) async {
    final eventId = _uuid.v4();
    _lastAlertShownAt = DateTime.now();
    _isAlertDialogOpen = true;

    final featureVector = [
      ...VehicleParameters.flattenWindow(_windowBuffer.toList()),
      ...ctx.toFeatureSlice(),
    ];
    await _trainingService.saveInferenceRecord(
      eventId: eventId,
      inputFeatures: featureVector,
      modelOutput: prediction,
      location: params.location,
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccidentConfirmationDialog(
        eventId: eventId,
        prediction: prediction,
        trainingService: _trainingService,
        onConfirm: () {},
        onDismiss: () {},
      ),
    );
    _isAlertDialogOpen = false;
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

  void _openRideTest() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RideTestScreen()),
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
      subtitle: 'ML-assisted vehicle shell',
      actions: [
        IconButton.filledTonal(
          onPressed: _openRideTest,
          icon: const Icon(Icons.route_rounded),
          tooltip: 'Ride Test',
        ),
      ],
      tabs: [
        RoleShellTab(
          label: 'Dashboard',
          icon: Icons.space_dashboard_rounded,
          child: ShellPage(child: _buildDashboard(params)),
        ),
        RoleShellTab(
          label: 'Map',
          icon: Icons.map_rounded,
          child: ShellPage(child: _buildMap(params)),
        ),
        RoleShellTab(
          label: 'Activity',
          icon: Icons.monitor_heart_rounded,
          child: ShellPage(child: _buildActivity(params)),
        ),
        RoleShellTab(
          label: 'Settings',
          icon: Icons.settings_rounded,
          child: ShellPage(child: _buildSettings()),
        ),
      ],
    );
  }

  Widget _buildDashboard(VehicleParameters params) {
    final prediction = _latestPrediction;
    final routeProgress =
        (params.additionalSensors['routeProgress'] as double?) ?? 0.0;
    final etaMinutes =
        params.additionalSensors['etaMinutes']?.toString() ?? '--';
    final destination =
        params.additionalSensors['hospital']?.toString() ?? '--';
    final activeHotspot = _activeHotspot;

    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          if (activeHotspot != null && _activeHotspotDistance != null)
            HotspotWarningBanner(
              zone: activeHotspot,
              distanceMeters: _activeHotspotDistance!,
              onDismiss: () {
                if (!mounted) return;
                setState(() {
                  _activeHotspot = null;
                  _activeHotspotDistance = null;
                });
              },
            ),
          OpsSectionCard(
            title: 'Vehicle telemetry',
            subtitle:
                'Live route health, destination readiness, and model state.',
            trailing: OpsStatusPill(
              label: _isMonitoring ? 'Live' : 'Paused',
              tone: _isMonitoring ? AppColors.success : AppColors.warning,
            ),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 820;
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
                            label: 'Speed',
                            value: '${params.speed.toStringAsFixed(0)} km/h',
                            helper: 'Current corridor pace',
                            icon: Icons.speed_rounded,
                            tone: AppColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: OpsMetricTile(
                            label: 'Impact force',
                            value: '${params.impactForce.toStringAsFixed(2)} g',
                            helper: 'Suspension and shock load',
                            icon: Icons.graphic_eq_rounded,
                            tone: AppColors.accent,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: OpsMetricTile(
                            label: 'Acceleration',
                            value:
                                '${params.totalAcceleration.toStringAsFixed(2)} m/s^2',
                            helper: 'Window motion summary',
                            icon: Icons.show_chart_rounded,
                            tone: AppColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: OpsMetricTile(
                            label: 'GPS status',
                            value: params.location.accuracy <= 5
                                ? 'Locked'
                                : 'Searching',
                            helper:
                                'Accuracy ${params.location.accuracy.toStringAsFixed(1)} m',
                            icon: Icons.gps_fixed_rounded,
                            tone: params.location.accuracy <= 5
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: OpsMetricTile(
                            label: 'Route progress',
                            value: '${(routeProgress * 100).round()}%',
                            helper: 'Current trip completion',
                            icon: Icons.alt_route_rounded,
                            tone: AppColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: OpsMetricTile(
                            label: 'ETA',
                            value: '$etaMinutes min',
                            helper: 'Current dispatch forecast',
                            icon: Icons.schedule_rounded,
                            tone: AppColors.primary,
                          ),
                        ),
                        SizedBox(
                          width:
                              isWide ? (width * 2) + OpsSpacing.tileGap : width,
                          child: OpsMetricTile(
                            label: 'Destination',
                            value: destination,
                            helper: '3.6 km away · Corridor pre-cleared',
                            icon: Icons.local_hospital_rounded,
                            tone: AppColors.primary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final split = constraints.maxWidth > 920;
              if (split) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: _buildPredictionCard(params)),
                    const SizedBox(width: OpsSpacing.sectionGap),
                    Expanded(
                      flex: 10,
                      child: SizedBox(
                        height: 360,
                        child: OpsRoutePreview(
                          title: 'Route intelligence',
                          badge: _activeHotspotDistance == null
                              ? 'Clear'
                              : '${_activeHotspotDistance!.round()} m',
                          risk: prediction?.accidentProbability ?? 0.24,
                          caution: prediction?.isAccident == true ||
                              _activeHotspot != null,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _buildPredictionCard(params),
                  const SizedBox(height: OpsSpacing.sectionGap),
                  SizedBox(
                    height: 320,
                    child: OpsRoutePreview(
                      title: 'Route intelligence',
                      badge: _activeHotspotDistance == null
                          ? 'Clear'
                          : '${_activeHotspotDistance!.round()} m',
                      risk: prediction?.accidentProbability ?? 0.24,
                      caution: prediction?.isAccident == true ||
                          _activeHotspot != null,
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
                  children: [
                    Expanded(
                      child: OpsSparklineCard(
                        title: 'Speed trend',
                        valueLabel: params.speed.toStringAsFixed(0),
                        tone: AppColors.primary,
                        points: _speedHistory,
                      ),
                    ),
                    const SizedBox(width: OpsSpacing.sectionGap),
                    Expanded(
                      child: OpsSparklineCard(
                        title: 'Impact trend',
                        valueLabel: params.impactForce.toStringAsFixed(2),
                        tone: AppColors.accent,
                        points: _impactHistory,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  OpsSparklineCard(
                    title: 'Speed trend',
                    valueLabel: params.speed.toStringAsFixed(0),
                    tone: AppColors.primary,
                    points: _speedHistory,
                  ),
                  const SizedBox(height: OpsSpacing.sectionGap),
                  OpsSparklineCard(
                    title: 'Impact trend',
                    valueLabel: params.impactForce.toStringAsFixed(2),
                    tone: AppColors.accent,
                    points: _impactHistory,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          OpsOperationalStrip(
            items: [
              OpsOperationalItem(
                label: 'Incident watch',
                value: prediction?.isAccident == true ? 'Active' : 'Stable',
                helper: activeHotspot == null
                    ? 'No active geofence'
                    : '${activeHotspot.incidentCount} incidents nearby',
                icon: Icons.visibility_rounded,
                tone: prediction?.isAccident == true
                    ? AppColors.error
                    : AppColors.warning,
              ),
              OpsOperationalItem(
                label: 'System sync',
                value: _mlDetector.isLoaded ? 'Synced' : 'Fallback',
                helper: _formatClock(params.timestamp),
                icon: Icons.cloud_done_rounded,
                tone: _mlDetector.isLoaded
                    ? AppColors.success
                    : AppColors.warning,
              ),
              OpsOperationalItem(
                label: 'Vehicle',
                value:
                    '${params.additionalSensors['batteryVoltage']?.toStringAsFixed(1) ?? '14.0'} V',
                helper: params.deviceId,
                icon: Icons.battery_charging_full_rounded,
                tone: AppColors.success,
              ),
              OpsOperationalItem(
                label: 'Network',
                value: '5G',
                helper:
                    params.additionalSensors['network']?.toString() ?? 'Strong',
                icon: Icons.network_cell_rounded,
                tone: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OpsActionButton(
                label: 'Toggle monitoring',
                icon: _isMonitoring
                    ? Icons.pause_circle_rounded
                    : Icons.play_circle_fill_rounded,
                tone: _isMonitoring ? AppColors.warning : AppColors.success,
                onTap: () => setState(() => _isMonitoring = !_isMonitoring),
              ),
              OpsActionButton(
                label: 'Share route',
                icon: Icons.share_location_rounded,
                tone: AppColors.primary,
                onTap: () {},
              ),
              OpsActionButton(
                label: 'Call hospital',
                icon: Icons.call_rounded,
                tone: AppColors.accent,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(VehicleParameters params) {
    final prediction = _latestPrediction;
    final riskTone = _riskTone(prediction);
    final riskPercent =
        ((prediction?.accidentProbability ?? 0.18) * 100).round().toString();

    return OpsSectionCard(
      title: 'Accident risk prediction',
      subtitle:
          'Five-sample motion window plus hotspot and context enrichment.',
      tone: riskTone,
      trailing: Icon(Icons.info_outline_rounded, color: riskTone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$riskPercent%',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: riskTone,
                      ),
                ),
              ),
              OpsStatusPill(
                label: _riskLabel(prediction),
                tone: riskTone,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GaugeBar(
            progress: prediction?.accidentProbability ?? 0.18,
            tone: riskTone,
          ),
          const SizedBox(height: 18),
          OpsInfoRow(
            label: 'Severity',
            value: _titleCase(prediction?.severityClass ?? 'minor'),
            valueColor: riskTone,
          ),
          OpsInfoRow(
            label: 'Type',
            value: _titleCase(prediction?.accidentType ?? 'near_miss'),
          ),
          OpsInfoRow(
            label: 'Trend',
            value: _historyTrend(),
            valueColor: _historyTrend().startsWith('+')
                ? AppColors.error
                : AppColors.success,
          ),
          OpsInfoRow(
            label: 'Context',
            value:
                _latestContext.isKnownHotspot ? 'Hotspot-aware' : 'Road-normal',
          ),
        ],
      ),
    );
  }

  Widget _buildMap(VehicleParameters params) {
    final routeProgress =
        (params.additionalSensors['routeProgress'] as double?) ?? 0.0;

    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          OpsSectionCard(
            title: 'Route intelligence',
            subtitle:
                'Hotspot proximity, ETA context, and live route readiness.',
            trailing: OpsStatusPill(
              label: _activeHotspot == null ? 'Clear route' : 'Caution',
              tone: _activeHotspot == null
                  ? AppColors.success
                  : AppColors.warning,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 360,
                  child: OpsRoutePreview(
                    title: 'Primary corridor',
                    badge: _activeHotspotDistance == null
                        ? 'Clear'
                        : '${_activeHotspotDistance!.round()} m',
                    risk: _latestPrediction?.accidentProbability ?? 0.2,
                    caution: _activeHotspot != null,
                  ),
                ),
                const SizedBox(height: 18),
                OpsInfoRow(
                  label: 'Destination',
                  value: params.additionalSensors['hospital']?.toString() ??
                      'Unknown',
                ),
                OpsInfoRow(
                  label: 'Nearest hotspot',
                  value: _activeHotspot == null
                      ? 'No active hotspot in route buffer'
                      : '${_activeHotspot!.incidentCount} incidents · ${(_activeHotspotDistance! / 1000).toStringAsFixed(1)} km',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Route progress',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: OpsPalette.textSecondary(context),
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '${(routeProgress * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: routeProgress.clamp(0.0, 1.0),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivity(VehicleParameters params) {
    final prediction = _latestPrediction;
    final timeline = [
      _TimelineItem(
        title: _mlDetector.isLoaded
            ? 'Model adapter active'
            : 'Rule fallback active',
        subtitle: _mlDetector.modelSource ?? 'bundled_asset',
        tone: _mlDetector.isLoaded ? AppColors.success : AppColors.warning,
        icon: Icons.memory_rounded,
      ),
      _TimelineItem(
        title:
            _activeHotspot == null ? 'Route clear' : 'Hotspot warning issued',
        subtitle: _activeHotspot == null
            ? 'No geofence trigger in active route'
            : '${_activeHotspot!.incidentCount} historical incidents near corridor',
        tone: _activeHotspot == null ? AppColors.success : AppColors.warning,
        icon: Icons.route_rounded,
      ),
      _TimelineItem(
        title: prediction?.isAccident == true
            ? 'Accident escalation prepared'
            : 'Prediction loop stable',
        subtitle: prediction == null
            ? 'Awaiting first inference'
            : '${_titleCase(prediction.accidentType)} · ${_titleCase(prediction.severityClass)}',
        tone: _riskTone(prediction),
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return MaxWidthContainer(
      maxWidth: 1180,
      child: Column(
        children: [
          OpsSectionCard(
            title: 'Sensor and data snapshot',
            subtitle: 'Latest window payload and derived context.',
            child: Column(
              children: [
                OpsInfoRow(label: 'Vehicle ID', value: params.deviceId),
                OpsInfoRow(
                    label: 'Timestamp', value: _formatClock(params.timestamp)),
                OpsInfoRow(
                  label: 'Latitude',
                  value: params.location.latitude.toStringAsFixed(6),
                ),
                OpsInfoRow(
                  label: 'Longitude',
                  value: params.location.longitude.toStringAsFixed(6),
                ),
                OpsInfoRow(
                  label: 'Total acceleration',
                  value: '${params.totalAcceleration.toStringAsFixed(2)} G',
                ),
                OpsInfoRow(
                  label: 'Road context',
                  value:
                      'Road ${_latestContext.roadTypeEncoded} · Weather ${_latestContext.weatherEncoded}',
                ),
              ],
            ),
          ),
          const SizedBox(height: OpsSpacing.sectionGap),
          OpsSectionCard(
            title: 'Recent activity',
            subtitle:
                'Operational timeline of data collection, telemetry, and hotspot state.',
            child: Column(
              children: [
                for (final item in timeline) ...[
                  _DriverTimelineTile(item: item),
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
            title: 'Driver controls',
            subtitle:
                'Monitoring and data collection settings for the live ops shell.',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _isMonitoring,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Live monitoring'),
                  subtitle: const Text(
                    'Pause telemetry updates without leaving the driver shell.',
                  ),
                  onChanged: (value) => setState(() => _isMonitoring = value),
                ),
                OpsInfoRow(
                  label: 'Detection source',
                  value: _mlDetector.modelSource ?? 'unknown',
                ),
                OpsInfoRow(
                  label: 'Hotspot cache',
                  value: '${_hotspotService.cachedZones.length} zones',
                ),
                const OpsInfoRow(
                  label: 'Driver label loop',
                  value: 'Enabled',
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
                label: 'Switch role',
                icon: Icons.swap_horiz_rounded,
                tone: AppColors.warning,
                onTap: _switchRole,
              ),
              OpsActionButton(
                label: 'Ride test',
                icon: Icons.route_rounded,
                tone: AppColors.accent,
                onTap: _openRideTest,
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

  Color _riskTone(AccidentPrediction? prediction) {
    if (prediction == null) return AppColors.primary;
    if (prediction.isAccident) return AppColors.error;
    if (prediction.isNearMiss) return AppColors.warning;
    return AppColors.success;
  }

  String _riskLabel(AccidentPrediction? prediction) {
    if (prediction == null) return 'Assessing';
    if (prediction.isAccident) return 'High risk';
    if (prediction.isNearMiss) return 'Near miss';
    return 'Normal';
  }

  String _historyTrend() {
    if (_speedHistory.length < 2) return 'Stable';
    final first = _speedHistory.first;
    final last = _speedHistory.last;
    final delta = ((last - first) / first) * 100;
    final prefix = delta >= 0 ? '+' : '';
    return '$prefix${delta.toStringAsFixed(0)}% vs 5 min';
  }

  String _titleCase(String input) {
    if (input.isEmpty) return 'Unknown';
    return input
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _GaugeBar extends StatelessWidget {
  final double progress;
  final Color tone;

  const _GaugeBar({
    required this.progress,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 16,
        backgroundColor: tone.withValues(alpha: 0.14),
        valueColor: AlwaysStoppedAnimation<Color>(tone),
      ),
    );
  }
}

class _TimelineItem {
  final String title;
  final String subtitle;
  final Color tone;
  final IconData icon;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.icon,
  });
}

class _DriverTimelineTile extends StatelessWidget {
  final _TimelineItem item;

  const _DriverTimelineTile({required this.item});

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

String _formatClock(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final second = dateTime.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
