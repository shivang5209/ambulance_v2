"""
retrain_model.py
────────────────
Weekly retraining pipeline. Pulls labeled data from Firestore,
fine-tunes only the last Dense(3) layer, re-prunes, re-quantizes,
and uploads the new .tflite to Firebase Storage.

Architecture never changes — only weights update.
This keeps the file size locked at ~1.2 MB after INT8 quantization.

Run manually or schedule in Google Colab via a cron-triggered notebook.

Requirements:
  !pip install tensorflow tensorflow-model-optimization firebase-admin pandas scikit-learn
"""

import datetime
import pickle
import numpy as np
import pandas as pd
import tensorflow as tf
import tensorflow_model_optimization as tfmot
import firebase_admin
from firebase_admin import credentials, firestore, storage
from sklearn.preprocessing import StandardScaler

# ── 0. Firebase init ──────────────────────────────────────────────────
# cred = credentials.Certificate("serviceAccountKey.json")
# firebase_admin.initialize_app(cred, {"storageBucket": "YOUR_BUCKET.appspot.com"})

fdb = firestore.client()
bucket = storage.bucket()

VERSION_TAG = datetime.datetime.utcnow().strftime("%Y%m%d_%H%M%S")
MODEL_FILENAME = f"accident_detector_{VERSION_TAG}.tflite"

# ── 1. Pull labeled training data from Firestore ──────────────────────
print("📥 Fetching labeled training data from Firestore…")
snap = (
    fdb.collection("training_data")
    .where("ready_for_training", "==", True)
    .get()
)

new_records = []
for doc in snap.docs:
    d = doc.to_dict()
    if d.get("input_features") and d.get("true_label"):
        label_map = {"normal": 0, "near_miss": 1, "accident": 2, "false_positive": 0}
        label = label_map.get(d["true_label"], 0)
        new_records.append({
            "features": d["input_features"],
            "label": label,
        })

print(f"  → {len(new_records)} new labeled records")

# ── 2. Merge with existing CSV ────────────────────────────────────────
try:
    existing_df = pd.read_csv("training_data_combined.csv")
    print(f"  → {len(existing_df)} existing records loaded")
except FileNotFoundError:
    existing_df = pd.read_csv("training_data_initial.csv")
    print("  → Using initial dataset as base")

if new_records:
    new_df = pd.DataFrame([
        {**{f"f{i}": v for i, v in enumerate(r["features"])}, "label": r["label"]}
        for r in new_records
    ])
    combined_df = pd.concat([existing_df, new_df], ignore_index=True)
else:
    combined_df = existing_df

combined_df.to_csv("training_data_combined.csv", index=False)
print(f"  → Combined dataset: {len(combined_df)} records")

X = combined_df.drop("label", axis=1).values.astype(np.float32)
y = combined_df["label"].values.astype(np.int32)

# Scale (load existing scaler or fit new)
try:
    with open("feature_scaler.pkl", "rb") as f:
        scaler = pickle.load(f)
    X = scaler.transform(X)
except FileNotFoundError:
    scaler = StandardScaler()
    X = scaler.fit_transform(X)
    with open("feature_scaler.pkl", "wb") as f:
        pickle.dump(scaler, f)

# ── 3. Load current model from Firebase Storage ───────────────────────
print("📥 Downloading current model from Firebase Storage…")
# Download latest active version
active_snap = (
    fdb.collection("model_versions")
    .where("is_active", "==", True)
    .order_by("created_at", direction=firestore.Query.DESCENDING)
    .limit(1)
    .get()
)

if active_snap:
    current_doc = active_snap[0].to_dict()
    storage_path = current_doc["storage_path"]
    blob = bucket.blob(storage_path)
    blob.download_to_filename("current_model.tflite")
    print(f"  → Downloaded {storage_path}")
else:
    print("  ⚠️  No active model found. Starting from saved Keras model.")

# Load as Keras model for fine-tuning
# NOTE: For true weight-loading from TFLite you'd use a representative
# Keras clone. In production, save the Keras model alongside the .tflite.
from tensorflow import keras

try:
    model = keras.models.load_model("accident_detector_keras/")
    print("  → Keras model loaded")
except Exception:
    # Rebuild architecture and retrain from scratch if Keras weights unavailable
    print("  → Keras model not found — rebuilding architecture")
    from tensorflow.keras import layers
    inp = keras.Input(shape=(X.shape[1],))
    x = layers.Dense(64, activation="relu")(inp)
    x = layers.Dropout(0.2)(x)
    x = layers.Dense(32, activation="relu")(x)
    out = layers.Dense(3, activation="softmax")(x)
    model = keras.Model(inp, out)

# ── 4. Freeze all but last layer ─────────────────────────────────────
for layer in model.layers[:-1]:
    layer.trainable = False
model.layers[-1].trainable = True

model.compile(
    optimizer=keras.optimizers.Adam(1e-4),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

# ── 5. Fine-tune 5 epochs ─────────────────────────────────────────────
print("🔄 Fine-tuning last layer…")
model.fit(
    X, y,
    epochs=5,
    batch_size=32,
    validation_split=0.15,
    verbose=1,
)

# Unfreeze all layers for pruning
for layer in model.layers:
    layer.trainable = True

# Save updated Keras model
model.save("accident_detector_keras/")

# ── 6. Re-prune to 50 % sparsity ─────────────────────────────────────
print("✂️  Re-pruning…")
prune_low_magnitude = tfmot.sparsity.keras.prune_low_magnitude
pruning_params = {
    "pruning_schedule": tfmot.sparsity.keras.PolynomialDecay(
        initial_sparsity=0.0,
        final_sparsity=0.50,
        begin_step=0,
        end_step=len(X) // 32 * 3,
    )
}
pruned = prune_low_magnitude(model, **pruning_params)
pruned.compile(
    optimizer=keras.optimizers.Adam(1e-4),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)
pruned.fit(
    X, y, epochs=3, batch_size=32,
    callbacks=[tfmot.sparsity.keras.UpdatePruningStep()],
    verbose=1,
)
stripped = tfmot.sparsity.keras.strip_pruning(pruned)

# ── 7. Re-quantize to INT8 ────────────────────────────────────────────
print("📦 INT8 quantizing…")
X_rep = X[:500].astype(np.float32)

def representative_dataset():
    for i in range(len(X_rep)):
        yield [X_rep[i:i+1]]

converter = tf.lite.TFLiteConverter.from_keras_model(stripped)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_bytes = converter.convert()

with open(MODEL_FILENAME, "wb") as f:
    f.write(tflite_bytes)

size_kb = len(tflite_bytes) / 1024
print(f"  → {MODEL_FILENAME}  ({size_kb:.1f} KB)")

# ── 8. Upload new model ───────────────────────────────────────────────
print("📤 Uploading to Firebase Storage…")
remote_path = f"models/{MODEL_FILENAME}"
blob = bucket.blob(remote_path)
blob.upload_from_filename(MODEL_FILENAME)

# ── 9. Update /model_versions ─────────────────────────────────────────
# Deactivate previous version
for doc in active_snap:
    doc.reference.update({"is_active": False})

# Create new version entry
fdb.collection("model_versions").document(VERSION_TAG).set({
    "version_id": VERSION_TAG,
    "storage_path": remote_path,
    "is_active": True,
    "size_kb": size_kb,
    "training_samples": len(X),
    "created_at": firestore.SERVER_TIMESTAMP,
})

print(f"✅ New model registered as version {VERSION_TAG}")
print(f"   App will hot-swap on next launch via ModelUpdateService.")
