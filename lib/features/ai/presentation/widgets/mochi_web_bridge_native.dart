import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Native twin of [MochiWebBridge]; clipboard paste is unavailable and
/// image resizing uses Flutter's image codec instead of a browser canvas.
class MochiWebBridge {
  void installPasteListener(ValueChanged<String> onPasteDataUri) {}

  void uninstallPasteListener() {}

  Future<String> resizeImageToDataUri(
    Uint8List bytes, {
    int maxDim = 1280,
  }) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final scale = math.min(
      1.0,
      maxDim / math.max(source.width, source.height),
    );
    final width = (source.width * scale).round().clamp(1, 4096);
    final height = (source.height * scale).round().clamp(1, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(
        0,
        0,
        source.width.toDouble(),
        source.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final resized = await recorder.endRecording().toImage(width, height);
    final data = await resized.toByteData(format: ui.ImageByteFormat.png);
    source.dispose();
    resized.dispose();
    return 'data:image/png;base64,${base64Encode(data!.buffer.asUint8List())}';
  }
}
