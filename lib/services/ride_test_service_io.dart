import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/ride_test_session.dart';
import '../models/vehicle_parameters.dart';
import 'esp32_service.dart';
import 'supabase_repository.dart';

class RideTestService {
  RideTestService({
    required ESP32Service esp32Service,
    FirebaseFirestore? firestore,
    SharedPreferences? preferences,
    SupabaseRepository? supabaseRepository,
  })  : _esp32Service = esp32Service,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _providedPreferences = preferences,
        _supabaseRepository = supabaseRepository ?? SupabaseRepository();

  static const String indexKey = 'ride_test_sessions';

  final ESP32Service _esp32Service;
  final FirebaseFirestore _firestore;
  final SharedPreferences? _providedPreferences;
  final SupabaseRepository _supabaseRepository;
  final Uuid _uuid = const Uuid();
  final List<RideTestSample> _sampleBuffer = [];
  final StreamController<RideTestSession> _sessionController =
      StreamController<RideTestSession>.broadcast();

  StreamSubscription<VehicleParameters>? _subscription;
  Timer? _fallbackTimer;
  RideTestSession? _currentSession;
  RideTestSample? _latestSample;
  DateTime? _lastRideProgressSent;
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

    final location = startLocation ?? await getCurrentLocation();
    _sampleBuffer.clear();
    _latestSample = null;
    _lastRideProgressSent = null;
    _currentSession = RideTestSession.start(
      sessionId: _uuid.v4(),
      sessionType: sessionType,
      vehicleMode: vehicleMode,
      startLocation: location,
    );
    _isRecording = true;

    _subscription = _esp32Service.dataStream.listen(_onVehicleParameters);
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _captureFallbackSample(),
    );

    await _writeSessionMetadata('recording', _currentSession!);
    unawaited(_esp32Service.notifyRideStarted(
      sessionId: _currentSession!.sessionId,
      startedAt: _currentSession!.startTime,
    ));
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
    final location = stopLocation ?? await getCurrentLocation();
    final finalized = session.copyWith(
      stopTime: stoppedAt,
      stopLocation: location,
      durationSeconds: stoppedAt.difference(session.startTime).inSeconds,
      totalSamples: _sampleBuffer.length,
      notes: notes.trim(),
      samples: List.unmodifiable(_sampleBuffer),
    );
    _currentSession = finalized;
    _emitCurrentSession();

    if (save) {
      return saveSession(finalized, notes: notes);
    }
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

    final file = await _sessionFile(updated.sessionId);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(updated.toJson()),
    );

    final exportPath = await _uploadSessionExport(updated);
    final savedSession = updated.copyWith(
      uploadedToSupabase: exportPath != null,
      supabaseExportPath: exportPath,
    );
    final uploaded = await _writeSessionMetadata('completed', savedSession);
    final finalSession = savedSession.copyWith(uploadedToFirestore: uploaded);
    if (uploaded) {
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(finalSession.toJson()),
      );
    }
    await _upsertSummary(finalSession.toSummary());
    unawaited(_esp32Service.notifyRideFinished(
      sessionId: finalSession.sessionId,
      stoppedAt: finalSession.stopTime ?? DateTime.now(),
      durationSeconds: finalSession.durationSeconds,
      totalSamples: finalSession.totalSamples,
      uploadedToSupabase: finalSession.uploadedToSupabase,
    ));
    _currentSession = null;
    _sampleBuffer.clear();
    _latestSample = null;
    _lastRideProgressSent = null;
    return finalSession;
  }

  Future<void> discardCurrentSession() async {
    await _subscription?.cancel();
    _subscription = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _isRecording = false;
    _currentSession = null;
    _latestSample = null;
    _lastRideProgressSent = null;
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
      } catch (_) {
        // Ignore legacy or corrupt index rows; full JSON files remain intact.
      }
    }

    summaries.sort((a, b) => b.startTime.compareTo(a.startTime));
    return summaries;
  }

  Future<RideTestSession> loadSession(String sessionId) async {
    final file = await _sessionFile(sessionId);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return RideTestSession.fromJson(json);
  }

  Future<void> deleteSession(String sessionId) async {
    final file = await _sessionFile(sessionId);
    if (await file.exists()) {
      await file.delete();
    }

    final prefs = await _prefs();
    final rawItems = prefs.getStringList(indexKey) ?? const [];
    final filtered = <String>[];
    for (final raw in rawItems) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['session_id'] != sessionId) {
          filtered.add(raw);
        }
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
      buffer.writeln(
        [
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
        ].map(_csvCell).join(','),
      );
    }

    return buffer.toString();
  }

  Future<RideTestSession> startRideSession({
    required RideTestSessionType sessionType,
    required RideTestVehicleMode vehicleMode,
    RideTestLocation? startLocation,
  }) {
    return startSession(
      sessionType: sessionType,
      vehicleMode: vehicleMode,
      startLocation: startLocation,
    );
  }

  Future<void> recordSensorSample(VehicleParameters params) {
    return _onVehicleParameters(params);
  }

  Future<RideTestSession> endRideSessionAndUpload({
    RideTestLocation? stopLocation,
    String notes = '',
  }) {
    return stopSession(stopLocation: stopLocation, notes: notes, save: true);
  }

  RideTestSample _sampleFromVehicleParameters(
    VehicleParameters params,
    RideTestLocation mobileLocation,
  ) {
    return RideTestSample(
      timestamp: params.timestamp,
      accelX: params.accelerationX,
      accelY: params.accelerationY,
      accelZ: params.accelerationZ,
      speed: params.speed,
      impactForce: params.impactForce,
      orientation: params.orientation,
      latitude: mobileLocation.latitude,
      longitude: mobileLocation.longitude,
      totalAcceleration: params.totalAcceleration,
      source: 'esp32',
      deviceId: params.deviceId,
      gpsAccuracy: mobileLocation.accuracy,
      gpsSpeed: mobileLocation.speed,
      gpsHeading: mobileLocation.heading,
      rawPayload: params.toJson(),
    );
  }

  Future<String?> _uploadSessionExport(RideTestSession session) async {
    final payload = const JsonEncoder.withIndent('  ').convert({
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'session': session.toJson(),
    });
    try {
      return await _supabaseRepository.uploadRideSessionExport(
        sessionId: session.sessionId,
        payload: payload,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeSessionMetadata(
    String status,
    RideTestSession session,
  ) async {
    try {
      await _firestore.collection('ride_sessions').doc(session.sessionId).set({
        'session_id': session.sessionId,
        'session_type': session.sessionType.id,
        'vehicle_mode': session.vehicleMode.id,
        'status': status,
        'start_time': session.startTime.toIso8601String(),
        'stop_time': session.stopTime?.toIso8601String(),
        'start_location': session.startLocation.toJson(),
        'stop_location': session.stopLocation?.toJson(),
        'duration_seconds': session.durationSeconds,
        'total_samples': session.totalSamples,
        'notes': session.notes,
        'supabase_export_path': session.supabaseExportPath,
        'uploaded_to_supabase': session.uploadedToSupabase,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeSample(RideTestSample sample) async {
    final session = _currentSession;
    if (session == null) return;
    try {
      await _firestore
          .collection('ride_sessions')
          .doc(session.sessionId)
          .collection('samples')
          .doc(sample.timestamp.microsecondsSinceEpoch.toString())
          .set({'session_id': session.sessionId, ...sample.toJson()});
    } catch (_) {}
  }

  Future<RideTestLocation> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _latestLocationOrZero();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _latestLocationOrZero();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return RideTestLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
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

  Future<void> _onVehicleParameters(VehicleParameters params) async {
    if (!_isRecording || _currentSession == null) return;
    final mobileLocation = await getCurrentLocation();
    await _addSample(_sampleFromVehicleParameters(params, mobileLocation));
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

    await _addSample(
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
        source: 'fallback',
        gpsAccuracy: location.accuracy,
        gpsSpeed: location.speed,
        gpsHeading: location.heading,
        rawPayload: {
          'source': 'fallback',
          'generated_at': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  Future<void> _addSample(RideTestSample sample) async {
    _sampleBuffer.add(sample);
    _latestSample = sample;
    _emitCurrentSession();
    unawaited(_writeSample(sample));
    _notifyRideProgressIfNeeded(sample);
  }

  void _notifyRideProgressIfNeeded(RideTestSample sample) {
    final session = _currentSession;
    if (session == null) return;

    final now = DateTime.now();
    final lastSent = _lastRideProgressSent;
    if (lastSent != null && now.difference(lastSent).inSeconds < 5) {
      return;
    }

    _lastRideProgressSent = now;
    unawaited(_esp32Service.notifyRideProgress(
      sessionId: session.sessionId,
      totalSamples: _sampleBuffer.length,
      durationSeconds: now.difference(session.startTime).inSeconds,
      speed: sample.speed,
      totalAcceleration: sample.totalAcceleration,
    ));
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
      accuracy: latest.gpsAccuracy,
      speed: latest.gpsSpeed,
      heading: latest.gpsHeading,
    );
  }

  Future<File> _sessionFile(String sessionId) async {
    final root = await getApplicationDocumentsDirectory();
    return File(p.join(root.path, 'ride_tests', 'ride_test_$sessionId.json'));
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

    if (!inserted) {
      next.add(jsonEncode(summary.toJson()));
    }
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
