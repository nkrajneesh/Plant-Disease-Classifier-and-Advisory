"""Create a leakage-safe, materialized 2,000-image training set per leaf class.

Only raw training-split images are used as augmentation sources. Validation and
test images remain the untouched preprocessed originals.
"""

from __future__ import annotations

import csv
import json
import random
from collections import Counter
from pathlib import Path

from PIL import Image, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parent
PREPROCESSED = ROOT / "preprocessed"
SPLIT_PATH = PREPROCESSED / "data_split.csv"
CLASS_NAMES_PATH = ROOT / "model_output" / "class_names.json"
OUTPUT = PREPROCESSED / "balanced_2000" / "train"
TARGET_PER_CLASS = 2000
IMAGE_SIZE = (224, 224)
SEED = 42
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def load_rgb(path: Path) -> Image.Image:
    with Image.open(path) as opened:
        image = ImageOps.exif_transpose(opened).convert("RGB")
        return image.resize(IMAGE_SIZE, Image.Resampling.BILINEAR)


def augment(image: Image.Image, rng: random.Random) -> tuple[Image.Image, str]:
    operations: list[str] = []
    if rng.random() < 0.5:
        image = ImageOps.mirror(image)
        operations.append("horizontal_flip")
    if rng.random() < 0.5:
        image = ImageOps.flip(image)
        operations.append("vertical_flip")
    angle = rng.choice((0, 90, 180, 270))
    if angle:
        image = image.rotate(angle, resample=Image.Resampling.BILINEAR, expand=False)
        operations.append(f"rotate_{angle}")
    brightness = rng.uniform(0.88, 1.12)
    contrast = rng.uniform(0.88, 1.12)
    image = ImageEnhance.Brightness(image).enhance(brightness)
    image = ImageEnhance.Contrast(image).enhance(contrast)
    operations.extend((f"brightness_{brightness:.3f}", f"contrast_{contrast:.3f}"))
    return image, ";".join(operations)


def main() -> None:
    if not SPLIT_PATH.is_file() or not CLASS_NAMES_PATH.is_file():
        raise FileNotFoundError("The preprocessed split manifest or class names are missing.")
    if OUTPUT.exists():
        raise FileExistsError(
            f"Refusing to overwrite the existing augmented dataset: {OUTPUT}. "
            "Review or move that folder before rebuilding."
        )

    classes = json.loads(CLASS_NAMES_PATH.read_text(encoding="utf-8"))
    with SPLIT_PATH.open("r", encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    if not rows or set(row["label"] for row in rows) != set(classes):
        raise ValueError("Split manifest labels do not exactly match the 16 leaf classes.")

    # Exact duplicate groups must never cross the train/validation/test boundary.
    group_splits: dict[str, set[str]] = {}
    for row in rows:
        group_splits.setdefault(row["duplicate_group"], set()).add(row["split"])
    leakage_groups = [group for group, splits in group_splits.items() if len(splits) > 1]
    if leakage_groups:
        raise ValueError(f"Found {len(leakage_groups)} duplicate groups across data splits.")

    training_rows: dict[str, list[dict[str, str]]] = {name: [] for name in classes}
    for row in rows:
        if row["split"] == "train":
            source = Path(row["source_path"])
            if not source.is_file():
                raise FileNotFoundError(f"Raw training image is missing: {source}")
            training_rows[row["label"]].append(row)

    OUTPUT.mkdir(parents=True, exist_ok=False)
    manifest_path = OUTPUT.parent / "augmentation_manifest.csv"
    manifest_rows: list[dict[str, object]] = []
    summary: dict[str, object] = {
        "target_images_per_leaf_class": TARGET_PER_CLASS,
        "leaf_class_count": len(classes),
        "total_leaf_training_images": TARGET_PER_CLASS * len(classes),
        "image_size": list(IMAGE_SIZE),
        "seed": SEED,
        "source": "raw images referenced by the train rows in preprocessed/data_split.csv",
        "validation_and_test_augmented": False,
        "augmentation": [
            "horizontal/vertical flips",
            "random 0/90/180/270-degree rotations",
            "brightness factor 0.88 to 1.12",
            "contrast factor 0.88 to 1.12",
        ],
        "classes": {},
    }

    for class_index, class_name in enumerate(classes):
        source_rows = training_rows[class_name]
        if not source_rows:
            raise ValueError(f"No raw training images found for {class_name}.")
        if len(source_rows) > TARGET_PER_CLASS:
            raise ValueError(
                f"{class_name} has {len(source_rows)} training images, more than the target; "
                "the script will not discard source images silently."
            )

        class_dir = OUTPUT / class_name
        class_dir.mkdir(parents=True)
        rng = random.Random(SEED + class_index * 1009)
        generated = TARGET_PER_CLASS - len(source_rows)
        class_manifest: list[dict[str, object]] = []

        for index, row in enumerate(source_rows):
            image = load_rgb(Path(row["source_path"]))
            destination = class_dir / f"original_{index:05d}.jpg"
            image.save(destination, format="JPEG", quality=95, subsampling=0, optimize=True)
            class_manifest.append({
                "class": class_name,
                "split": "train",
                "kind": "resized_original",
                "source_path": row["source_path"],
                "output_path": str(destination.resolve()),
                "operations": "resize_224x224",
            })

        for index in range(generated):
            source_row = rng.choice(source_rows)
            image = load_rgb(Path(source_row["source_path"]))
            image, operations = augment(image, rng)
            destination = class_dir / f"augmented_{index:05d}.jpg"
            image.save(destination, format="JPEG", quality=95, subsampling=0, optimize=True)
            class_manifest.append({
                "class": class_name,
                "split": "train",
                "kind": "augmented",
                "source_path": source_row["source_path"],
                "output_path": str(destination.resolve()),
                "operations": operations,
            })

        saved_images = [p for p in class_dir.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES]
        if len(saved_images) != TARGET_PER_CLASS:
            raise RuntimeError(f"{class_name}: expected {TARGET_PER_CLASS} files, found {len(saved_images)}.")
        manifest_rows.extend(class_manifest)
        summary["classes"][class_name] = {
            "raw_dataset_images": sum(
                1 for r in rows if r["label"] == class_name and Path(r["source_path"]).is_file()
            ),
            "original_training_images": len(source_rows),
            "generated_augmented_images": generated,
            "training_images_after_augmentation": len(saved_images),
        }
        print(
            f"{class_name}: {len(source_rows)} train originals + {generated} augmented = "
            f"{len(saved_images)}",
            flush=True,
        )

    with manifest_path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=("class", "split", "kind", "source_path", "output_path", "operations"),
        )
        writer.writeheader()
        writer.writerows(manifest_rows)
    (OUTPUT.parent / "augmentation_summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    print(
        f"Verified {sum(1 for _ in OUTPUT.rglob('*.jpg'))} images across "
        f"{len(classes)} leaf classes. Validation/test source images were not modified.",
        flush=True,
    )


if __name__ == "__main__":
    main()
