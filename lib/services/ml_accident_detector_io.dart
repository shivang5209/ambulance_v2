import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/accident_prediction.dart';
import '../models/location_context.dart';
import '../models/vehicle_parameters.dart';

class MLAccidentDetector {
  static const String _bundledAssetPath =
      'assets/models/accident_detector_v1.tflite';
  static const int _inputSize = 38;
  static const int _outputClasses = 3;

  Interpreter? _interpreter;
  bool _isLoaded = false;
  String? _loadedFromPath;

  bool get isLoaded => _isLoaded;
  String? get modelSource => _loadedFromPath ?? 'bundled_asset';

  Future<void> loadModel() async {
    try {
      final byteData = await rootBundle.load(_bundledAssetPath);
      final buffer = byteData.buffer.asUint8List();
      _interpreter?.close();
      _interpreter = Interpreter.fromBuffer(buffer);
      _isLoaded = true;
      _loadedFromPath = null;
    } catch (e) {
      _isLoaded = false;
      rethrow;
    }
  }

  Future<void> reloadFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      await loadModel();
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      _interpreter?.close();
      _interpreter = Interpreter.fromBuffer(bytes);
      _isLoaded = true;
      _loadedFromPath = path;
    } catch (_) {
      await loadModel();
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }

  AccidentPrediction predict(
    List<VehicleParameters> window,
    LocationContext ctx,
  ) {
    if (!_isLoaded || _interpreter == null) {
      final isAccident =
          window.isNotEmpty && window.last.exceedsAccidentThreshold;
      return AccidentPrediction.ruleBased(isAccident: isAccident);
    }

    try {
      final features = _buildFeatureVector(window, ctx);
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);

      late final List<double> softmax;
      if (inputTensor.type == TensorType.int8 &&
          outputTensor.type == TensorType.int8) {
        final quantizedInput = [
          _quantizeVector(
            features,
            scale: inputTensor.params.scale,
            zeroPoint: inputTensor.params.zeroPoint,
          ),
        ];
        final quantizedOutput = List.generate(
          1,
          (_) => List<int>.filled(_outputClasses, 0),
        );
        _interpreter!.run(quantizedInput, quantizedOutput);
        softmax = _dequantizeVector(
          quantizedOutput.first,
          scale: outputTensor.params.scale,
          zeroPoint: outputTensor.params.zeroPoint,
        );
      } else {
        final floatInput = [features];
        final floatOutput = List.generate(
          1,
          (_) => List<double>.filled(_outputClasses, 0.0),
        );
        _interpreter!.run(floatInput, floatOutput);
        softmax = floatOutput.first;
      }

      final accidentType = _inferAccidentType(window);
      return AccidentPrediction.fromSoftmax(
        softmax,
        accidentType: accidentType,
      );
    } catch (_) {
      final isAccident =
          window.isNotEmpty && window.last.exceedsAccidentThreshold;
      return AccidentPrediction.ruleBased(isAccident: isAccident);
    }
  }

  List<double> _buildFeatureVector(
    List<VehicleParameters> window,
    LocationContext ctx,
  ) {
    final sensorFeatures = VehicleParameters.flattenWindow(window);
    final locationFeatures = ctx.toFeatureSlice();
    final combined = [...sensorFeatures, ...locationFeatures];

    assert(
      combined.length == _inputSize,
      'Feature vector length mismatch: ${combined.length} != $_inputSize',
    );

    return combined;
  }

  List<int> _quantizeVector(
    List<double> values, {
    required double scale,
    required int zeroPoint,
  }) {
    if (scale == 0) {
      return values.map((_) => 0).toList(growable: false);
    }

    return values
        .map((value) {
          final quantized = (value / scale + zeroPoint).round();
          return quantized.clamp(-128, 127);
        })
        .toList(growable: false);
  }

  List<double> _dequantizeVector(
    List<int> values, {
    required double scale,
    required int zeroPoint,
  }) {
    if (scale == 0) {
      return values.map((_) => 0.0).toList(growable: false);
    }

    return values
        .map((value) => (value - zeroPoint) * scale)
        .toList(growable: false);
  }

  String _inferAccidentType(List<VehicleParameters> window) {
    if (window.isEmpty) return 'unknown';
    final last = window.last;

    if (last.accelerationZ.abs() > last.accelerationX.abs() * 2 &&
        last.accelerationZ.abs() > 3.0) {
      return 'rollover';
    }
    if (last.accelerationX.abs() > last.accelerationY.abs()) {
      return last.accelerationX < 0 ? 'frontal' : 'rear';
    }
    if (last.accelerationY.abs() > 2.0) return 'side';

    return 'unknown';
  }
}
