import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Picked image bytes plus an optional file name, shared by web/native.
class PickedImageData {
  const PickedImageData({required this.bytes, this.fileName});

  final Uint8List bytes;
  final String? fileName;
}

Future<PickedImageData?> pickImageBytes() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return PickedImageData(
    bytes: await picked.readAsBytes(),
    fileName: picked.name,
  );
}
