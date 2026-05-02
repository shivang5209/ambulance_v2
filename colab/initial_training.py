"""
initial_training.py
───────────────────
Trains the first accident detection model from scratch.
Run in Google Colab (free GPU) after generate_training_data.py.

Steps:
  1. Load training_data_initial.csv
  2. Build Dense(64) → Dropout(0.2) → Dense(32) → Dense(3, softmax)
  3. Train 50 epochs
  4. Prune to 50 % sparsity
  5. Quantize to INT8
  6. Export accident_detector_v1.tflite
  7. Upload to Firebase Storage /models/

Requirements (install in Colab):
  !pip install tensorflow tensorflow-model-optimization firebase-admin
"""

# ── 0. Colab GPU check ────────────────────────────────────────────────
import tensorflow as tf
print("TF version:", tf.__version__)
print("GPUs:", tf.config.list_physical_devices("GPU"))

# ── 1. Load dataset ───────────────────────────────────────────────────
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

df = pd.read_csv("training_data_initial.csv")
X = df.drop("label", axis=1).values.astype(np.float32)
y = df["label"].values.astype(np.int32)

# Scale features
scaler = StandardScaler()
X = scaler.fit_transform(X)

import pickle
with open("feature_scaler.pkl", "wb") as f:
    pickle.dump(scaler, f)

X_train, X_val, y_train, y_val = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"Train: {X_train.shape}, Val: {X_val.shape}")
print(f"Input size: {X_train.shape[1]}  (should be 14 features × 1 — single sample mode)")
# Note: the TFLite model accepts a flat [1, 38] vector (5-window × 6 sensor + 8 location).
# For initial training we use single-sample [1, 14] and the orchestrator
# replicates the last sample across the window until real data accumulates.

INPUT_DIM = X_train.shape[1]

# ── 2. Build model ────────────────────────────────────────────────────
from tensorflow import keras
from tensorflow.keras import layers

def build_model(input_dim):
    inp = keras.Input(shape=(input_dim,), name="sensor_features")
    x = layers.Dense(64, activation="relu")(inp)
    x = layers.Dropout(0.2)(x)
    x = layers.Dense(32, activation="relu")(x)
    out = layers.Dense(3, activation="softmax", name="class_probs")(x)
    model = keras.Model(inp, out)
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model

model = build_model(INPUT_DIM)
model.summary()

# ── 3. Train ──────────────────────────────────────────────────────────
history = model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=50,
    batch_size=32,
    callbacks=[
        keras.callbacks.EarlyStopping(patience=8, restore_best_weights=True),
        keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=4),
    ],
    verbose=1,
)

val_acc = max(history.history["val_accuracy"])
print(f"\n✅ Best val accuracy: {val_acc:.4f}")

# ── 4. Prune (50 % sparsity) ──────────────────────────────────────────
import tensorflow_model_optimization as tfmot

prune_low_magnitude = tfmot.sparsity.keras.prune_low_magnitude

pruning_params = {
    "pruning_schedule": tfmot.sparsity.keras.PolynomialDecay(
        initial_sparsity=0.0,
        final_sparsity=0.50,
        begin_step=0,
        end_step=len(X_train) // 32 * 5,  # 5 fine-tune epochs
    )
}

pruned_model = prune_low_magnitude(model, **pruning_params)
pruned_model.compile(
    optimizer=keras.optimizers.Adam(1e-4),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

pruned_model.fit(
    X_train, y_train,
    validation_data=(X_val, y_val),
    epochs=5,
    batch_size=32,
    callbacks=[tfmot.sparsity.keras.UpdatePruningStep()],
    verbose=1,
)

stripped_model = tfmot.sparsity.keras.strip_pruning(pruned_model)
print("✅ Pruning complete")

# ── 5. INT8 quantization ──────────────────────────────────────────────
def representative_dataset():
    for i in range(0, min(500, len(X_val)), 1):
        yield [X_val[i:i+1].astype(np.float32)]

converter = tf.lite.TFLiteConverter.from_keras_model(stripped_model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.representative_dataset = representative_dataset
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_model = converter.convert()

# ── 6. Save .tflite ───────────────────────────────────────────────────
MODEL_FILENAME = "accident_detector_v1.tflite"
with open(MODEL_FILENAME, "wb") as f:
    f.write(tflite_model)

size_kb = len(tflite_model) / 1024
print(f"✅ Saved {MODEL_FILENAME}  ({size_kb:.1f} KB)")

# ── 7. Upload to Firebase Storage ────────────────────────────────────
import firebase_admin
from firebase_admin import credentials, storage, firestore
import datetime

# Mount your service-account key in Colab or use environment secret
# cred = credentials.Certificate("serviceAccountKey.json")
# firebase_admin.initialize_app(cred, {"storageBucket": "YOUR_BUCKET.appspot.com"})

# bucket = storage.bucket()
# blob = bucket.blob(f"models/{MODEL_FILENAME}")
# blob.upload_from_filename(MODEL_FILENAME)
# blob.make_public()  # or use signed URL

# # Register in Firestore /model_versions
# fdb = firestore.client()
# version_id = f"v1_{datetime.datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"
# fdb.collection("model_versions").document(version_id).set({
#     "version_id": version_id,
#     "storage_path": f"models/{MODEL_FILENAME}",
#     "is_active": True,
#     "accuracy": float(val_acc),
#     "created_at": firestore.SERVER_TIMESTAMP,
# })
# print(f"✅ Uploaded and registered as {version_id}")

print("\n⚠️  Uncomment the Firebase upload block above after adding your serviceAccountKey.json")
print("📦  Model file is ready:", MODEL_FILENAME)
