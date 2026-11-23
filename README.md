# Crop Disease Detection

This project contains a 16-class crop-leaf classifier, a separate invalid-image rejection branch, and an Android demonstration app. The research-style machine-learning report follows the section order used by Mohanty et al. (2016), while describing this project's own data, methods, and measured results.

## Dataset and preprocessing

The local raw image folder contains 17,645 leaf images across apple, corn, potato, and tomato classes. Dataset images are not included in this GitHub repository; add the dataset locally under `raw images/` before running training. The input pipeline corrects image orientation, preserves three-channel RGB, resizes to 224 x 224 pixels, then converts RGB to BGR and subtracts the ResNet50 channel means [103.939, 116.779, 123.68]. The normalized float32 tensor is not divided by 255.

The leaf split is 70/15/15 and is fixed before augmentation. Training data is balanced to 2,000 images for each of the 16 supported leaf classes. Background removal, grayscale conversion, Gaussian blur, and thresholding are not enabled in the final training run.

The notebook `crop_disease_detection.ipynb` contains the preprocessing, balancing, training, evaluation, and inference workflow. Step images and the exact normalized sample tensor are saved in `preprocessed/preprocessing_steps/`.

## Training and results

The selected model is ImageNet-pretrained ResNet50. Training used a frozen-backbone classification head followed by conv5_x fine-tuning on an NVIDIA GTX 1650 through TensorFlow DirectML. The final test set contains 2,647 supported leaves and 3,925 unrelated Imagenette images.

- Leaf-only accuracy: 98.90% (2,618/2,647)
- 17-output argmax accuracy: 99.51% (6,540/6,572)
- Gated end-to-end accuracy: 99.54% (6,542/6,572)
- Invalid-image gate: 3,924/3,925 non-leaf images rejected; one false acceptance

These results describe the held-out project split. They do not establish field performance or guarantee rejection of every arbitrary image. The TFLite model was checked for parity on one image; full test metrics are from the Keras model.

## Main artifacts

- Research report: `crop_disease_model_final_report.docx` and `Crop_Disease_ML_Report.pdf`
- Keras model: `model_output/retrained_balanced_2000_gpu/resnet50_leafgate.keras`
- TensorFlow Lite model: `model_output/retrained_balanced_2000_gpu/crop_disease_leaf_gate.tflite`
- Model metadata and class order: `model_output/retrained_balanced_2000_gpu/model_metadata.json` and `class_names.json`
- Training and evaluation graphs: `model_output/retrained_balanced_2000_gpu/report_figures/`
- Flutter app source: `crop_disease_app/`
- Android APK: build locally with `flutter build apk --release`; the root submission copy is excluded from GitHub.
- Training script: `retrain_crop_disease_balanced2000_gpu.py`
- Dataset balancing script: `prepare_balanced_2000.py`

The individual preprocessing outputs are under `preprocessed/preprocessing_steps/`. The exact normalized tensor is the `.npy` file; the normalized PNG is a visualization only.

## GitHub contents

The root `.gitignore` excludes local datasets, generated balanced image folders, Python environments, training checkpoints, cached features, report-render previews, and the root APK. These files remain on the computer but are not part of the GitHub upload. The Flutter model asset (`crop_disease_app/assets/crop_disease_resnet50.tflite`) is retained so the app can be built from the repository. To retrain, obtain the source leaf dataset and Imagenette data separately and place them in the ignored folders described by the training scripts.
