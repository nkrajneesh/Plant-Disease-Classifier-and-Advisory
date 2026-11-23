# Preprocessing step images

These examples come from one raw image in the training split.

- `00_raw_training_image.png`: original training image, decoded as RGB for display.
- `01_exif_corrected_rgb.png`: EXIF orientation corrected and three-channel RGB preserved.
- `02_resized_224x224.png`: deterministic bilinear resize to the model input size.
- `03_resnet_normalized_display.png`: display-only view of the signed ResNet50 tensor after RGB-to-BGR and ImageNet mean subtraction.
- `03_resnet_normalized_tensor.npy`: exact float32 model input after normalization, shape 224 x 224 x 3.
- `preprocessing_steps_contact_sheet.png`: four-stage contact sheet for the report.

Background removal, grayscale, Gaussian blur, and thresholding were not applied to the final training/evaluation input. The normalized display PNG uses a visualization offset and must not be substituted for the `.npy` tensor.
