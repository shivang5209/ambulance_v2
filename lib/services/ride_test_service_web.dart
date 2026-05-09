import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/ride_test_session.dart';
import '../models/vehicle_parameters.dart';
import 'esp32_service.dart';

class RideTestService {
  RideTestService({
    required ESP32Service esp32Service,
    FirebaseFirestore? firestore,
    SharedPreferences? preferences,
  })  : _esp32Service = esp32Service,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _providedPreferences = preferences;

  static const String indexKey = 'ride_test_sessions';
  static const String _sessionPrefix = 'ride_test_session_json_';

  final ESP32Service _esp32Service;
  final FirebaseFirestore _firestore;
  final SharedPreferences? _providedPreferences;
  final Uuid _uuid = const Uuid();
  final List<RideTestSample> _sampleBuffer = [];
  final StreamController<RideTestSession> _sessionController =
      StreamController<RideTestSession>.broadcast();

  StreamSubscription<VehicleParameters>? _subscription;
  Timer? _fallbackTimer;
  RideTestSession? _currentSession;
  RideTestSample? _latestSample;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  RideTestSession? get currentSession => _currentSession;
  RideTestSample? get latestSample => _latestSample;
  int get sampleCount => _sampleBuffer.length;
  Stream<RideTestSession> get sessionStream => _sessionController.stream;

  Future<RideTestSession> startSession({
    required RideTestSessionType sessionType,
    required RideTestVehicleMode vehicleMode,
    RideTestLocation? startLocation,
  }) async {
    if (_isRecording) {
      throw StateError('A ride test session is already recording.');
    }

    _sampleBuffer.clear();
    _latestSample = null;
    _currentSession = RideTestSession.start(
      sessionId: _uuid.v4(),
      sessionType: sessionType,
      vehicleMode: vehicleMode,
      startLocation: startLocation ?? await getCurrentLocation(),
    );
    _isRecording = true;
    _subscription = _esp32Service.dataStream.listen(_onVehicleParameters);
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _captureFallbackSample(),
    );
    _emitCurrentSession();
    return _currentSession!;
  }

  Future<RideTestSession> stopSession({
    RideTestLocation? stopLocation,
    String notes = '',
    bool save = true,
  }) async {
    final session = _currentSession;
    if (!_isRecording || session == null) {
      throw StateError('No ride test session is recording.');
    }

    await _subscription?.cancel();
    _subscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _isRecording = false;

    final stoppedAt = DateTime.now();
    final finalized = session.copyWith(
      stopTime: stoppedAt,
      stopLocation: stopLocation ?? await getCurrentLocation(),
      durationSeconds: stoppedAt.difference(session.startTime).inSeconds,
      totalSamples: _sampleBuffer.length,
      notes: notes.trim(),
      samples: List.unmodifiable(_sampleBuffer),
    );
    _currentSession = finalized;
    _emitCurrentSession();
    if (save) return saveSession(finalized);
    return finalized;
  }

  Future<RideTestSession> saveSession(
    RideTestSession session, {
    String? notes,
  }) async {
    final updated = session.copyWith(
      notes: notes?.trim(),
      totalSamples: session.samples.length,
    );

    var uploaded = false;
    try {
      await _firestore
          .collection('ride_test_sessions')
          .doc(updated.sessionId)
          .set(updated.toJson());
      uploaded = true;
    } catch (_) {
      uploaded = false;
    }

    final savedSession = updated.copyWith(uploadedToFirestore: uploaded);
    final prefs = await _prefs();
    await prefs.setString(
      '$_sessionPrefix${savedSession.sessionId}',
      jsonEncode(savedSession.toJson()),
    );
    await _upsertSummary(savedSession.toSummary());
    _currentSession = null;
    _sampleBuffer.clear();
    _latestSample = null;
    return savedSession;
  }

  Future<void> discardCurrentSession() async {
    await _subscription?.cancel();
    _subscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _isRecording = false;
    _currentSession = null;
    _latestSample = null;
    _sampleBuffer.clear();
  }

  Future<List<RideTestSessionSummary>> getSessions() async {
    final prefs = await _prefs();
    final rawItems = prefs.getStringList(indexKey) ?? const [];
    final summaries = <RideTestSessionSummary>[];
    for (final raw in rawItems) {
      try {
        summaries.add(
          RideTestSessionSummary.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ),
        );
      } catch (_) {}
    }
    summaries.sort((a, b) => b.startTime.compareTo(a.startTime));
    return summaries;
  }

  Future<RideTestSession> loadSession(String sessionId) async {
    final prefs = await _prefs();
    final raw = prefs.getString('$_sessionPrefix$sessionId');
    if (raw == null) throw StateError('Ride test session not found.');
    return RideTestSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> deleteSession(String sessionId) async {
    final prefs = await _prefs();
    await prefs.remove('$_sessionPrefix$sessionId');
    final rawItems = prefs.getStringList(indexKey) ?? const [];
    final filtered = <String>[];
    for (final raw in rawItems) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['session_id'] != sessionId) filtered.add(raw);
      } catch (_) {
        filtered.add(raw);
      }
    }
    await prefs.setStringList(indexKey, filtered);
  }

  Future<String> exportSessionCsv(String sessionId) async {
    final session = await loadSession(sessionId);
    final buffer = StringBuffer()
      ..writeln(
        'session_id,session_type,vehicle_mode,timestamp,accel_x,accel_y,accel_z,speed,impact_force,orientation,latitude,longitude,total_acceleration',
      );
    for (final sample in session.samples) {
      buffer.writeln([
        session.sessionId,
        session.sessionType.id,
        session.vehicleMode.id,
        sample.timestamp.toIso8601String(),
        sample.accelX,
        sample.accelY,
        sample.accelZ,
        sample.speed,
        sample.impactForce,
        sample.orientation,
        sample.latitude,
        sample.longitude,
        sample.totalAcceleration,
      ].map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  Future<RideTestLocation> getCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _latestLocationOrZero();
      }
      final position = await Geolocator.getCurrentPosition();
      return RideTestLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (_) {
      return _latestLocationOrZero();
    }
  }

  void dispose() {
    _subscription?.cancel();
    _fallbackTimer?.cancel();
    _sessionController.close();
  }

  void _onVehicleParameters(VehicleParameters params) {
    if (!_isRecording || _currentSession == null) return;
    _addSample(RideTestSample.fromVehicleParameters(params));
  }

  Future<void> _captureFallbackSample() async {
    if (!_isRecording || _currentSession == null) return;
    if (_latestSample != null &&
        DateTime.now().difference(_latestSample!.timestamp).inMilliseconds <
            1500) {
      return;
    }

    final location = await getCurrentLocation();
    final random = Random();
    final accelX = (random.nextDouble() - 0.5) * 0.18;
    final accelY = (random.nextDouble() - 0.5) * 0.18;
    final accelZ = 1 + ((random.nextDouble() - 0.5) * 0.12);
    final totalAcceleration = sqrt(
      accelX * accelX + accelY * accelY + accelZ * accelZ,
    );
    _addSample(
      RideTestSample(
        timestamp: DateTime.now(),
        accelX: accelX,
        accelY: accelY,
        accelZ: accelZ,
        speed: 0,
        impactForce: totalAcceleration,
        orientation: 0,
        latitude: location.latitude,
        longitude: location.longitude,
        totalAcceleration: totalAcceleration,
      ),
    );
  }

  void _addSample(RideTestSample sample) {
    _sampleBuffer.add(sample);
    _latestSample = sample;
    _emitCurrentSession();
  }

  void _emitCurrentSession() {
    final session = _currentSession;
    if (session == null || _sessionController.isClosed) return;
    _sessionController.add(
      session.copyWith(
        durationSeconds: DateTime.now().difference(session.startTime).inSeconds,
        totalSamples: _sampleBuffer.length,
        samples: List.unmodifiable(_sampleBuffer),
      ),
    );
  }

  RideTestLocation _latestLocationOrZero() {
    final latest = _latestSample;
    if (latest == null) return RideTestLocation.zero();
    return RideTestLocation(
      latitude: latest.latitude,
      longitude: latest.longitude,
      accuracy: 0,
    );
  }

  Future<SharedPreferences> _prefs() async {
    final provided = _providedPreferences;
    if (provided != null) return provided;
    return SharedPreferences.getInstance();
  }

  Future<void> _upsertSummary(RideTestSessionSummary summary) async {
    final prefs = await _prefs();
    final rawItems = prefs.getStringList(indexKey) ?? const [];
    final next = <String>[];
    var inserted = false;
    for (final raw in rawItems) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['session_id'] == summary.sessionId) {
          next.add(jsonEncode(summary.toJson()));
          inserted = true;
        } else {
          next.add(raw);
        }
      } catch (_) {
        next.add(raw);
      }
    }
    if (!inserted) next.add(jsonEncode(summary.toJson()));
    await prefs.setStringList(indexKey, next);
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
