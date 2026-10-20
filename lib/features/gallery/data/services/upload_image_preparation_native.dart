import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../../../core/utils/logger.dart';

Future<({Uint8List full, Uint8List? thumb})> prepareImages(Uint8List bytes) =>
    compute(prepareImagesSync, bytes);

({Uint8List full, Uint8List? thumb}) prepareImagesSync(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      return (
        full: encodeResized(decoded, 1600),
        thumb: encodeResized(decoded, 400),
      );
    }
  } catch (error) {
    Logger.e('Image resize failed, using original bytes', error: error);
  }
  return (full: bytes, thumb: null);
}

Uint8List encodeResized(img.Image image, int maxSize) {
  final longest = image.width > image.height ? image.width : image.height;
  final resized = longest <= maxSize
      ? image
      : img.copyResize(
          image,
          width: image.width >= image.height ? maxSize : null,
          height: image.height > image.width ? maxSize : null,
        );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}
