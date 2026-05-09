import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/ride_test_session.dart';
import '../services/esp32_service.dart';
import '../services/iot_data_orchestrator_mobile.dart'
    if (dart.library.html) '../services/iot_data_orchestrator_web.dart';
import '../services/ride_test_service.dart';
import '../widgets/max_width_container.dart';

enum _RideTestUiState {
  idle,
  recording,
  stopped,
}

class RideTestScreen extends StatefulWidget {
  const RideTestScreen({super.key});

  @override
  State<RideTestScreen> createState() => _RideTestScreenState();
}

class _RideTestScreenState extends State<RideTestScreen> {
  late final RideTestService _service;
  late final ESP32Service _esp32Service;
  late final IoTDataOrchestrator _orchestrator;
  final TextEditingController _notesController = TextEditingController();

  _RideTestUiState _state = _RideTestUiState.idle;
  RideTestSessionType _sessionType = RideTestSessionType.rideTest;
  RideTestVehicleMode _vehicleMode = RideTestVehicleMode.bike;
  RideTestSession? _activeSession;
  RideTestSession? _stoppedSession;
  RideTestSample? _latestSample;
  List<RideTestSessionSummary> _sessions = [];
  StreamSubscription<RideTestSession>? _sessionSubscription;
  Timer? _ticker;
  Timer? _stopHoldTimer;
  bool _isStopping = false;
  bool _isSaving = false;
  bool _isLoadingSessions = true;
  bool _holdInProgress = false;

  bool get _hasDevice => _esp32Service.connectedDevices.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _esp32Service = context.read<ESP32Service>();
    _orchestrator = context.read<IoTDataOrchestrator>();
    _service = RideTestService(esp32Service: _esp32Service);
    _sessionSubscription = _service.sessionStream.listen((session) {
      if (!mounted) return;
      setState(() {
        _activeSession = session;
        _latestSample = session.samples.isEmpty ? null : session.samples.last;
      });
    });
    _loadSessions();
  }

  @override
  void dispose() {
    if (_state == _RideTestUiState.recording) {
      unawaited(_orchestrator.stopRoadDataCollection());
    }
    _ticker?.cancel();
    _stopHoldTimer?.cancel();
    _sessionSubscription?.cancel();
    _service.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await _service.getSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoadingSessions = false;
    });
  }

  Future<void> _startSession() async {
    final startLocation = await _service.getCurrentLocation();
    final session = await _service.startSession(
      sessionType: _sessionType,
      vehicleMode: _vehicleMode,
      startLocation: startLocation,
    );
    _orchestrator.startRoadDataCollection(
      tripId: session.sessionId,
      startTime: session.startTime,
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    if (!mounted) return;
    setState(() {
      _state = _RideTestUiState.recording;
      _activeSession = session;
      _latestSample = null;
      _stoppedSession = null;
      _notesController.clear();
    });
  }

  void _beginStopHold() {
    if (_isStopping) return;
    setState(() => _holdInProgress = true);
    _stopHoldTimer?.cancel();
    _stopHoldTimer = Timer(const Duration(seconds: 2), _stopSession);
  }

  void _cancelStopHold() {
    _stopHoldTimer?.cancel();
    if (mounted) setState(() => _holdInProgress = false);
  }

  Future<void> _stopSession() async {
    if (_isStopping) return;
    setState(() {
      _isStopping = true;
      _holdInProgress = false;
    });

    final stopLocation = await _service.getCurrentLocation();
    final session = await _service.stopSession(
      stopLocation: stopLocation,
      save: false,
    );
    await _orchestrator.stopRoadDataCollection(
      endTime: session.stopTime,
    );

    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _state = _RideTestUiState.stopped;
      _stoppedSession = session;
      _activeSession = session;
      _isStopping = false;
    });
  }

  Future<void> _saveStoppedSession() async {
    final session = _stoppedSession;
    if (session == null || _isSaving) return;
    setState(() => _isSaving = true);

    final saved = await _service.saveSession(
      session,
      notes: _notesController.text,
    );
    await _loadSessions();

    if (!mounted) return;
    setState(() {
      _state = _RideTestUiState.idle;
      _stoppedSession = null;
      _activeSession = null;
      _latestSample = null;
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved.uploadedToFirestore
              ? 'Ride test saved locally and uploaded.'
              : 'Ride test saved locally. Firestore upload can be retried later.',
        ),
      ),
    );
  }

  Future<void> _discardStoppedSession() async {
    await _orchestrator.stopRoadDataCollection();
    await _service.discardCurrentSession();
    if (!mounted) return;
    setState(() {
      _state = _RideTestUiState.idle;
      _stoppedSession = null;
      _activeSession = null;
      _latestSample = null;
      _notesController.clear();
    });
  }

  Future<void> _openSessionDetail(RideTestSessionSummary summary) async {
    final session = await _service.loadSession(summary.sessionId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideTestSessionDetailScreen(
          session: session,
          service: _service,
        ),
      ),
    );
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Test Recorder'),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_hasDevice) _buildWarningBanner(),
              if (_state == _RideTestUiState.idle) _buildIdleState(),
              if (_state == _RideTestUiState.recording) _buildRecordingState(),
              if (_state == _RideTestUiState.stopped) _buildStoppedState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sensors_off, color: AppTheme.accent),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ESP32 is not connected. Recording can still start with GPS and low-noise fallback samples.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Session setup',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              _buildSegmented<RideTestSessionType>(
                value: _sessionType,
                values: RideTestSessionType.values,
                labelBuilder: (type) => type.label,
                onChanged: (type) => setState(() => _sessionType = type),
              ),
              const SizedBox(height: 12),
              _buildSegmented<RideTestVehicleMode>(
                value: _vehicleMode,
                values: RideTestVehicleMode.values,
                labelBuilder: (mode) => mode.label,
                onChanged: (mode) => setState(() => _vehicleMode = mode),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _startSession,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('START'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Past sessions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingSessions)
          const Center(child: CircularProgressIndicator())
        else if (_sessions.isEmpty)
          _buildEmptySessions()
        else
          ..._sessions.map(_buildSessionTile),
      ],
    );
  }

  Widget _buildRecordingState() {
    final session = _activeSession;
    final elapsed = session == null
        ? Duration.zero
        : DateTime.now().difference(session.startTime);
    final sample = _latestSample;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          child: Column(
            children: [
              Row(
                children: [
                  _buildRecIndicator(),
                  const SizedBox(width: 10),
                  Text(
                    'REC ${_formatDuration(elapsed)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${_service.sampleCount} samples',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildLiveMetric(
                      'Speed',
                      sample?.speed.toStringAsFixed(1) ?? '--',
                      'km/h',
                      Icons.speed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLiveMetric(
                      'G-force',
                      sample?.totalAcceleration.toStringAsFixed(2) ?? '--',
                      'G',
                      Icons.vibration,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildLiveMetric(
                      'GPS Acc.',
                      _activeSession?.startLocation.accuracy
                              .toStringAsFixed(1) ??
                          '--',
                      'm',
                      Icons.gps_fixed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLiveMetric(
                      'Samples',
                      _service.sampleCount.toString(),
                      'recorded',
                      Icons.storage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildCoordinateBlock(sample),
              const SizedBox(height: 22),
              GestureDetector(
                onLongPressStart: (_) => _beginStopHold(),
                onLongPressEnd: (_) => _cancelStopHold(),
                onLongPressCancel: _cancelStopHold,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _holdInProgress
                        ? AppTheme.error.withValues(alpha: 0.75)
                        : AppTheme.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _isStopping
                        ? 'Stopping...'
                        : _holdInProgress
                            ? 'Keep holding'
                            : 'HOLD 2 SEC TO STOP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoppedState() {
    final session = _stoppedSession;
    if (session == null) return const SizedBox.shrink();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Review session',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Add a note about this session',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRows(session),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _discardStoppedSession,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('DISCARD'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveStoppedSession,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'SAVING' : 'SAVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmented<T>({
    required T value,
    required List<T> values,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return SegmentedButton<T>(
      segments: values
          .map(
            (item) => ButtonSegment<T>(
              value: item,
              label: Text(labelBuilder(item)),
            ),
          )
          .toList(),
      selected: {value},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: child,
    );
  }

  Widget _buildEmptySessions() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text('No ride test sessions yet.'),
    );
  }

  Widget _buildSessionTile(RideTestSessionSummary summary) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.monitoringActive.withValues(alpha: 0.12),
          child: Icon(
            summary.vehicleMode == RideTestVehicleMode.bike
                ? Icons.two_wheeler
                : Icons.directions_car,
            color: AppTheme.monitoringActive,
          ),
        ),
        title:
            Text('${summary.sessionType.label} - ${summary.vehicleMode.label}'),
        subtitle: Text(
          '${_formatDate(summary.startTime)} • ${_formatDuration(Duration(seconds: summary.durationSeconds))} • ${summary.totalSamples} samples',
        ),
        trailing: Icon(
          summary.uploadedToFirestore ? Icons.cloud_done : Icons.save,
          color: summary.uploadedToFirestore
              ? AppTheme.success
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        onTap: () => _openSessionDetail(summary),
      ),
    );
  }

  Widget _buildRecIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted && _state == _RideTestUiState.recording) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildLiveMetric(
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.monitoringActive),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $unit',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateBlock(RideTestSample? sample) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        sample == null
            ? 'Current GPS: waiting for first sample'
            : 'Current GPS: ${sample.latitude.toStringAsFixed(6)}, ${sample.longitude.toStringAsFixed(6)}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
      ),
    );
  }

  Widget _buildSummaryRows(RideTestSession session) {
    return Column(
      children: [
        _summaryRow(
            'Duration',
            _formatDuration(
              Duration(seconds: session.durationSeconds),
            )),
        _summaryRow('Samples', session.totalSamples.toString()),
        _summaryRow(
          'Start',
          '${session.startLocation.latitude.toStringAsFixed(5)}, ${session.startLocation.longitude.toStringAsFixed(5)}',
        ),
        _summaryRow(
          'Stop',
          '${session.stopLocation?.latitude.toStringAsFixed(5) ?? '--'}, ${session.stopLocation?.longitude.toStringAsFixed(5) ?? '--'}',
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class RideTestSessionDetailScreen extends StatefulWidget {
  const RideTestSessionDetailScreen({
    super.key,
    required this.session,
    required this.service,
  });

  final RideTestSession session;
  final RideTestService service;

  @override
  State<RideTestSessionDetailScreen> createState() =>
      _RideTestSessionDetailScreenState();
}

class _RideTestSessionDetailScreenState
    extends State<RideTestSessionDetailScreen> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final stats = session.stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Test Details'),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _detailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.sessionType.label} - ${session.vehicleMode.label}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(_formatDate(session.startTime)),
                    const SizedBox(height: 16),
                    _detailRow(
                        'Duration',
                        _formatDuration(
                          Duration(seconds: session.durationSeconds),
                        )),
                    _detailRow('Samples', session.totalSamples.toString()),
                    _detailRow('Uploaded',
                        session.uploadedToFirestore ? 'Yes' : 'Local only'),
                    if (session.notes.trim().isNotEmpty)
                      _detailRow('Notes', session.notes),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _detailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header('Locations'),
                    _detailRow('Start',
                        '${session.startLocation.latitude.toStringAsFixed(6)}, ${session.startLocation.longitude.toStringAsFixed(6)}'),
                    _detailRow('Stop',
                        '${session.stopLocation?.latitude.toStringAsFixed(6) ?? '--'}, ${session.stopLocation?.longitude.toStringAsFixed(6) ?? '--'}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _detailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header('Stats'),
                    _detailRow('Speed min/max/avg',
                        '${stats.minSpeed.toStringAsFixed(1)} / ${stats.maxSpeed.toStringAsFixed(1)} / ${stats.avgSpeed.toStringAsFixed(1)} km/h'),
                    _detailRow('G min/max/avg',
                        '${stats.minGForce.toStringAsFixed(2)} / ${stats.maxGForce.toStringAsFixed(2)} / ${stats.avgGForce.toStringAsFixed(2)} G'),
                    _detailRow('Distance estimate',
                        '${stats.distanceMeters.toStringAsFixed(0)} m'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.file_download),
                label: const Text('Export as CSV'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _deleting ? null : _deleteSession,
                icon: const Icon(Icons.delete_outline),
                label: Text(_deleting ? 'Deleting' : 'Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final csv = await widget.service.exportSessionCsv(widget.session.sessionId);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to clipboard.')),
    );
  }

  Future<void> _deleteSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content:
            const Text('This removes the local JSON file and index entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    await widget.service.deleteSession(widget.session.sessionId);
    if (mounted) Navigator.pop(context);
  }

  Widget _detailCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.neumorphicShadow(),
      ),
      child: child,
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
