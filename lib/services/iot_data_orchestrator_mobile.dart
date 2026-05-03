import 'dart:async';
import 'dart:collection';
import 'package:uuid/uuid.dart';

import '../core/constants/supabase_config.dart';
import '../models/accident_prediction.dart';
import '../models/location_context.dart';
import '../models/vehicle_parameters.dart';
import 'esp32_service.dart';
import 'firebase_rtd_repository.dart';
import 'hotspot_service.dart';
import 'location_enrichment_service.dart';
import 'ml_accident_detector.dart';
import 'supabase_repository.dart';
import 'training_data_service.dart';

/// Diagnostic status emitted by the orchestrator.
class OrchestratorStatus {
  final int hotPathWriteCount;
  final int coldPathPendingCount;
  final int coldPathFlushCount;
  final int crashEventCount;
  final String? lastError;
  final DateTime updatedAt;
  final bool mlActive; // true = TFLite running, false = fallback

  const OrchestratorStatus({
    required this.hotPathWriteCount,
    required this.coldPathPendingCount,
    required this.coldPathFlushCount,
    required this.crashEventCount,
    this.lastError,
    required this.updatedAt,
    required this.mlActive,
  });
}

/// Singleton service that subscribes to [ESP32Service.dataStream] and routes
/// every tick to both:
///
///  * **Hot path** → [FirebaseRTDRepository] (fire-and-forget per tick)
///  * **Cold path** → [SupabaseRepository] (batched: 50 records OR 30 s)
///
/// v2 additions:
///  * 5-sample ring buffer for sliding-window ML inference
///  * [MLAccidentDetector] replaces rule-based threshold check
///  * [LocationEnrichmentService] enriches GPS before inference
///  * [TrainingDataService] persists labeled records for retraining
///  * Rule-based fallback when TFLite is unavailable
class IoTDataOrchestrator {
  IoTDataOrchestrator({
    required ESP32Service esp32Service,
    FirebaseRTDRepository? firebaseRepo,
    SupabaseRepository? supabaseRepo,
    MLAccidentDetector? mlDetector,
    TrainingDataService? trainingService,
    LocationEnrichmentService? enrichmentService,
    HotspotService? hotspotService,
  })  : _esp32Service = esp32Service,
        _firebaseRepo = firebaseRepo ?? FirebaseRTDRepository(),
        _supabaseRepo = supabaseRepo ?? SupabaseRepository(),
        _mlDetector = mlDetector ?? MLAccidentDetector(),
        _trainingService = trainingService ?? TrainingDataService(),
        _enrichmentService =
            enrichmentService ?? LocationEnrichmentService(),
        _hotspotService = hotspotService ?? HotspotService();

  final ESP32Service _esp32Service;
  final FirebaseRTDRepository _firebaseRepo;
  final SupabaseRepository _supabaseRepo;
  final MLAccidentDetector _mlDetector;
  final TrainingDataService _trainingService;
  final LocationEnrichmentService _enrichmentService;
  final HotspotService _hotspotService;
  final Uuid _uuid = const Uuid();

  StreamSubscription<VehicleParameters>? _dataSub;
  Timer? _flushTimer;

  // ── v2: 5-sample sliding window ring buffer ──────────────────────────
  final Queue<VehicleParameters> _ringBuffer = Queue<VehicleParameters>();
  static const int _ringBufferSize = 5;

  // ── Diagnostics ──────────────────────────────────────────────────────
  int _hotWrites = 0;
  int _coldFlushes = 0;
  int _crashEvents = 0;
  bool _mlActive = false;
  String? _lastError;

  final StreamController<OrchestratorStatus> _statusController =
      StreamController<OrchestratorStatus>.broadcast();

  /// Stream of diagnostic snapshots for a monitoring UI.
  Stream<OrchestratorStatus> get statusStream => _statusController.stream;
  HotspotService get hotspotService => _hotspotService;
  LocationEnrichmentService get enrichmentService => _enrichmentService;

  // Keep a small rolling window for crash-event context.
  final List<VehicleParameters> _recentHistory = [];
  static const int _historyWindow = 10;

  // ── Lifecycle ────────────────────────────────────────────────────────

  /// Wire up listeners. Call once at app startup.
  void initialize() {
    _dataSub = _esp32Service.dataStream.listen(
      _onData,
      onError: (Object e) {
        _lastError = 'dataStream error: $e';
        _emitStatus();
      },
    );
  }

  /// Start the cold-path periodic flush timer.
  void start() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      SupabaseConfig.batchTimeThreshold,
      (_) => _flushColdPath(),
    );
  }

  /// Tear down subscriptions and timers.
  void dispose() {
    _dataSub?.cancel();
    _flushTimer?.cancel();
    _statusController.close();
  }

  // ── Core routing logic ───────────────────────────────────────────────

  void _onData(VehicleParameters params) {
    // Maintain rolling history for crash context.
    _recentHistory.add(params);
    if (_recentHistory.length > _historyWindow) {
      _recentHistory.removeAt(0);
    }

    // ── v2: Update 5-sample ring buffer ─────────────────────────────
    _ringBuffer.addLast(params);
    if (_ringBuffer.length > _ringBufferSize) _ringBuffer.removeFirst();

    // ── v2: ML inference (async, fire-and-forget) ────────────────────
    _runInference(params);

    // HOT PATH — fire-and-forget (always writes; crash flag set by ML)
    _firebaseRepo
        .writeRealtime(params, crashDetected: false)
        .catchError((Object e) {
      _lastError = 'Firebase write error: $e';
      _emitStatus();
    });

    // COLD PATH — enqueue (no I/O)
    _supabaseRepo.enqueue(params);

    _hotWrites++;
    _emitStatus();

    // Flush cold path early if batch threshold reached.
    if (_supabaseRepo.pendingCount >= SupabaseConfig.batchSizeThreshold) {
      _flushColdPath();
    }
  }

  Future<void> _runInference(VehicleParameters latest) async {
    final window = _ringBuffer.toList();

    // Build location context (best-effort)
    LocationContext ctx;
    try {
      ctx = await _enrichmentService.enrich(latest.location);
    } catch (_) {
      ctx = LocationContext.unknown();
    }

    // ML inference with rule-based fallback
    AccidentPrediction prediction;
    try {
      prediction = _mlDetector.predict(window, ctx);
      _mlActive = _mlDetector.isLoaded;
    } catch (e) {
      // TFLite exception — fall back to rule-based check
      prediction = AccidentPrediction.ruleBased(
        isAccident: latest.exceedsAccidentThreshold,
      );
      _mlActive = false;
      _lastError = 'TFLite error, using fallback: $e';
    }

    if (prediction.isAccident || prediction.isNearMiss) {
      await _handleCrashEvent(latest, window, ctx, prediction);
    }
  }

  Future<void> _handleCrashEvent(
    VehicleParameters params,
    List<VehicleParameters> window,
    LocationContext ctx,
    AccidentPrediction prediction,
  ) async {
    final eventId = _uuid.v4();
    _crashEvents++;

    // Firebase crash event (hot)
    _firebaseRepo.writeCrashEvent(params, eventId).catchError((Object e) {
      _lastError = 'Firebase crash event error: $e';
      _emitStatus();
    });

    // ── v2: Save training record ─────────────────────────────────────
    final featureVector = [
      ...VehicleParameters.flattenWindow(window),
      ...ctx.toFeatureSlice(),
    ];
    _trainingService.saveInferenceRecord(
      eventId: eventId,
      inputFeatures: featureVector,
      modelOutput: prediction,
      location: params.location,
    );

    // Supabase crash event (cold)
    try {
      await _supabaseRepo.writeCrashEvent(
        eventId: eventId,
        params: params,
        recentHistory: List.unmodifiable(_recentHistory),
      );
    } catch (e) {
      _lastError = 'Supabase crash event error: $e';
      _emitStatus();
    }
  }

  Future<void> _flushColdPath() async {
    try {
      final flushed = await _supabaseRepo.flush();
      if (flushed > 0) _coldFlushes++;
    } catch (e) {
      _lastError = 'Cold flush error: $e';
    }
    _emitStatus();
  }

  void _emitStatus() {
    if (_statusController.isClosed) return;
    _statusController.add(OrchestratorStatus(
      hotPathWriteCount: _hotWrites,
      coldPathPendingCount: _supabaseRepo.pendingCount,
      coldPathFlushCount: _coldFlushes,
      crashEventCount: _crashEvents,
      lastError: _lastError,
      updatedAt: DateTime.now(),
      mlActive: _mlActive,
    ));
  }
}
