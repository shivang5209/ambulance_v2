/// Result returned by [MLAccidentDetector.predict].
///
/// Contains the raw softmax outputs from the TFLite model plus
/// convenience helpers for the UI and routing logic.
class AccidentPrediction {
  /// Raw probability that this window contains an accident (class 2).
  /// Range: 0.0 – 1.0.
  final double accidentProbability;

  /// Predicted accident type. One of:
  /// `frontal`, `rollover`, `side`, `rear`, `false_positive`.
  final String accidentType;

  /// Coarse severity bucket derived from [accidentProbability].
  /// One of: `none`, `minor`, `moderate`, `severe`, `critical`.
  final String severityClass;

  /// Raw probability that this window is a near-miss (class 1).
  /// Range: 0.0 – 1.0.
  final double nearMissProbability;

  /// Probability for the normal class (class 0).
  final double normalProbability;

  const AccidentPrediction({
    required this.accidentProbability,
    required this.accidentType,
    required this.severityClass,
    required this.nearMissProbability,
    required this.normalProbability,
  });

  // ── Factory constructors ────────────────────────────────────────────

  /// Build from raw softmax output: [normal, near_miss, accident].
  factory AccidentPrediction.fromSoftmax(
    List<double> softmax, {
    String accidentType = 'unknown',
  }) {
    assert(softmax.length == 3, 'Softmax must have exactly 3 elements');
    final normalP = softmax[0];
    final nearMissP = softmax[1];
    final accidentP = softmax[2];

    return AccidentPrediction(
      normalProbability: normalP,
      nearMissProbability: nearMissP,
      accidentProbability: accidentP,
      accidentType: accidentType,
      severityClass: _severityFromProbability(accidentP),
    );
  }

  /// Fallback: rule-based result used when TFLite is unavailable.
  factory AccidentPrediction.ruleBased({required bool isAccident}) {
    return AccidentPrediction(
      accidentProbability: isAccident ? 0.85 : 0.05,
      nearMissProbability: 0.0,
      normalProbability: isAccident ? 0.05 : 0.95,
      accidentType: isAccident ? 'unknown' : 'false_positive',
      severityClass: isAccident ? 'moderate' : 'none',
    );
  }

  // ── Convenience getters ─────────────────────────────────────────────

  /// True when model output exceeds the 70 % accident threshold.
  bool get isAccident => accidentProbability >= 0.70;

  /// True when near-miss probability is dominant and above 50 %.
  bool get isNearMiss =>
      nearMissProbability >= 0.50 && nearMissProbability > accidentProbability;

  /// Dominant class index: 0=normal, 1=near_miss, 2=accident.
  int get predictedClass {
    if (accidentProbability >= nearMissProbability &&
        accidentProbability >= normalProbability) {
      return 2;
    }
    if (nearMissProbability >= normalProbability) return 1;
    return 0;
  }

  /// Human-readable confidence string, e.g. "87.3 %".
  String get confidenceDisplay =>
      '${(accidentProbability * 100).toStringAsFixed(1)} %';

  // ── Serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'accidentProbability': accidentProbability,
        'accidentType': accidentType,
        'severityClass': severityClass,
        'nearMissProbability': nearMissProbability,
        'normalProbability': normalProbability,
      };

  factory AccidentPrediction.fromJson(Map<String, dynamic> json) =>
      AccidentPrediction(
        accidentProbability: (json['accidentProbability'] as num).toDouble(),
        accidentType: json['accidentType'] as String,
        severityClass: json['severityClass'] as String,
        nearMissProbability: (json['nearMissProbability'] as num).toDouble(),
        normalProbability: (json['normalProbability'] as num).toDouble(),
      );

  // ── Private helpers ─────────────────────────────────────────────────

  static String _severityFromProbability(double p) {
    if (p < 0.50) return 'none';
    if (p < 0.65) return 'minor';
    if (p < 0.80) return 'moderate';
    if (p < 0.92) return 'severe';
    return 'critical';
  }

  @override
  String toString() =>
      'AccidentPrediction(class=$predictedClass, accident=$confidenceDisplay, '
      'type=$accidentType, severity=$severityClass)';
}
