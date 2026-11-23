"""GPU-only retraining for the CropCare leaf disease classifier.

Run with the Python 3.10 environment containing TensorFlow 2.10 and the
TensorFlow DirectML plugin. This script stops if it cannot verify GPU compute.
"""

from __future__ import annotations

import csv
import hashlib
import json
import os
import random
import shutil
import time
from collections import Counter
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)


ROOT = Path(__file__).resolve().parent
PREPROCESSED = ROOT / "preprocessed"
OUTPUT = ROOT / "model_output" / "retrained_balanced_2000_gpu"
BALANCED_TRAIN = PREPROCESSED / "balanced_2000" / "train"
EXTERNAL = ROOT / "external_data" / "imagenette2-160"
CLASS_NAMES_PATH = ROOT / "model_output" / "class_names.json"
SIZE = 224
BACKBONE_SIZE = 160
SEED = 42
NOT_LEAF = "__not_a_supported_leaf__"
NUM_LEAF_CLASSES = 16
NUM_CLASSES = NUM_LEAF_CLASSES + 1
SAMPLES_PER_CLASS_PER_EPOCH = int(os.environ.get("CROP_SAMPLES_PER_CLASS", "2000"))
HEAD_EPOCHS = int(os.environ.get("CROP_HEAD_EPOCHS", "8"))
FINETUNE_EPOCHS = int(os.environ.get("CROP_FINETUNE_EPOCHS", "10"))
HEAD_BATCH = int(os.environ.get("CROP_HEAD_BATCH", "16"))
FINETUNE_BATCH = int(os.environ.get("CROP_FINETUNE_BATCH", "8"))
AUTOTUNE = tf.data.AUTOTUNE

random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)
OUTPUT.mkdir(parents=True, exist_ok=True)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, default=str), encoding="utf-8")


def verify_gpu() -> dict:
    gpus = tf.config.list_physical_devices("GPU")
    if not gpus:
        raise RuntimeError(
            "No TensorFlow GPU device is visible. Training is stopped; CPU fallback is disabled."
        )
    # This matrix operation must be placed by TensorFlow on the GPU device.
    with tf.device("/GPU:0"):
        x = tf.ones((512, 512), dtype=tf.float32)
        y = tf.linalg.matmul(x, x)
        result = float(tf.reduce_sum(y).numpy())
    device = y.device
    if "GPU:0" not in device.upper() or not np.isfinite(result):
        raise RuntimeError(f"GPU placement could not be verified: tensor device was {device!r}.")
    info = {
        "tensorflow": tf.__version__,
        "gpu_name": "NVIDIA GeForce GTX 1650 via DirectML adapter 0",
        "gpu_devices": [device.name for device in gpus],
        "gpu_probe_tensor_device": device,
        "gpu_probe_result": result,
        "training_device": "/GPU:0",
        "cpu_training_fallback": False,
        "python": os.sys.version,
    }
    write_json(OUTPUT / "gpu_runtime.json", info)
    print("Verified GPU matrix operation on", device, flush=True)
    return info


gpu_info = verify_gpu()


def file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def supported_images(folder: Path) -> list[Path]:
    suffixes = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    return sorted(p for p in folder.rglob("*") if p.is_file() and p.suffix.lower() in suffixes)


def map_imagenette_class(directory: str) -> str:
    mapping = {
        "n01440764": "tench fish",
        "n02102040": "springer spaniel",
        "n02979186": "cassette player",
        "n03000684": "chainsaw",
        "n03028079": "church",
        "n03394916": "French horn",
        "n03417042": "garbage truck",
        "n03425413": "gas pump",
        "n03445777": "golf ball",
        "n03888257": "parachute",
    }
    if directory not in mapping:
        raise ValueError(f"Unexpected non-leaf dataset category: {directory}")
    return mapping[directory]


if not (PREPROCESSED / "data_split.csv").is_file():
    raise FileNotFoundError("Run the dataset preprocessing/split cells first; data_split.csv is missing.")
if not BALANCED_TRAIN.is_dir():
    raise FileNotFoundError(f"The materialized 2,000-image training folders are missing: {BALANCED_TRAIN}")
if not (EXTERNAL / "train").is_dir() or not (EXTERNAL / "val").is_dir():
    raise FileNotFoundError("Imagenette 160 data is missing from external_data/imagenette2-160.")

leaf_df = pd.read_csv(PREPROCESSED / "data_split.csv")
class_names = json.loads(CLASS_NAMES_PATH.read_text(encoding="utf-8"))
if len(class_names) != NUM_LEAF_CLASSES:
    raise ValueError(f"Expected 16 disease/healthy labels; found {len(class_names)}.")
if set(leaf_df["label"].unique()) != set(class_names):
    raise ValueError("Preprocessed labels do not match model_output/class_names.json.")
if not set(leaf_df["split"].unique()).issubset({"train", "validation", "test"}):
    raise ValueError("Unexpected data split value.")

label_to_index = {name: i for i, name in enumerate(class_names)}
not_leaf_index = NUM_LEAF_CLASSES
all_class_names = class_names + [NOT_LEAF]

leaf_paths_by_split: dict[str, dict[str, list[str]]] = {}
for split in ("train", "validation", "test"):
    current = leaf_df[leaf_df["split"] == split]
    leaf_paths_by_split[split] = {
        name: current.loc[current["label"] == name, "path"].astype(str).tolist()
        for name in class_names
    }
    missing = [p for group in leaf_paths_by_split[split].values() for p in group if not Path(p).is_file()]
    if missing:
        raise FileNotFoundError(f"{len(missing)} preprocessed image paths are missing; first: {missing[0]}")

# Replace only the leaf training paths with the leakage-safe, materialized
# augmentations. Validation and test continue to use untouched split originals.
leaf_paths_by_split["train"] = {}
for name in class_names:
    class_dir = BALANCED_TRAIN / name
    files = supported_images(class_dir)
    if len(files) != 2000:
        raise ValueError(f"Expected exactly 2,000 images for {name}; found {len(files)} in {class_dir}.")
    leaf_paths_by_split["train"][name] = [str(path.resolve()) for path in files]


# Keep the external source's official validation split as the final OOD test set.
# A deterministic held-out part of its training split calibrates the rejection gate.
negative_train_by_group: dict[str, list[Path]] = {}
negative_calibration_by_group: dict[str, list[Path]] = {}
negative_test_by_group: dict[str, list[Path]] = {}
negative_manifest_rows: list[dict] = []
split_rng = np.random.default_rng(SEED)
train_root, test_root = EXTERNAL / "train", EXTERNAL / "val"
groups = sorted(p.name for p in train_root.iterdir() if p.is_dir())
if len(groups) != 10:
    raise ValueError(f"Expected 10 Imagenette non-leaf categories, found {len(groups)}.")

train_hashes: set[str] = set()
official_test_hashes: set[str] = set()
for group in groups:
    train_files = supported_images(train_root / group)
    official_test_files = supported_images(test_root / group)
    if not train_files or not official_test_files:
        raise ValueError(f"Imagenette category {group} is empty in train or val.")
    permuted = np.array(train_files, dtype=object)
    split_rng.shuffle(permuted)
    calibration_count = max(1, int(round(len(permuted) * 0.15)))
    calibration_files = [Path(p) for p in permuted[:calibration_count]]
    model_train_files = [Path(p) for p in permuted[calibration_count:]]
    negative_train_by_group[group] = model_train_files
    negative_calibration_by_group[group] = calibration_files
    negative_test_by_group[group] = official_test_files
    for split, files, hashes in (
        ("train", model_train_files, train_hashes),
        ("validation", calibration_files, set()),
        ("test", official_test_files, official_test_hashes),
    ):
        for path in files:
            digest = file_digest(path)
            if split == "train":
                hashes.add(digest)
            if split == "test":
                hashes.add(digest)
            negative_manifest_rows.append({
                "path": str(path.resolve()),
                "label": NOT_LEAF,
                "source_category": map_imagenette_class(group),
                "split": split,
                "sha256": digest,
            })
if train_hashes.intersection(official_test_hashes):
    raise ValueError("Exact duplicate Imagenette files cross the training/test boundary.")
pd.DataFrame(negative_manifest_rows).to_csv(OUTPUT / "invalid_image_split.csv", index=False)


# Save the equal-per-class epoch design as a transparent class balance record.
class_train_counts = {name: len(leaf_paths_by_split["train"][name]) for name in class_names}
class_train_counts[NOT_LEAF] = sum(map(len, negative_train_by_group.values()))
balance_rows = [
    {
        "class": name,
        "original_training_images": count,
        "samples_per_balanced_epoch": SAMPLES_PER_CLASS_PER_EPOCH,
        "sampling_multiplier_per_epoch": round(SAMPLES_PER_CLASS_PER_EPOCH / count, 3),
        "leaf_augmentation_materialized": name in class_names,
        "negative_online_augmentation": name == NOT_LEAF,
    }
    for name, count in class_train_counts.items()
]
pd.DataFrame(balance_rows).to_csv(OUTPUT / "balanced_epoch_manifest.csv", index=False)


def make_path_stream(paths: list[str | Path], label: int, augment: bool):
    if not paths:
        raise ValueError(f"Cannot build an empty data stream for label {all_class_names[label]}.")
    path_ds = tf.data.Dataset.from_tensor_slices([str(p) for p in paths])
    path_ds = path_ds.shuffle(
        min(max(len(paths), 1), 2048), seed=SEED + label, reshuffle_each_iteration=True
    ).repeat()

    def load(path):
        encoded = tf.io.read_file(path)
        image = tf.image.decode_image(encoded, channels=3, expand_animations=False)
        image.set_shape([None, None, 3])
        image = tf.image.resize(image, (SIZE, SIZE), method=tf.image.ResizeMethod.BILINEAR)
        if augment:
            image = tf.image.random_flip_left_right(image)
            image = tf.image.random_flip_up_down(image)
            rotations = tf.random.uniform([], minval=0, maxval=4, dtype=tf.int32)
            image = tf.image.rot90(image, rotations)
            image = tf.image.random_brightness(image, max_delta=18.0)
            image = tf.image.random_contrast(image, lower=0.85, upper=1.15)
            image = tf.clip_by_value(image, 0.0, 255.0)
        # Keras ResNet50 Caffe preprocessing: RGB->BGR, then channel means.
        image = tf.reverse(image, axis=[-1])
        image = image - tf.constant([103.939, 116.779, 123.68], dtype=tf.float32)
        return image, tf.constant(label, dtype=tf.int32)

    return path_ds.map(load, num_parallel_calls=AUTOTUNE, deterministic=not augment)


def build_balanced_training_dataset(seed_offset: int = 0):
    """Build an epoch containing exactly the requested number of examples/class."""
    paths: list[str] = []
    labels: list[int] = []
    class_counts: Counter[int] = Counter()
    for label, name in enumerate(class_names):
        class_paths = leaf_paths_by_split["train"][name]
        if len(class_paths) != 2000:
            raise ValueError(f"{name}: expected 2,000 materialized training images, found {len(class_paths)}.")
        paths.extend(class_paths)
        labels.extend([label] * len(class_paths))
        class_counts[label] += len(class_paths)

    # Keep every negative source category available across training stages;
    # draw a stratified 2,000 distinct examples for this stage, then augment
    # them online so the finite pool is not reduced to a fixed subset forever.
    negative_groups = sorted(negative_train_by_group.items())
    if not negative_groups:
        raise ValueError("No non-leaf training groups were found.")
    quotient, remainder = divmod(SAMPLES_PER_CLASS_PER_EPOCH, len(negative_groups))
    rng = np.random.default_rng(SEED + seed_offset)
    for group_index, (_, group_paths) in enumerate(negative_groups):
        take = quotient + (1 if group_index < remainder else 0)
        if len(group_paths) < take:
            raise ValueError(f"Negative source category is too small for stratified sampling: {len(group_paths)} < {take}.")
        chosen = rng.choice(np.asarray(group_paths, dtype=object), size=take, replace=False)
        paths.extend(str(Path(path).resolve()) for path in chosen)
        labels.extend([not_leaf_index] * take)
        class_counts[not_leaf_index] += take

    expected = {index: SAMPLES_PER_CLASS_PER_EPOCH for index in range(NUM_CLASSES)}
    if dict(class_counts) != expected:
        raise RuntimeError(f"Training epoch is not exactly balanced: {dict(class_counts)}")
    number_of_examples = SAMPLES_PER_CLASS_PER_EPOCH * NUM_CLASSES
    ds = tf.data.Dataset.from_tensor_slices((paths, np.asarray(labels, dtype=np.int32)))
    ds = ds.shuffle(
        buffer_size=number_of_examples,
        seed=SEED + seed_offset,
        reshuffle_each_iteration=True,
    )

    def load_training(path, label):
        encoded = tf.io.read_file(path)
        image = tf.image.decode_image(encoded, channels=3, expand_animations=False)
        image.set_shape([None, None, 3])
        image = tf.image.resize(image, (SIZE, SIZE), method=tf.image.ResizeMethod.BILINEAR)

        def augment_negative():
            result = tf.image.random_flip_left_right(image)
            result = tf.image.random_flip_up_down(result)
            result = tf.image.random_brightness(result, max_delta=18.0)
            result = tf.image.random_contrast(result, lower=0.85, upper=1.15)
            return tf.clip_by_value(result, 0.0, 255.0)

        image = tf.cond(tf.equal(label, not_leaf_index), augment_negative, lambda: image)
        # Keras ResNet50 Caffe preprocessing: RGB->BGR, then channel means.
        image = tf.reverse(image, axis=[-1])
        image = image - tf.constant([103.939, 116.779, 123.68], dtype=tf.float32)
        return image, label

    ds = ds.map(load_training, num_parallel_calls=AUTOTUNE, deterministic=False)
    # Explicit repetition is required because fit uses a fixed steps_per_epoch.
    # It prevents Keras from exhausting the finite balanced examples after epoch 1.
    return ds.batch(HEAD_BATCH).repeat().prefetch(2), number_of_examples


def build_finetune_dataset():
    return build_balanced_training_dataset(seed_offset=1)


def finite_dataset(records: list[tuple[str, int]], batch_size: int):
    paths = [record[0] for record in records]
    labels = np.asarray([record[1] for record in records], dtype=np.int32)
    ds = tf.data.Dataset.from_tensor_slices((paths, labels))

    def load(path, label):
        encoded = tf.io.read_file(path)
        image = tf.image.decode_image(encoded, channels=3, expand_animations=False)
        image.set_shape([None, None, 3])
        image = tf.image.resize(image, (SIZE, SIZE), method=tf.image.ResizeMethod.BILINEAR)
        image = tf.reverse(image, axis=[-1])
        image = image - tf.constant([103.939, 116.779, 123.68], dtype=tf.float32)
        return image, label

    return ds.map(load, num_parallel_calls=AUTOTUNE).batch(batch_size).prefetch(1)


def leaf_records(split: str) -> list[tuple[str, int]]:
    return [
        (path, label_to_index[name])
        for name in class_names
        for path in leaf_paths_by_split[split][name]
    ]


def negative_records(index: dict[str, list[Path]]) -> list[tuple[str, int]]:
    return [(str(path), not_leaf_index) for files in index.values() for path in files]


validation_records = leaf_records("validation") + negative_records(negative_calibration_by_group)
test_records = leaf_records("test") + negative_records(negative_test_by_group)
validation_ds = finite_dataset(validation_records, 32)
test_ds = finite_dataset(test_records, 32)
balanced_train_ds, balanced_epoch_examples = build_balanced_training_dataset()


with tf.device("/GPU:0"):
    backbone = tf.keras.applications.ResNet50(
        include_top=False,
        weights="imagenet",
        input_shape=(BACKBONE_SIZE, BACKBONE_SIZE, 3),
    )
    backbone.trainable = False
    inputs = tf.keras.Input(shape=(SIZE, SIZE, 3), dtype=tf.float32, name="resnet_caffe_rgb")
    resized = tf.keras.layers.Resizing(
        BACKBONE_SIZE, BACKBONE_SIZE, interpolation="bilinear", name="backbone_resize"
    )(inputs)
    features = backbone(resized, training=False)
    pooled = tf.keras.layers.GlobalAveragePooling2D(name="global_average_pooling")(features)
    x = tf.keras.layers.Dropout(0.30, name="head_dropout_1")(pooled)
    x = tf.keras.layers.Dense(256, activation="relu", name="classifier_dense")(x)
    x = tf.keras.layers.Dropout(0.25, name="head_dropout_2")(x)
    outputs = tf.keras.layers.Dense(NUM_CLASSES, activation="softmax", name="leaf_or_other")(x)
    model = tf.keras.Model(inputs, outputs, name="resnet50_balanced_leaf_gate")


trainable_devices = sorted({v.device for v in model.trainable_variables if v.device})
if not trainable_devices or not all("GPU:0" in device.upper() for device in trainable_devices):
    raise RuntimeError(f"Model trainable variables are not all on the verified GPU: {trainable_devices}")
write_json(OUTPUT / "training_config.json", {
    "seed": SEED,
    "input_size": [SIZE, SIZE],
    "resnet_internal_size": [BACKBONE_SIZE, BACKBONE_SIZE],
    "classes": all_class_names,
    "materialized_leaf_training_images_per_class": 2000,
    "materialized_leaf_training_total": 2000 * NUM_LEAF_CLASSES,
    "leaf_augmentation_source": "raw images referenced only by the training rows in data_split.csv",
    "validation_test_images_augmented": False,
    "not_leaf_original_training_pool": sum(map(len, negative_train_by_group.values())),
    "training_images_per_class_per_epoch": SAMPLES_PER_CLASS_PER_EPOCH,
    "balanced_examples_per_epoch": balanced_epoch_examples,
    "head_epochs_max": HEAD_EPOCHS,
    "fine_tune_epochs_max": FINETUNE_EPOCHS,
    "head_batch_size": HEAD_BATCH,
    "fine_tune_batch_size": FINETUNE_BATCH,
    "head_learning_rate": 0.001,
    "fine_tune_learning_rate": 0.00001,
    "unfrozen_resnet_block": "conv5_x only; all BatchNormalization layers frozen",
    "trainable_variable_devices": trainable_devices,
    "gpu": gpu_info,
})


def callbacks(stage: str):
    best_weights = OUTPUT / f"{stage}_best.weights.h5"
    return [
        tf.keras.callbacks.ModelCheckpoint(
            str(best_weights), monitor="val_loss", save_best_only=True,
            save_weights_only=True, verbose=1,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=3, restore_best_weights=True, verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=2, min_lr=1e-6, verbose=1
        ),
        tf.keras.callbacks.BackupAndRestore(backup_dir=str(OUTPUT / f"{stage}_recovery")),
        tf.keras.callbacks.CSVLogger(str(OUTPUT / f"{stage}_keras_history.csv")),
    ]


def train_stage(stage: str, learning_rate: float, epochs: int, batch_size: int):
    global balanced_train_ds, balanced_epoch_examples
    if stage == "head":
        balanced_train_ds, balanced_epoch_examples = build_balanced_training_dataset()
    else:
        balanced_train_ds, balanced_epoch_examples = build_finetune_dataset()
    if batch_size != (HEAD_BATCH if stage == "head" else FINETUNE_BATCH):
        balanced_train_ds = balanced_train_ds.unbatch().batch(batch_size).prefetch(1)
    steps = balanced_epoch_examples // batch_size
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    print(
        f"Starting {stage}: GPU=/GPU:0, examples/epoch={balanced_epoch_examples}, "
        f"steps/epoch={steps}, batch={batch_size}, max_epochs={epochs}",
        flush=True,
    )
    started = time.time()
    with tf.device("/GPU:0"):
        history = model.fit(
            balanced_train_ds,
            validation_data=validation_ds,
            epochs=epochs,
            steps_per_epoch=steps,
            callbacks=callbacks(stage),
            verbose=2,
        )
    seconds = time.time() - started
    model.load_weights(OUTPUT / f"{stage}_best.weights.h5")
    model.save_weights(OUTPUT / f"{stage}_selected.weights.h5")
    print(f"Finished {stage} in {seconds / 60:.1f} minutes.", flush=True)
    return history, seconds


reuse_head_dir = Path(os.environ["CROP_REUSE_HEAD_DIR"]) if os.environ.get("CROP_REUSE_HEAD_DIR") else None
head_weights = OUTPUT / "head_selected.weights.h5"
if reuse_head_dir is not None:
    source_weights = reuse_head_dir / "head_selected.weights.h5"
    source_history = reuse_head_dir / "head_keras_history.csv"
    if not source_weights.is_file() or not source_history.is_file():
        raise FileNotFoundError(f"Reusable completed head-stage artifacts are incomplete: {reuse_head_dir}")
    model.load_weights(source_weights)
    shutil.copy2(source_weights, head_weights)
    shutil.copy2(source_history, OUTPUT / "head_keras_history.csv")
    head_frame = pd.read_csv(source_history)
    history_head = tf.keras.callbacks.History()
    history_head.history = {
        key: head_frame[key].astype(float).tolist()
        for key in ("loss", "accuracy", "val_loss", "val_accuracy")
        if key in head_frame
    }
    history_head.epoch = list(range(len(head_frame)))
    head_seconds = 0.0
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    print(f"Reusing verified {len(head_frame)}-epoch frozen-head training from {reuse_head_dir}", flush=True)
else:
    history_head, head_seconds = train_stage("head", 1e-3, HEAD_EPOCHS, HEAD_BATCH)
    head_weights = OUTPUT / "head_selected.weights.h5"
head_validation = model.evaluate(validation_ds, verbose=0, return_dict=True)

# Fine-tune the final residual stage. The stem and conv2_x through conv4_x stay frozen.
backbone.trainable = True
for layer in backbone.layers:
    layer.trainable = layer.name.startswith("conv5_")
    if isinstance(layer, tf.keras.layers.BatchNormalization):
        layer.trainable = False
fine_trainable_names = [layer.name for layer in backbone.layers if layer.trainable]
if not fine_trainable_names or not all(name.startswith("conv5_") for name in fine_trainable_names):
    raise RuntimeError("The intended ResNet50 conv5_x fine-tuning boundary was not applied.")
fine_trainable_devices = sorted({v.device for v in model.trainable_variables if v.device})
if not fine_trainable_devices or not all("GPU:0" in device.upper() for device in fine_trainable_devices):
    raise RuntimeError(f"Fine-tuning variables are not all on the verified GPU: {fine_trainable_devices}")
write_json(OUTPUT / "resnet_freeze_plan.json", {
    "frozen": "ResNet50 stem, conv2_x, conv3_x and conv4_x",
    "unfrozen": "ResNet50 conv5_x and disease head",
    "batch_normalization": "Frozen during both stages",
    "unfrozen_backbone_layer_names": fine_trainable_names,
    "fine_tuning_variable_devices": fine_trainable_devices,
})
history_fine, fine_seconds = train_stage("finetune", 1e-5, FINETUNE_EPOCHS, FINETUNE_BATCH)
fine_weights = OUTPUT / "finetune_selected.weights.h5"
fine_validation = model.evaluate(validation_ds, verbose=0, return_dict=True)

# Select the stage using validation loss only. The combined test set has not been used.
if fine_validation["loss"] < head_validation["loss"]:
    model.load_weights(fine_weights)
    selected_stage = "ResNet50 conv5_x fine-tuned"
    selected_validation = fine_validation
else:
    model.load_weights(head_weights)
    selected_stage = "Frozen ResNet50 feature extractor"
    selected_validation = head_validation
model.save(OUTPUT / "resnet50_leafgate.keras")
print("Selected stage:", selected_stage, "validation:", selected_validation, flush=True)


def predict_records(dataset):
    probabilities = model.predict(dataset, verbose=0)
    return np.asarray(probabilities, dtype=np.float32)


validation_probabilities = predict_records(validation_ds)
validation_y = np.asarray([label for _, label in validation_records], dtype=np.int32)
test_probabilities = predict_records(test_ds)
test_y = np.asarray([label for _, label in test_records], dtype=np.int32)


def choose_gate_thresholds(y_true: np.ndarray, probabilities: np.ndarray):
    leaf_true = y_true != not_leaf_index
    other_probability = probabilities[:, not_leaf_index]
    leaf_confidence = probabilities[:, :NUM_LEAF_CLASSES].max(axis=1)
    top_class_is_leaf = np.argmax(probabilities, axis=1) != not_leaf_index
    candidates = np.linspace(0.0, 1.0, 101)
    rows = []
    best = None
    for other_cutoff in candidates:
        for leaf_cutoff in candidates:
            accept = (
                top_class_is_leaf
                & (other_probability < other_cutoff)
                & (leaf_confidence >= leaf_cutoff)
            )
            leaf_sensitivity = float(np.mean(accept[leaf_true])) if leaf_true.any() else 0.0
            other_specificity = float(np.mean(~accept[~leaf_true])) if (~leaf_true).any() else 0.0
            balanced_accuracy = (leaf_sensitivity + other_specificity) / 2.0
            rows.append({
                "not_leaf_probability_threshold": float(other_cutoff),
                "minimum_leaf_confidence": float(leaf_cutoff),
                "leaf_acceptance_sensitivity": leaf_sensitivity,
                "non_leaf_rejection_specificity": other_specificity,
                "balanced_accuracy": balanced_accuracy,
            })
            # Preserve at least 98% of known crop leaves, then maximize rejection.
            key = (leaf_sensitivity >= 0.98, other_specificity, leaf_sensitivity, balanced_accuracy)
            if best is None or key > best[0]:
                best = (key, float(other_cutoff), float(leaf_cutoff), leaf_sensitivity, other_specificity)
    pd.DataFrame(rows).to_csv(OUTPUT / "gate_threshold_sweep.csv", index=False)
    if best is None:
        raise RuntimeError("Could not calibrate the invalid-image decision threshold.")
    return {
        "not_leaf_probability_threshold": best[1],
        "minimum_leaf_confidence": best[2],
        "validation_leaf_acceptance_sensitivity": best[3],
        "validation_non_leaf_rejection_specificity": best[4],
        "selection_rule": "maximize non-leaf rejection while retaining >=98% validation leaf acceptance",
    }


gate = choose_gate_thresholds(validation_y, validation_probabilities)
write_json(OUTPUT / "invalid_image_gate.json", gate)


def gate_predictions(probabilities: np.ndarray) -> np.ndarray:
    return (
        (np.argmax(probabilities, axis=1) != not_leaf_index)
        &
        (probabilities[:, not_leaf_index] < gate["not_leaf_probability_threshold"])
        & (probabilities[:, :NUM_LEAF_CLASSES].max(axis=1) >= gate["minimum_leaf_confidence"])
    )


top_17 = np.argmax(test_probabilities, axis=1)
gate_accept = gate_predictions(test_probabilities)
gate_binary_truth = (test_y != not_leaf_index).astype(np.int32)  # positive = supported leaf
gate_binary_prediction = gate_accept.astype(np.int32)
gate_cm = confusion_matrix(gate_binary_truth, gate_binary_prediction, labels=[0, 1])
test_leaf_mask = test_y != not_leaf_index
test_negative_mask = ~test_leaf_mask
disease_only_prediction = np.argmax(test_probabilities[:, :NUM_LEAF_CLASSES], axis=1)
end_to_end_correct = np.where(
    test_leaf_mask,
    gate_accept & (disease_only_prediction == test_y),
    ~gate_accept,
)

gate_metrics = {
    "positive_definition": "supported crop leaf accepted by the gate",
    "negative_definition": "non-leaf input correctly rejected by the gate",
    "TP_leaf_accepted": int(gate_cm[1, 1]),
    "FN_leaf_rejected": int(gate_cm[1, 0]),
    "FP_nonleaf_accepted": int(gate_cm[0, 1]),
    "TN_nonleaf_rejected": int(gate_cm[0, 0]),
    "leaf_acceptance_recall": float(recall_score(gate_binary_truth, gate_binary_prediction, zero_division=0)),
    "nonleaf_rejection_specificity": float(gate_cm[0, 0] / max(gate_cm[0].sum(), 1)),
    "gate_precision_for_accepted_leaf": float(precision_score(gate_binary_truth, gate_binary_prediction, zero_division=0)),
    "gate_f1": float(f1_score(gate_binary_truth, gate_binary_prediction, zero_division=0)),
    "gate_balanced_accuracy": float(balanced_accuracy_score(gate_binary_truth, gate_binary_prediction)),
    "gate_confusion_matrix_labels": ["not supported leaf", "supported leaf"],
    "gate_confusion_matrix": gate_cm.tolist(),
}

full_cm = confusion_matrix(test_y, top_17, labels=np.arange(NUM_CLASSES))
test_report = classification_report(
    test_y,
    top_17,
    labels=np.arange(NUM_CLASSES),
    target_names=all_class_names,
    output_dict=True,
    zero_division=0,
)
accepted_leaf_total = int(test_leaf_mask.sum())
negative_total = int(test_negative_mask.sum())
test_metrics = {
    "selected_stage": selected_stage,
    "validation_loss": float(selected_validation["loss"]),
    "validation_accuracy": float(selected_validation["accuracy"]),
    "combined_test_examples": int(len(test_y)),
    "combined_17_way_accuracy": float(accuracy_score(test_y, top_17)),
    "end_to_end_accuracy_after_gate": float(np.mean(end_to_end_correct)),
    "leaf_test_examples": accepted_leaf_total,
    "nonleaf_test_examples": negative_total,
    "forced_16_disease_class_accuracy_on_leaf_test": float(accuracy_score(test_y[test_leaf_mask], disease_only_prediction[test_leaf_mask])),
    "system_leaf_correct_and_accepted_rate": float(np.mean((disease_only_prediction[test_leaf_mask] == test_y[test_leaf_mask]) & gate_accept[test_leaf_mask])),
    "test_macro_precision_17_way": float(test_report["macro avg"]["precision"]),
    "test_macro_recall_17_way": float(test_report["macro avg"]["recall"]),
    "test_macro_f1_17_way": float(test_report["macro avg"]["f1-score"]),
    "invalid_image_gate": gate_metrics,
}
write_json(OUTPUT / "test_metrics.json", test_metrics)
pd.DataFrame(full_cm, index=all_class_names, columns=all_class_names).to_csv(OUTPUT / "confusion_matrix_17_class.csv")
pd.DataFrame(test_report).T.to_csv(OUTPUT / "classification_report_17_class.csv")
pd.DataFrame(gate_cm, index=["actual_not_leaf", "actual_supported_leaf"], columns=["rejected_invalid", "accepted_leaf"]).to_csv(
    OUTPUT / "invalid_gate_confusion_matrix.csv"
)

prediction_rows = []
for (path, true_index), probabilities, predicted_index, accepted in zip(
    test_records, test_probabilities, top_17, gate_accept
):
    prediction_rows.append({
        "path": path,
        "actual_class": all_class_names[true_index],
        "predicted_17_way": all_class_names[int(predicted_index)],
        "gate_result": "leaf accepted" if accepted else "invalid/rejected",
        "not_leaf_probability": float(probabilities[not_leaf_index]),
        "top_leaf_probability": float(probabilities[:NUM_LEAF_CLASSES].max()),
        "top_leaf_class": class_names[int(np.argmax(probabilities[:NUM_LEAF_CLASSES]))],
        "correct_17_way": bool(predicted_index == true_index),
    })
pd.DataFrame(prediction_rows).to_csv(OUTPUT / "test_predictions.csv", index=False)


# Merge the two Keras histories into a single plot-ready epoch table.
metric_rows = []
global_epoch = 0
for stage_name, history in (("Frozen feature extractor", history_head), ("Fine-tuned conv5_x", history_fine)):
    epochs_in_history = len(history.history.get("loss", []))
    for i in range(epochs_in_history):
        global_epoch += 1
        metric_rows.append({
            "global_epoch": global_epoch,
            "stage": stage_name,
            "stage_epoch": i + 1,
            "loss": float(history.history["loss"][i]),
            "accuracy": float(history.history["accuracy"][i]),
            "val_loss": float(history.history["val_loss"][i]),
            "val_accuracy": float(history.history["val_accuracy"][i]),
        })
pd.DataFrame(metric_rows).to_csv(OUTPUT / "training_metrics.csv", index=False)


# Convert the validation-selected 17-class classifier for the Flutter app.
tflite_path = OUTPUT / "crop_disease_leaf_gate.tflite"
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_path.write_bytes(converter.convert())

interpreter = tf.lite.Interpreter(model_path=str(tflite_path), num_threads=2)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()[0]
output_details = interpreter.get_output_details()[0]
if list(input_details["shape"]) != [1, SIZE, SIZE, 3] or input_details["dtype"] != np.float32:
    raise RuntimeError(f"Unexpected TFLite input tensor: {input_details}")
if list(output_details["shape"]) != [1, NUM_CLASSES]:
    raise RuntimeError(f"Unexpected TFLite output tensor: {output_details}")
sample_x, _ = next(iter(test_ds.take(1)))
sample = sample_x[:1].numpy()
interpreter.set_tensor(input_details["index"], sample)
interpreter.invoke()
tflite_scores = interpreter.get_tensor(output_details["index"])[0]
keras_scores = model.predict(sample, verbose=0)[0]
if not np.isfinite(tflite_scores).all() or np.argmax(tflite_scores) != np.argmax(keras_scores):
    raise RuntimeError("TFLite export failed the finite-score/top-class parity check.")
write_json(OUTPUT / "tflite_validation.json", {
    "input_shape": input_details["shape"].tolist(),
    "output_shape": output_details["shape"].tolist(),
    "keras_top_label": all_class_names[int(np.argmax(keras_scores))],
    "tflite_top_label": all_class_names[int(np.argmax(tflite_scores))],
    "max_abs_score_difference": float(np.max(np.abs(keras_scores - tflite_scores))),
    "file_bytes": tflite_path.stat().st_size,
})

metadata = {
    "model_name": "CropCare ResNet50 supported-leaf and disease classifier",
    "format": "TensorFlow Lite",
    "input_shape": [1, SIZE, SIZE, 3],
    "input_dtype": "float32",
    "output_shape": [1, NUM_CLASSES],
    "class_names": all_class_names,
    "not_leaf_label": NOT_LEAF,
    "invalid_image_gate": gate,
    "selected_stage": selected_stage,
    "preprocessing": {
        "orientation": "EXIF correction in Flutter image decoder",
        "color": "RGB",
        "resize": [SIZE, SIZE],
        "interpolation": "bilinear",
        "normalization": "RGB to BGR then subtract [103.939, 116.779, 123.68]; no division by 255",
    },
    "resnet_internal_resize": [BACKBONE_SIZE, BACKBONE_SIZE],
    "training": {
        "balanced_sampling": "2,000 samples for each of 16 supported crop classes and the not-a-supported-leaf class per epoch",
        "materialized_leaf_dataset": "2,000 images per leaf class, generated from raw training-split images only",
        "not_leaf_pool": "Full training pool retained; 2,000 randomly sampled and augmented negatives per epoch",
        "samples_per_class_per_epoch": SAMPLES_PER_CLASS_PER_EPOCH,
        "augmentation": ["offline horizontal/vertical flips", "offline random 0/90/180/270-degree rotations", "offline brightness and contrast factors 0.88 to 1.12", "online augmentation for not-a-supported-leaf examples"],
        "seed": SEED,
        "test_not_used_for_threshold_selection": True,
        "gpu_device": "/GPU:0 DirectML",
    },
    "test_metrics": test_metrics,
    "warning": "Out-of-distribution rejection is learned from a finite negative-image set and cannot guarantee rejection of every possible image.",
}
write_json(OUTPUT / "model_metadata.json", metadata)
write_json(OUTPUT / "class_names.json", all_class_names)

print("Training and held-out evaluation finished.", flush=True)
print(json.dumps(test_metrics, indent=2), flush=True)
print("Artifacts:", OUTPUT, flush=True)
