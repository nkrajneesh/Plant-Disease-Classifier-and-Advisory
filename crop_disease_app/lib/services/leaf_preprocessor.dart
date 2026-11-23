import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Matches the notebook's accuracy-improvement input pipeline:
/// EXIF orientation correction, RGB preservation, and 224 x 224 resizing.
/// Optional background removal, grayscale, and blur are intentionally off.
class LeafImagePreprocessor {
  static const int size = 224;

  /// Returns interleaved RGB bytes in row-major order.
  Uint8List preprocess(Uint8List encodedImage) {
    final decoded = img.decodeImage(encodedImage);
    if (decoded == null) {
      throw const FormatException('The selected file is not a readable image.');
    }

    final oriented = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      oriented,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );

    final rgb = Uint8List(size * size * 3);
    var offset = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final pixel = resized.getPixel(x, y);
        rgb[offset++] = pixel.r.round().clamp(0, 255).toInt();
        rgb[offset++] = pixel.g.round().clamp(0, 255).toInt();
        rgb[offset++] = pixel.b.round().clamp(0, 255).toInt();
      }
    }
    return rgb;
  }
}
