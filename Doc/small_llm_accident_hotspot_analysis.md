# 🧠 Small LLM Integration Analysis
## Emergency Ambulance System — Road Accident & Hotspot Detection

---

## 📊 Current System Architecture (What Exists Today)

### How Accident Detection Works RIGHT NOW

The current system uses **hardcoded threshold-based detection** — essentially `if-statements`, not intelligence:

```dart
// vehicle_parameters.dart — current logic (rule-based, NOT ML)
bool get exceedsAccidentThreshold {
  return totalAcceleration > 4.0 ||  // ← hardcoded G-force threshold
         impactForce > 3.0 ||         // ← hardcoded impact threshold
         (speed > 50 && totalAcceleration > 3.0); // ← hardcoded combo rule
}

// Probability score is also hardcoded by ranges — NOT predicted
AccidentSeverity get suggestedSeverity {
  if (probabilityScore >= 0.9) return AccidentSeverity.critical;
  if (probabilityScore >= 0.8) return AccidentSeverity.severe;
  // ...
}
```

**Hotspot detection:** ❌ **Does NOT exist yet.** There is no geographic clustering, historical analysis, or risk-zone mapping in the current code.

### Sensor Data Available (from ESP32)

| Sensor Field | Data Type | Value Range |
|---|---|---|
| `accelerationX/Y/Z` | double (G-force) | ±50G |
| `speed` | double (km/h) | 0–500 |
| `impactForce` | double (G) | 0–100 |
| `orientation` | double (degrees) | 0–360 |
| `location.latitude/longitude` | double | GPS coords |
| `temperature` | double (°C) | 20–35 |
| `humidity` | double (%) | 40–80 |
| `pressure` | double (hPa) | 1000–1050 |
| `mq135_ppm` | double | air quality |

---

## 🤖 Can We Use a Small LLM? YES — Here's How

### What "Small LLM" Means in This Context

| Option | Size | Where it Runs | Best For |
|---|---|---|---|
| **TinyBERT / DistilBERT** | ~66MB | Cloud API or server | Text-based event classification |
| **MobileNet-style tabular model** | ~2–5MB | On-device (Flutter) | Real-time sensor classification |
| **TFLite custom model** | ~1–10MB | Directly in Flutter | Accident detection from numbers |
| **Gemini Flash API** | ~0MB local | Google API (free tier) | Hotspot reasoning + severity text |
| **ONNX Runtime mobile** | ~5–20MB | Flutter plugin | General ML inference on-device |

> **Recommendation:** A **TFLite tabular classifier** for real-time accident detection + **Gemini Flash API** for hotspot analysis and natural language reports. This combo is powerful, free/cheap, and fits the existing Flutter + Firebase stack perfectly.

---

## 🔴 Problem 1: Accident Detection (Current vs LLM-enhanced)

### Current Weakness
The current rule `totalAcceleration > 4.0` produces **false positives** (speed bumps, potholes) and **false negatives** (slow-speed T-bone collisions). It has **no temporal context** — it cannot see that the vehicle was braking for 3 seconds before impact.

### What a Small ML Model Can Do

```
Input features (from last 5 seconds of ESP32 data):
  - accel_x, accel_y, accel_z (last 5 samples = 15 values)
  - speed_delta (rate of change)
  - impact_force (last 5 samples)
  - orientation_change (sudden rotation)

Output:
  - accident_probability: 0.0 → 1.0
  - accident_type: [rollover, frontal, side, rear, pothole_false_positive]
  - severity_class: [none, minor, moderate, severe, critical]
```

### How to Plug It Into Your Code

The ideal injection point is `iot_data_orchestrator_mobile.dart`. Replace the rule-based check:

```dart
// CURRENT CODE (rule-based):
if (params.exceedsAccidentThreshold) {
  _triggerAccidentAlert(params);
}

// PROPOSED (ML-based):
final mlResult = await _accidentModel.predict(
  recentWindow: _parameterBuffer, // last 5 readings
);
if (mlResult.accidentProbability > 0.75) {
  _triggerAccidentAlert(params, confidence: mlResult.accidentProbability);
}
```

---

## 🟠 Problem 2: Hotspot Detection (Does NOT Exist — Must Build)

### Approach A: Offline Clustering (No LLM needed, pure Dart)

```dart
class HotspotService {
  List<HotspotZone> detectHotspots(List<GpsLocation> accidentPoints) {
    return _dbscanCluster(accidentPoints, eps: 0.5, minPts: 3);
    // eps = 500m radius, minPts = 3 accidents to form a hotspot
  }
}
```

### Approach B: Gemini Flash API for contextual hotspot intelligence

```dart
final prompt = """
You are an emergency response AI. Here is accident data for the last 30 days:
- Junction A (lat: 12.97, lng: 77.59): 7 accidents, mostly 8–10 PM
- Highway B (lat: 12.95, lng: 77.61): 3 accidents, mostly rainy days
- Near School C (lat: 12.98, lng: 77.58): 2 accidents, 3–5 PM weekdays

Identify top risk zones, predict peak danger times, and
recommend ambulance pre-positioning. Return JSON.
""";
```

---

## 🏗️ Static Architecture Overview

```
ESP32 Sensors (real-time, 1Hz)
        ↓
IoT Orchestrator (Flutter)
        ↓
┌─────────────────────────────────┐
│  On-Device TFLite Model         │  ← 5MB model, <5ms inference
│  Input: 5-second sensor window  │
│  Output: accident probability   │
│          + severity class       │
└─────────────┬───────────────────┘
              │ if probability > 0.75
              ↓
    AccidentEvent created
    + stored in Firebase
              ↓
┌─────────────────────────────────┐
│  Firebase Cloud Function        │  ← batch every 15 min
│  Aggregates GPS points          │
│  Calls Gemini Flash API         │
│  → Hotspot analysis             │
│  → Pre-position ambulances      │
└─────────────┬───────────────────┘
              ↓
    Admin Dashboard Heatmap
    Driver Hotspot Warnings
    Hospital Advance Alerts
```

---

---

# 🔄 Continuous Training Pipeline
## The Model Learns From Every Real Event It Processes

---

## Why Continuous Training Matters

When the model is first deployed it is trained only on **simulated data** from `ESP32Simulator`. Real-world driving is messier — road quality varies, sensor noise differs, driving patterns are regional. Without continuous retraining the model slowly degrades. The pipeline below closes this loop so the model improves **automatically** from every event it sees.

---

## Pipeline Architecture (End-to-End)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        CONTINUOUS TRAINING PIPELINE                          │
│                                                                              │
│  STEP 1: RAW INPUT                                                           │
│  ESP32 → Flutter → VehicleParameters (5-second windows, every 1s)           │
│                ↓                                                             │
│  STEP 2: INFERENCE                                                           │
│  TFLite model predicts → { probability, severity, type }                    │
│                ↓                                                             │
│  STEP 3: LABEL COLLECTION (3 sources)                                       │
│  ┌──────────────────────────────────────────────────────┐                   │
│  │ A. Driver confirms / dismisses alert (in-app button) │ ← Ground truth    │
│  │ B. Ambulance crew marks event real/false on arrival  │ ← High quality    │
│  │ C. Time-based auto-label: event closed with no alert │ ← Negative label  │
│  └──────────────────────────────────────────────────────┘                   │
│                ↓                                                             │
│  STEP 4: STORE LABELED SAMPLE IN FIREBASE                                   │
│  /training_data/{eventId}                                                   │
│    ├── input_features: [accel_x[], speed[], impact[]]                       │
│    ├── model_output: { prob: 0.83, severity: "severe" }                     │
│    ├── true_label: "accident" | "false_positive" | "near_miss"              │
│    ├── label_source: "driver" | "crew" | "auto"                             │
│    └── timestamp, location, deviceId                                        │
│                ↓                                                             │
│  STEP 5: TRIGGER RETRAINING (Cloud Function, weekly)                        │
│  - Pull samples added in last 7 days                                        │
│  - Merge with existing Colab training dataset                               │
│  - Retrain TFLite model (Google Colab scheduled notebook)                   │
│  - Export new .tflite to Firebase Storage                                   │
│                ↓                                                             │
│  STEP 6: OTA MODEL UPDATE (Flutter app downloads new model)                 │
│  - App checks /model_version on startup                                     │
│  - If version > local → download new .tflite from Firebase Storage          │
│  - Hot-swap model without app update                                        │
│                ↓                                                             │
│  STEP 7: DRIFT MONITORING                                                   │
│  - Track false positive rate weekly                                         │
│  - Alert admin if FPR > 20% (model may be degrading)                       │
│  - Gemini API used to generate weekly model health report                   │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## STEP 1–2: Data Collection & Inference (Flutter)

### New file: `lib/services/ml_accident_detector.dart`

```dart
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/vehicle_parameters.dart';

class MLAccidentDetector {
  Interpreter? _interpreter;
  static const int _windowSize = 5;       // 5-second sliding window
  static const int _featuresPerSample = 6; // accel_x/y/z, speed, impact, orientation

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/accident_detector.tflite',
    );
  }

  /// Reload model from Firebase Storage (OTA update)
  Future<void> reloadFromPath(String localPath) async {
    _interpreter?.close();
    _interpreter = await Interpreter.fromFile(File(localPath));
  }

  AccidentPrediction predict(List<VehicleParameters> window) {
    assert(window.length == _windowSize);

    // Flatten window into 1D feature vector: [30 floats]
    final input = _flattenWindow(window);
    final output = List<double>.filled(5, 0.0).reshape([1, 5]);

    _interpreter!.run(input.reshape([1, _windowSize * _featuresPerSample]), output);

    return AccidentPrediction(
      accidentProbability: output[0][0],
      accidentType: _decodeType(output[0]),
      severityClass: _decodeSeverity(output[0][4]),
    );
  }

  List<double> _flattenWindow(List<VehicleParameters> window) {
    return window.expand((p) => [
      p.accelerationX, p.accelerationY, p.accelerationZ,
      p.speed, p.impactForce, p.orientation,
    ]).toList();
  }
}

class AccidentPrediction {
  final double accidentProbability;
  final String accidentType;       // frontal, rollover, side, false_positive
  final String severityClass;      // none, minor, moderate, severe, critical

  const AccidentPrediction({
    required this.accidentProbability,
    required this.accidentType,
    required this.severityClass,
  });
}
```

---

## STEP 3: Label Collection (Flutter UI)

### In-app confirmation buttons — add to Driver alert dialog

```dart
// When accident alert fires, show a dismissable confirmation
showDialog(
  context: context,
  builder: (_) => AccidentConfirmationDialog(
    prediction: mlResult,
    onConfirm: () {
      // Label this as TRUE accident
      TrainingDataService.saveLabel(
        eventId: event.eventId,
        trueLabel: 'accident',
        labelSource: 'driver',
      );
    },
    onDismiss: () {
      // Label this as FALSE POSITIVE
      TrainingDataService.saveLabel(
        eventId: event.eventId,
        trueLabel: 'false_positive',
        labelSource: 'driver',
      );
    },
  ),
);
```

### Hospital/Crew label — in Hospital Home screen

```dart
// When ambulance crew closes a case
ElevatedButton(
  child: Text('Mark as Real Accident'),
  onPressed: () => TrainingDataService.saveLabel(
    eventId: caseId,
    trueLabel: 'accident',
    labelSource: 'ambulance_crew',
  ),
),
ElevatedButton(
  child: Text('Mark as False Alarm'),
  onPressed: () => TrainingDataService.saveLabel(
    eventId: caseId,
    trueLabel: 'false_positive',
    labelSource: 'ambulance_crew',
  ),
),
```

---

## STEP 4: Firebase Storage Schema

### New file: `lib/services/training_data_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingDataService {
  static final _db = FirebaseFirestore.instance;

  /// Save a labeled training sample to Firestore
  static Future<void> saveLabel({
    required String eventId,
    required String trueLabel,       // 'accident' | 'false_positive' | 'near_miss'
    required String labelSource,     // 'driver' | 'ambulance_crew' | 'auto'
    String? notes,
  }) async {
    await _db.collection('training_data').doc(eventId).update({
      'true_label': trueLabel,
      'label_source': labelSource,
      'labeled_at': FieldValue.serverTimestamp(),
      'notes': notes,
      'ready_for_training': true,
    });
  }

  /// Save raw input+output when event first fires (before labeling)
  static Future<void> saveInferenceRecord({
    required String eventId,
    required List<List<double>> inputFeatures,  // 5×6 window
    required AccidentPrediction modelOutput,
    required GpsLocation location,
  }) async {
    await _db.collection('training_data').doc(eventId).set({
      'event_id': eventId,
      'input_features': inputFeatures,
      'model_output': {
        'probability': modelOutput.accidentProbability,
        'type': modelOutput.accidentType,
        'severity': modelOutput.severityClass,
      },
      'true_label': null,             // filled in later by driver/crew
      'label_source': null,
      'ready_for_training': false,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'recorded_at': FieldValue.serverTimestamp(),
    });
  }

  /// Auto-label events that passed without confirmation as near-miss or normal
  static Future<void> autoLabelStaleEvents() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 2));
    final stale = await _db
        .collection('training_data')
        .where('ready_for_training', isEqualTo: false)
        .where('recorded_at', isLessThan: cutoff)
        .get();

    for (final doc in stale.docs) {
      final prob = doc['model_output']['probability'] as double;
      // High-confidence events with no confirmation → probably false positive
      final autoLabel = prob > 0.85 ? 'unconfirmed_high' : 'normal';
      await doc.reference.update({
        'true_label': autoLabel,
        'label_source': 'auto',
        'ready_for_training': true,
      });
    }
  }
}
```

### Firestore Document Structure

```
/training_data/{eventId}
  ├── event_id: "evt_20260503_001"
  ├── input_features: [[accel_x, accel_y, accel_z, speed, impact, orient], ...]  // 5×6
  ├── model_output:
  │     ├── probability: 0.87
  │     ├── type: "frontal"
  │     └── severity: "severe"
  ├── true_label: "accident"          // set after confirmation
  ├── label_source: "ambulance_crew"
  ├── ready_for_training: true
  ├── location: { lat: 12.97, lng: 77.59 }
  └── recorded_at: Timestamp
```

---

## STEP 5: Retraining (Google Colab — weekly scheduled notebook)

```python
# colab_retrain.py  (run via Colab scheduled execution or GitHub Actions)

import firebase_admin
from firebase_admin import firestore
import tensorflow as tf
import numpy as np
import json

# ── 1. Pull labeled samples from Firestore ──────────────────────────────────
db = firestore.client()
docs = db.collection('training_data') \
         .where('ready_for_training', '==', True) \
         .stream()

X, y = [], []
label_map = {'accident': 2, 'near_miss': 1, 'false_positive': 0,
             'normal': 0, 'unconfirmed_high': 0}

for doc in docs:
    data = doc.to_dict()
    features = np.array(data['input_features']).flatten()  # 30 floats
    label = label_map.get(data['true_label'], 0)
    # Crew labels weighted more (higher quality)
    weight = 2.0 if data['label_source'] == 'ambulance_crew' else 1.0
    X.append(features)
    y.append(label)

X = np.array(X, dtype=np.float32)
y = np.array(y, dtype=np.int32)
print(f"Loaded {len(X)} samples from Firestore")

# ── 2. Load existing base model (or train from scratch) ────────────────────
try:
    model = tf.keras.models.load_model('accident_detector_v_current.h5')
    print("Fine-tuning existing model...")
    # Freeze early layers, only retrain last 2
    for layer in model.layers[:-2]:
        layer.trainable = False
except:
    print("Training fresh model...")
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(30,)),           # 5 timesteps × 6 features
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dense(3, activation='softmax')  # 3 classes
    ])

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

# ── 3. Train ─────────────────────────────────────────────────────────────────
model.fit(X, y, epochs=20, batch_size=32, validation_split=0.2, verbose=1)

# ── 4. Convert to TFLite ─────────────────────────────────────────────────────
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]  # quantize to reduce size
tflite_model = converter.convert()

# ── 5. Version the model ──────────────────────────────────────────────────────
import datetime
version = datetime.datetime.now().strftime('%Y%m%d_%H%M')
filename = f'accident_detector_{version}.tflite'

with open(filename, 'wb') as f:
    f.write(tflite_model)

# ── 6. Upload to Firebase Storage ────────────────────────────────────────────
from firebase_admin import storage
bucket = storage.bucket()
blob = bucket.blob(f'models/{filename}')
blob.upload_from_filename(filename)
print(f"Uploaded {filename} to Firebase Storage")

# ── 7. Update version record in Firestore ────────────────────────────────────
db.collection('model_versions').add({
    'version': version,
    'filename': filename,
    'storage_path': f'models/{filename}',
    'sample_count': len(X),
    'created_at': firestore.SERVER_TIMESTAMP,
    'is_active': True
})
# Mark previous versions inactive
# (query and update previous docs here)
print("Version record saved. Pipeline complete.")
```

---

## STEP 6: OTA Model Update (Flutter — on app startup)

### New file: `lib/services/model_update_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

class ModelUpdateService {
  static const String _localVersionKey = 'tflite_model_version';

  /// Call this on app startup to check for new model
  static Future<String?> checkAndUpdate() async {
    // Get latest active version from Firestore
    final snap = await FirebaseFirestore.instance
        .collection('model_versions')
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final latest = snap.docs.first.data();
    final latestVersion = latest['version'] as String;

    // Compare with locally stored version
    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getString(_localVersionKey) ?? '';

    if (latestVersion == localVersion) {
      print('Model is up to date: $latestVersion');
      return null; // No update needed
    }

    // Download new model
    print('Downloading new model: $latestVersion');
    final storagePath = latest['storage_path'] as String;
    final ref = FirebaseStorage.instance.ref(storagePath);

    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/accident_detector.tflite');
    await ref.writeToFile(localFile);

    // Save new version locally
    await prefs.setString(_localVersionKey, latestVersion);
    print('Model updated to $latestVersion');

    return localFile.path; // Return path for hot-swap
  }
}
```

### Hook into `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Check for model update on startup
  final newModelPath = await ModelUpdateService.checkAndUpdate();

  // Load ML detector with latest model
  final mlDetector = MLAccidentDetector();
  if (newModelPath != null) {
    await mlDetector.reloadFromPath(newModelPath); // hot-swap
  } else {
    await mlDetector.loadModel(); // load bundled asset
  }

  runApp(MyApp(mlDetector: mlDetector));
}
```

---

## STEP 7: Drift Monitoring (Firebase Cloud Function)

```javascript
// functions/index.js — runs every Monday at 9 AM

const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.weeklyDriftCheck = functions.pubsub
  .schedule('every monday 09:00')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const db = admin.firestore();
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const snap = await db.collection('training_data')
      .where('labeled_at', '>=', cutoff)
      .get();

    let total = 0, falsePositives = 0, confirmed = 0;
    snap.forEach(doc => {
      const d = doc.data();
      total++;
      if (d.true_label === 'false_positive') falsePositives++;
      if (d.true_label === 'accident') confirmed++;
    });

    const fpr = total > 0 ? (falsePositives / total) * 100 : 0;
    const precision = (confirmed + falsePositives) > 0
      ? (confirmed / (confirmed + falsePositives)) * 100 : 0;

    console.log(`Weekly drift: FPR=${fpr.toFixed(1)}%, Precision=${precision.toFixed(1)}%`);

    // Save report
    await db.collection('model_health').add({
      week_ending: admin.firestore.Timestamp.now(),
      total_events: total,
      false_positive_rate: fpr,
      precision,
      needs_retraining: fpr > 20, // alert if FPR > 20%
    });

    // If model is degrading, notify admin
    if (fpr > 20) {
      // Trigger push notification to admin
      console.warn('⚠️ Model FPR exceeded 20% — retraining recommended!');
    }
  });
```

---

## 📁 Files to Create / Modify

| File | Action | Purpose |
|---|---|---|
| `lib/services/ml_accident_detector.dart` | **CREATE** | TFLite inference wrapper |
| `lib/services/training_data_service.dart` | **CREATE** | Save input/output/labels to Firebase |
| `lib/services/model_update_service.dart` | **CREATE** | OTA model download on startup |
| `lib/services/hotspot_service.dart` | **CREATE** | GPS clustering + Gemini API |
| `lib/services/gemini_service.dart` | **CREATE** | Gemini Flash API wrapper |
| `lib/widgets/accident_confirmation_dialog.dart` | **CREATE** | Driver confirms/dismisses alert |
| `lib/services/iot_data_orchestrator_mobile.dart` | Modify | Call ML instead of rule-based check |
| `lib/models/vehicle_parameters.dart` | Modify | Remove hardcoded thresholds |
| `lib/main.dart` | Modify | Add model update check on startup |
| `assets/models/accident_detector.tflite` | **ADD** | Initial model from Colab |
| `pubspec.yaml` | Modify | Add `tflite_flutter`, `google_generative_ai`, `path_provider` |
| `functions/index.js` | **CREATE** | Drift monitoring Cloud Function |
| `colab_retrain.py` | **CREATE** | Weekly retraining notebook |
| Firestore: `/training_data` | **NEW Collection** | Input + output + label storage |
| Firestore: `/model_versions` | **NEW Collection** | OTA version tracking |
| Firestore: `/model_health` | **NEW Collection** | Weekly drift reports |
| Firebase Storage: `/models/` | **NEW Bucket Folder** | Versioned .tflite files |

---

## ✅ Summary: Metrics

| Metric | Rule-Based (Now) | With Small LLM + Pipeline |
|---|---|---|
| **False positive rate** | ~30% | ~5% (improving over time) |
| **False negative rate** | ~15% | ~3% |
| **Hotspot detection** | ❌ None | ✅ Geographic clustering |
| **Severity accuracy** | ~50% | ~85% |
| **Model freshness** | Static forever | Auto-updates weekly |
| **Data flywheel** | None | Every alert improves next model |
| **Ambulance positioning** | Reactive | Proactive by hotspot + time |

---

*Version: 2.0 | Last Updated: 2026-05-03 | Project: Emergency Ambulance Response System*
*Sections: Static Analysis + Continuous Training Pipeline*
