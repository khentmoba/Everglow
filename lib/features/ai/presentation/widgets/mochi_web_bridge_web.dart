// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Web-specific helpers used by the Mochi screen.
///
/// Clipboard paste and canvas-based image resizing only exist in the
/// browser; the native twin keeps the same surface as safe no-ops /
/// codec-based resizing.
class MochiWebBridge {
  html.EventListener? _pasteListener;

  void installPasteListener(ValueChanged<String> onPasteDataUri) {
    uninstallPasteListener();
    _pasteListener = (html.Event event) {
      final e = event as html.ClipboardEvent;
      final items = e.clipboardData?.items;
      if (items == null) return;
      final length = items.length ?? 0;
      for (int i = 0; i < length; i++) {
        final item = items[i];
        if (item.type?.startsWith('image/') == true) {
          final file = item.getAsFile();
          if (file != null) {
            final reader = html.FileReader();
            reader.onLoadEnd.listen((_) {
              final result = reader.result as String?;
              if (result != null && result.contains(',')) {
                final base64Data = result.split(',').last;
                final ext = item.type?.split('/').last ?? 'png';
                onPasteDataUri('data:image/$ext;base64,$base64Data');
              }
            });
            reader.readAsDataUrl(file);
          }
          break;
        }
      }
    };
    html.window.addEventListener('paste', _pasteListener);
  }

  void uninstallPasteListener() {
    if (_pasteListener == null) return;
    html.window.removeEventListener('paste', _pasteListener);
    _pasteListener = null;
  }

  /// Draws image bytes onto a canvas and returns a compact data URI.
  Future<String> resizeImageToDataUri(
    Uint8List bytes, {
    int maxDim = 1280,
  }) async {
    final blob = html.Blob([bytes]);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    final completer = Completer<String>();
    try {
      final img = html.ImageElement();
      img.onLoad.listen((_) async {
        try {
          final scale = math.min(
            1.0,
            maxDim / math.max(img.naturalWidth, img.naturalHeight),
          );
          final w = (img.naturalWidth * scale).round().clamp(1, 4096);
          final h = (img.naturalHeight * scale).round().clamp(1, 4096);
          final canvas = html.CanvasElement(width: w, height: h);
          final ctx = canvas.context2D;
          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'medium';
          ctx.drawImage(img, 0, 0);
          final isPng = bytes.length > 8 &&
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47;
          final mime = isPng ? 'image/png' : 'image/jpeg';
          final quality = isPng ? null : 0.82;
          completer.complete(canvas.toDataUrl(mime, quality));
        } catch (e) {
          completer.completeError(e);
        } finally {
          html.Url.revokeObjectUrl(objectUrl);
        }
      });
      img.onError.listen((_) {
        html.Url.revokeObjectUrl(objectUrl);
        if (!completer.isCompleted) {
          completer.completeError(Exception('Image could not be loaded'));
        }
      });
      img.src = objectUrl;
      await completer.future;
    } catch (e) {
      html.Url.revokeObjectUrl(objectUrl);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    return completer.future;
  }
}
