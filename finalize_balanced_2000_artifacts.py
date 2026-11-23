"""Reconcile held-out metrics with the exact Flutter invalid-image gate."""
from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "model_output" / "retrained_balanced_2000_gpu"
METRICS = OUT / "test_metrics.json"
METADATA = OUT / "model_metadata.json"
PREDICTIONS = OUT / "test_predictions.csv"
NOT_LEAF = "__not_a_supported_leaf__"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


metrics = load_json(METRICS)
metadata = load_json(METADATA)
gate = metadata["invalid_image_gate"]
rows = list(csv.DictReader(PREDICTIONS.open(encoding="utf-8-sig", newline="")))

for row in rows:
    row["app_accept"] = (
        row["predicted_17_way"] != NOT_LEAF
        and float(row["not_leaf_probability"])
        < float(gate["not_leaf_probability_threshold"])
        and float(row["top_leaf_probability"])
        >= float(gate["minimum_leaf_confidence"])
    )
    row["gate_result"] = "leaf accepted" if row["app_accept"] else "invalid/rejected"

leaf_rows = [row for row in rows if row["actual_class"] != NOT_LEAF]
other_rows = [row for row in rows if row["actual_class"] == NOT_LEAF]
tp = sum(row["app_accept"] for row in leaf_rows)
fn = len(leaf_rows) - tp
fp = sum(row["app_accept"] for row in other_rows)
tn = len(other_rows) - fp
leaf_correct_accepted = sum(
    row["app_accept"] and row["top_leaf_class"] == row["actual_class"]
    for row in leaf_rows
)
end_to_end_correct = leaf_correct_accepted + tn
argmax_correct = sum(row["actual_class"] == row["predicted_17_way"] for row in rows)

gate_metrics = metrics["invalid_image_gate"]
gate_metrics.update(
    {
        "TP_leaf_accepted": tp,
        "FN_leaf_rejected": fn,
        "FP_nonleaf_accepted": fp,
        "TN_nonleaf_rejected": tn,
        "leaf_acceptance_recall": tp / len(leaf_rows) if leaf_rows else 0.0,
        "nonleaf_rejection_specificity": tn / len(other_rows) if other_rows else 0.0,
        "gate_precision_for_accepted_leaf": tp / (tp + fp) if tp + fp else 0.0,
        "gate_f1": (2 * tp) / (2 * tp + fp + fn) if (2 * tp + fp + fn) else 0.0,
        "gate_balanced_accuracy": (
            (tp / len(leaf_rows) if leaf_rows else 0.0)
            + (tn / len(other_rows) if other_rows else 0.0)
        )
        / 2.0,
        "gate_confusion_matrix": [[tn, fp], [fn, tp]],
    }
)
metrics.update(
    {
        "combined_17_way_accuracy": argmax_correct / len(rows),
        "end_to_end_accuracy_after_gate": end_to_end_correct / len(rows),
        "forced_16_disease_class_accuracy_on_leaf_test": leaf_correct_accepted / len(leaf_rows),
        "system_leaf_correct_and_accepted_rate": leaf_correct_accepted / len(leaf_rows),
        "invalid_image_gate": gate_metrics,
    }
)
metadata["test_metrics"] = metrics

with PREDICTIONS.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=[key for key in rows[0] if key != "app_accept"])
    writer.writeheader()
    for row in rows:
        writer.writerow({key: value for key, value in row.items() if key != "app_accept"})

for path, value in ((METRICS, metrics), (METADATA, metadata)):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

with (OUT / "invalid_gate_confusion_matrix.csv").open("w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["", "rejected_invalid", "accepted_leaf"])
    writer.writerow(["actual_not_leaf", tn, fp])
    writer.writerow(["actual_supported_leaf", fn, tp])

print(
    json.dumps(
        {
            "test_images": len(rows),
            "combined_17_way_argmax_accuracy": metrics["combined_17_way_accuracy"],
            "end_to_end_app_accuracy": metrics["end_to_end_accuracy_after_gate"],
            "leaf_disease_accuracy": metrics["forced_16_disease_class_accuracy_on_leaf_test"],
            "gate_confusion_matrix": [[tn, fp], [fn, tp]],
        },
        indent=2,
    )
)
