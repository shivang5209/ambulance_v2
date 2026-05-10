import '../models/accident_prediction.dart';
import '../models/location_context.dart';
import '../models/vehicle_parameters.dart';

/// Dormant ML adapter for the data-collection-first phase.
///
/// TFLite runtime is intentionally not linked right now. The app can keep
/// collecting model-ready samples while crash checks use rule-based fallback.
class MLAccidentDetector {
  bool get isLoaded => false;
  String? get modelSource => 'dormant_rule_based';

  Future<void> loadModel() async {}

  Future<void> reloadFromPath(String path) async {}

  void dispose() {}

  AccidentPrediction predict(
    List<VehicleParameters> window,
    LocationContext ctx,
  ) {
    final isAccident =
        window.isNotEmpty && window.last.exceedsAccidentThreshold;
    return AccidentPrediction.ruleBased(isAccident: isAccident);
  }
}
