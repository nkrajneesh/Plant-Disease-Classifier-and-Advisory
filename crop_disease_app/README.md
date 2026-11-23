# CropCare Android App

CropCare is an offline Flutter demonstration for four crop groups: apple, corn, potato, and tomato. Its home screen provides camera and gallery actions. The app runs the ResNet50 TensorFlow Lite model on the phone and shows disease guidance only when the image passes the supported-leaf gate. Unsupported images open a separate invalid-image result screen.

## Model assets

The `assets/` folder contains the trained model, its 17 output labels (16 crop disease or healthy classes plus `__not_a_supported_leaf__`), and the exact rejection thresholds used during evaluation. Keep the files together and do not reorder the labels. Inputs are EXIF-oriented RGB images resized to 224 × 224, then converted from RGB to BGR and normalized by subtracting `[103.939, 116.779, 123.68]`.

The bundled model was fine-tuned from ImageNet-pretrained ResNet50 using the updated balanced dataset. Each of the 16 supported leaf classes has 2,000 training images (32,000 total), created using only raw training-split photos; validation and test photos were not augmented. On Keras inference with the same rejection rule used by the app, leaf-only accuracy was 98.90% (2,618 of 2,647) and gated end-to-end accuracy was 99.54% (6,542 of 6,572). The invalid-image gate rejected 3,924 of 3,925 unrelated images; one parachute photo was confidently accepted as corn Northern Leaf Blight. TensorFlow Lite was checked against Keras on a parity sample; the full test-set metrics are from Keras inference. These scores describe the held-out dataset and do not guarantee rejection of every possible unfamiliar image.

## Build the Android app

From this folder, install the Flutter packages and build a release APK:

```powershell
flutter pub get
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The project root also contains the submission copy, `CropCare.apk`.

## Model training and evaluation

Training code and generated metrics are in the project root and `model_output/retrained_balanced_2000_gpu/`. The training run used the NVIDIA GTX 1650 through TensorFlow DirectML, 2,000 examples per class in each epoch, offline leaf augmentation, a frozen ResNet50 head stage followed by `conv5_x` fine-tuning, and held-out evaluation. Training details, curves, confusion matrices, and limitations are in `crop_disease_model_final_report.docx` at the project root.

The app is an educational decision-support demo. The model recognizes only its 16 trained apple, corn, potato, and tomato leaf classes. Field photos, unfamiliar cultivars, mixed symptoms, and other conditions may produce errors; severe symptoms should be confirmed with a local plant-health specialist.
