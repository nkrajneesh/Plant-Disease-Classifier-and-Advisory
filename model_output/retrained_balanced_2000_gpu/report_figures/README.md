# Report figures

- `training_accuracy.png` — training and validation accuracy by epoch, with the conv5_x unfreeze boundary.
- `training_loss.png` — training and validation cross-entropy by epoch.
- `class_balance.png` — original and augmented training counts per leaf class.
- `split_distribution.png` — train, validation, and test proportions for leaves and unrelated images.
- `leaf_f1_by_class.png` — held-out F1 score for each supported leaf class.
- `confusion_matrix_17.png` — normalized confusion matrix with raw counts for all 17 outputs.
- `invalid_gate_confusion.png` — binary invalid-image gate counts (TN, FP, FN, TP).
- `published_accuracy_comparison.png` — contextual accuracy comparison with four papers.
- `residual_block.png` — simplified residual connection diagram.
- `app_pipeline.png` — camera/gallery preprocessing and prediction flow.

Preprocessing stage images are in `preprocessed/preprocessing_steps/`; the four-stage contact sheet is `preprocessing_steps_contact_sheet.png`.
