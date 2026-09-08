import 'dart:typed_data';
import 'package:image_picker_web/image_picker_web.dart';

/// Picked image bytes plus an optional file name, shared by web/native.
class PickedImageData {
  const PickedImageData({required this.bytes, this.fileName});

  final Uint8List bytes;
  final String? fileName;
}

Future<PickedImageData?> pickImageBytes() async {
  final info = await ImagePickerWeb.getImageInfo;
  final data = info?.data;
  if (info == null || data == null) return null;
  return PickedImageData(bytes: data, fileName: info.fileName);
}
