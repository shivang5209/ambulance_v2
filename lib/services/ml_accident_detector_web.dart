import '../models/accident_prediction.dart';
import '../models/location_context.dart';
import '../models/vehicle_parameters.dart';

class MLAccidentDetector {
  bool get isLoaded => false;
  String? get modelSource => 'web_fallback';

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
