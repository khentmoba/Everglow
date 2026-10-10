// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';

/// Web-specific helpers used by the Motchi screen.
///
/// Clipboard paste and canvas-based image resizing only exist in the
/// browser; the native twin keeps the same surface as safe no-ops /
/// codec-based resizing.
class MotchiWebBridge {
  html.EventListener? _pasteListener;
  js.JsObject? _recognition;
  Completer<String?>? _speech;
  Timer? _speechTimeout;

  void cancelRecognition() {
    final rec = _recognition;
    _finishSpeech(null);
    if (rec != null) {
      try {
        rec.callMethod('abort');
      } catch (error) {
        Logger.e('Motchi microphone could not close', error: error);
      }
    }
  }

  void stopRecognition() {
    try {
      _recognition?.callMethod('stop');
    } catch (error) {
      _finishSpeech(null, error: error);
    }
  }

  void _finishSpeech(String? transcript, {Object? error}) {
    final pending = _speech;
    _speech = null;
    _speechTimeout?.cancel();
    _speechTimeout = null;
    final rec = _recognition;
    _recognition = null;
    if (rec != null) {
      rec['onresult'] = null;
      rec['onerror'] = null;
      rec['onend'] = null;
    }
    if (pending == null || pending.isCompleted) return;
    if (error != null) {
      pending.completeError(error);
    } else {
      pending.complete(transcript);
    }
  }

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

  bool get isSpeechSupported {
    if (js.context['webkitSpeechRecognition'] != null) return true;
    if (js.context['SpeechRecognition'] != null) return true;
    return false;
  }

  Future<String?> recognizeOnce({String lang = 'en-US'}) {
    cancelRecognition();
    final ctor =
        js.context['webkitSpeechRecognition'] ??
        js.context['SpeechRecognition'];
    if (ctor == null) return Future.value(null);
    final pending = Completer<String?>();
    _speech = pending;
    final rec = js.JsObject(ctor);
    _recognition = rec;
    rec['lang'] = lang;
    rec['interimResults'] = true;
    rec['maxAlternatives'] = 1;
    rec['continuous'] = false;
    String? transcript;
    rec['onresult'] = (dynamic event) {
      if (!identical(_recognition, rec)) return;
      try {
        // Keep the latest full result list: interim words can be revised, and
        // mobile browsers may end listening without sending a final result.
        // ignore: avoid_dynamic_calls
        final results = event['results'] as js.JsObject;
        final words = <String>[];
        final length = results['length'] as int;
        for (var i = 0; i < length; i++) {
          final result = results[i] as js.JsObject;
          final alternative = result[0] as js.JsObject;
          final text = alternative['transcript']?.toString().trim();
          if (text != null && text.isNotEmpty) words.add(text);
        }
        transcript = words.isEmpty ? null : words.join(' ');
      } catch (error) {
        _finishSpeech(null, error: error);
      }
    };
    rec['onerror'] = (dynamic event) {
      if (!identical(_recognition, rec)) return;
      // ignore: avoid_dynamic_calls
      final code = event['error']?.toString() ?? 'unknown';
      _finishSpeech(null, error: StateError(code));
    };
    rec['onend'] = (dynamic _) {
      if (identical(_recognition, rec)) _finishSpeech(transcript);
    };
    // Start directly in the mic tap so Safari retains user activation.
    try {
      rec.callMethod('start');
      if (_speech != null) {
        _speechTimeout = Timer(const Duration(seconds: 45), cancelRecognition);
      }
    } catch (error) {
      _finishSpeech(null, error: error);
    }
    return pending.future;
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
          final isPng =
              bytes.length > 8 &&
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
