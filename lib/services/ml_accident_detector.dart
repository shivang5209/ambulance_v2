import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/accident_prediction.dart';
import '../models/location_context.dart';
import '../models/vehicle_parameters.dart';

/// On-device TFLite accident detection model wrapper.
///
/// Architecture:
///   Input  → [1, 38]  (30 sensor floats + 8 location floats)
///   Dense(64, relu) → Dropout(0.2) → Dense(32, relu) → Dense(3, softmax)
///   Output → [normal, near_miss, accident]  probabilities
///
/// Usage:
/// ```dart
/// final detector = MLAccidentDetector();
/// await detector.loadModel();                      // from bundled asset
/// final prediction = detector.predict(window, ctx);
/// ```
class MLAccidentDetector {
  static const String _bundledAssetPath = 'assets/models/accident_detector_v1.tflite';
  static const int _inputSize = 38; // 30 sensor + 8 location
  static const int _outputClasses = 3;

  Interpreter? _interpreter;
  bool _isLoaded = false;
  String? _loadedFromPath; // null = bundled asset, string = OTA path

  bool get isLoaded => _isLoaded;
  String? get modelSource => _loadedFromPath ?? 'bundled_asset';

  // ── Lifecycle ────────────────────────────────────────────────────────

  /// Load the bundled TFLite model from the app asset bundle.
  Future<void> loadModel() async {
    try {
      final byteData = await rootBundle.load(_bundledAssetPath);
      final buffer = byteData.buffer.asUint8List();
      _interpreter = Interpreter.fromBuffer(buffer);
      _isLoaded = true;
      _loadedFromPath = null;
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  /// Hot-swap to an OTA-downloaded model file.
  ///
  /// Called by [ModelUpdateService] after a new version is downloaded.
  /// Falls back to the bundled asset if [path] is invalid.
  Future<void> reloadFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await loadModel(); // fall back to bundled
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      _interpreter?.close();
      _interpreter = Interpreter.fromBuffer(bytes);
      _isLoaded = true;
      _loadedFromPath = path;
    } catch (e) {
      // Failed to load OTA model — fall back to bundled asset
      await loadModel();
    }
  }

  /// Close the interpreter and release resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  // ── Inference ────────────────────────────────────────────────────────

  /// Run inference on a 5-sample sensor window enriched with location context.
  ///
  /// Returns an [AccidentPrediction] with the softmax probabilities.
  /// If the model is not loaded or throws, returns a rule-based fallback.
  AccidentPrediction predict(
    List<VehicleParameters> window,
    LocationContext ctx,
  ) {
    if (!_isLoaded || _interpreter == null) {
      // Fallback: use rule-based exceedsAccidentThreshold
      final isAccident = window.isNotEmpty &&
          window.last.exceedsAccidentThreshold;
      return AccidentPrediction.ruleBased(isAccident: isAccident);
    }

    try {
      final input = _buildFeatureVector(window, ctx);
      final output = List.generate(
        1,
        (_) => List<double>.filled(_outputClasses, 0.0),
      );

      _interpreter!.run(input, output);

      final softmax = output[0];
      final accidentType = _inferAccidentType(window);
      return AccidentPrediction.fromSoftmax(softmax, accidentType: accidentType);
    } catch (e) {
      // TFLite exception → rule-based fallback
      final isAccident = window.isNotEmpty &&
          window.last.exceedsAccidentThreshold;
      return AccidentPrediction.ruleBased(isAccident: isAccident);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  /// Build the 38-float input tensor: [30 sensor floats | 8 location floats].
  List<List<double>> _buildFeatureVector(
    List<VehicleParameters> window,
    LocationContext ctx,
  ) {
    final sensorFeatures = VehicleParameters.flattenWindow(window); // 30 floats
    final locationFeatures = ctx.toFeatureSlice();                 //  8 floats
    final combined = [...sensorFeatures, ...locationFeatures];     // 38 floats

    assert(combined.length == _inputSize,
        'Feature vector length mismatch: ${combined.length} != $_inputSize');

    return [combined]; // shape [1, 38]
  }

  /// Heuristically infer accident type from the sensor pattern in the window.
  ///
  /// This supplements the 3-class softmax output (which only classifies
  /// severity) with a type label for the training data and UI.
  String _inferAccidentType(List<VehicleParameters> window) {
    if (window.isEmpty) return 'unknown';
    final last = window.last;

    // High Z-axis + low XY → rollover
    if (last.accelerationZ.abs() > last.accelerationX.abs() * 2 &&
        last.accelerationZ.abs() > 3.0) {
      return 'rollover';
    }
    // High X-axis → frontal / rear
    if (last.accelerationX.abs() > last.accelerationY.abs()) {
      return last.accelerationX < 0 ? 'frontal' : 'rear';
    }
    // High Y-axis → side impact
    if (last.accelerationY.abs() > 2.0) return 'side';

    return 'unknown';
  }
}
