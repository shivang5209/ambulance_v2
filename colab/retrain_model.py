"""
retrain_model.py

Weekly retraining pipeline. Pulls labeled data from Firestore, fine-tunes the
current model, re-prunes, re-quantizes, and uploads the new TFLite file.

This script expects the same 38-float feature vector shape used by the app:
  30 sensor floats + 8 location floats
"""

import datetime

import numpy as np
import pandas as pd
import tensorflow as tf
import tensorflow_model_optimization as tfmot
import firebase_admin
from firebase_admin import credentials, firestore, storage
from tensorflow import keras

# cred = credentials.Certificate("serviceAccountKey.json")
# firebase_admin.initialize_app(cred, {"storageBucket": "YOUR_BUCKET.appspot.com"})

fdb = firestore.client()
bucket = storage.bucket()

VERSION_TAG = datetime.datetime.utcnow().strftime("%Y%m%d_%H%M%S")
MODEL_FILENAME = f"accident_detector_{VERSION_TAG}.tflite"
KERAS_FILENAME = "accident_detector_keras.keras"

print("Fetching labeled training data from Firestore...")
snap = fdb.collection("training_data").where("ready_for_training", "==", True).get()

label_map = {
    "normal": 0,
    "near_miss": 1,
    "accident": 2,
    "false_positive": 0,
}

new_records = []
for doc in snap.docs:
    data = doc.to_dict()
    features = data.get("input_features")
    true_label = data.get("true_label")
    if not features or true_label not in label_map:
        continue

    row = {f"f{i}": value for i, value in enumerate(features)}
    row["label"] = label_map[true_label]
    new_records.append(row)

print(f"  -> {len(new_records)} new labeled records")

try:
    existing_df = pd.read_csv("training_data_combined.csv")
    print(f"  -> {len(existing_df)} existing records loaded")
except FileNotFoundError:
    existing_df = pd.read_csv("training_data_initial.csv")
    print("  -> Using initial dataset as base")

if new_records:
    new_df = pd.DataFrame(new_records)
    combined_df = pd.concat([existing_df, new_df], ignore_index=True)
else:
    combined_df = existing_df

combined_df.to_csv("training_data_combined.csv", index=False)
print(f"  -> Combined dataset: {len(combined_df)} records")

feature_columns = [col for col in combined_df.columns if col.startswith("f")]
feature_columns = sorted(feature_columns, key=lambda name: int(name[1:]))

X = combined_df[feature_columns].values.astype(np.float32)
y = combined_df["label"].values.astype(np.int32)

if X.shape[1] != 38:
    raise ValueError(f"Expected 38 feature columns, found {X.shape[1]}")

print("Downloading current model metadata from Firebase Storage...")
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
    print(f"  -> Downloaded {storage_path}")
else:
    print("  -> No active model record found. Falling back to local Keras checkpoint.")

try:
    model = keras.models.load_model(KERAS_FILENAME)
    print("  -> Keras checkpoint loaded")
except Exception:
    print("  -> Keras checkpoint not found, rebuilding architecture")
    inp = keras.Input(shape=(38,), name="sensor_window_with_context")
    x = keras.layers.Dense(64, activation="relu")(inp)
    x = keras.layers.Dropout(0.2)(x)
    x = keras.layers.Dense(32, activation="relu")(x)
    out = keras.layers.Dense(3, activation="softmax", name="class_probs")(x)
    model = keras.Model(inp, out)

for layer in model.layers[:-1]:
    layer.trainable = False
model.layers[-1].trainable = True

model.compile(
    optimizer=keras.optimizers.Adam(1e-4),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

print("Fine-tuning last layer...")
model.fit(
    X,
    y,
    epochs=5,
    batch_size=32,
    validation_split=0.15,
    verbose=1,
)

for layer in model.layers:
    layer.trainable = True

model.save(KERAS_FILENAME)

print("Re-pruning...")
prune_low_magnitude = tfmot.sparsity.keras.prune_low_magnitude
pruning_params = {
    "pruning_schedule": tfmot.sparsity.keras.PolynomialDecay(
        initial_sparsity=0.0,
        final_sparsity=0.50,
        begin_step=0,
        end_step=max(1, (len(X) // 32) * 3),
    )
}

pruned_model = prune_low_magnitude(model, **pruning_params)
pruned_model.compile(
    optimizer=keras.optimizers.Adam(1e-4),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)
pruned_model.fit(
    X,
    y,
    epochs=3,
    batch_size=32,
    callbacks=[tfmot.sparsity.keras.UpdatePruningStep()],
    verbose=1,
)

stripped_model = tfmot.sparsity.keras.strip_pruning(pruned_model)

print("INT8 quantizing...")
X_rep = X[: min(500, len(X))].astype(np.float32)


def representative_dataset():
    for i in range(len(X_rep)):
        yield [X_rep[i : i + 1]]


converter = tf.lite.TFLiteConverter.from_keras_model(stripped_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_bytes = converter.convert()

with open(MODEL_FILENAME, "wb") as f:
    f.write(tflite_bytes)

size_kb = len(tflite_bytes) / 1024
print(f"  -> {MODEL_FILENAME} ({size_kb:.1f} KB)")

print("Uploading to Firebase Storage...")
remote_path = f"models/{MODEL_FILENAME}"
blob = bucket.blob(remote_path)
blob.upload_from_filename(MODEL_FILENAME)

for doc in active_snap:
    doc.reference.update({"is_active": False})

fdb.collection("model_versions").document(VERSION_TAG).set({
    "version_id": VERSION_TAG,
    "storage_path": remote_path,
    "is_active": True,
    "size_kb": size_kb,
    "training_samples": len(X),
    "created_at": firestore.SERVER_TIMESTAMP,
})

print(f"New model registered as version {VERSION_TAG}")
print("App will hot-swap on next launch via ModelUpdateService.")
