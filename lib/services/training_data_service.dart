import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/accident_prediction.dart';
import '../models/vehicle_parameters.dart';

/// Saves raw inference records and driver labels to Firestore `/training_data`.
///
/// These documents are consumed weekly by the Colab retraining pipeline.
///
/// Document schema:
/// ```
/// {
///   event_id:          String
///   input_features:    List<double>  (38 floats flat)
///   model_output: {
///     probability:     double
///     type:            String
///     severity:        String
///   }
///   true_label:        String?  (accident|false_positive|near_miss|normal|null)
///   label_source:      String?  (driver|ambulance_crew|auto|null)
///   ready_for_training: bool
///   location: { lat: double, lng: double }
///   recorded_at:       Timestamp
///   labeled_at:        Timestamp?
/// }
/// ```
class TrainingDataService {
  static const _collection = 'training_data';
  final FirebaseFirestore _db;

  TrainingDataService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Write raw inference record ───────────────────────────────────────

  /// Called immediately after ML inference when an accident is detected.
  Future<void> saveInferenceRecord({
    required String eventId,
    required List<double> inputFeatures,
    required AccidentPrediction modelOutput,
    required GpsLocation location,
  }) async {
    try {
      await _db.collection(_collection).doc(eventId).set({
        'event_id': eventId,
        'input_features': inputFeatures,
        'model_output': {
          'probability': modelOutput.accidentProbability,
          'type': modelOutput.accidentType,
          'severity': modelOutput.severityClass,
        },
        'true_label': null,
        'label_source': null,
        'ready_for_training': false,
        'location': {
          'lat': location.latitude,
          'lng': location.longitude,
        },
        'recorded_at': FieldValue.serverTimestamp(),
        'labeled_at': null,
      });
    } catch (e) {
      // Non-fatal — training pipeline loss is acceptable
    }
  }

  // ── Save driver / crew label ─────────────────────────────────────────

  /// Call when a driver confirms or dismisses an alert.
  ///
  /// [trueLabel]: one of `accident`, `false_positive`, `near_miss`, `normal`.
  /// [labelSource]: one of `driver`, `ambulance_crew`, `auto`.
  Future<void> saveLabel({
    required String eventId,
    required String trueLabel,
    required String labelSource,
  }) async {
    try {
      await _db.collection(_collection).doc(eventId).update({
        'true_label': trueLabel,
        'label_source': labelSource,
        'ready_for_training': true,
        'labeled_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-fatal
    }
  }

  // ── Auto-label stale events ──────────────────────────────────────────

  /// Auto-labels unlabeled events older than 2 hours.
  ///
  /// If the driver did not dismiss the alert within 2 hours it is very likely
  /// a real accident (or at minimum a near-miss).
  /// Label source is `auto`.
  Future<void> autoLabelStaleEvents() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 2));
    try {
      final snap = await _db
          .collection(_collection)
          .where('true_label', isNull: true)
          .where('recorded_at', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'true_label': 'accident',
          'label_source': 'auto',
          'ready_for_training': true,
          'labeled_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      // Non-fatal
    }
  }
}
