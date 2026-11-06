import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../../../core/utils/logger.dart';

/// Web-specific helpers used by the Motchi screen.
///
/// Clipboard paste and canvas-based image resizing only exist in the
/// browser; the native twin keeps the same surface as safe no-ops /
/// codec-based resizing.
///
/// Uses `package:web` + `dart:js_interop` rather than the legacy `dart:html`
/// and `dart:js` libraries so this file also compiles for the WebAssembly
/// renderer, where both are unavailable. Behaviour is unchanged: the same
/// browser APIs are called with the same arguments.
class MotchiWebBridge {
  web.EventListener? _pasteListener;
  web.EventListener? _voiceVisibilityListener;
  JSObject? _recognition;
  Completer<String?>? _speech;
  Timer? _speechTimeout;
  String? _speechTranscript;
  JSObject? _audioContext;
  JSObject? _audioSource;
  web.MediaStream? _meterStream;
  Timer? _meterTimer;

  String get speechLanguage {
    final languages = web.window.navigator.languages.toDart.map(
      (language) => language.toDart,
    );
    return languages.firstWhere(
      (language) =>
          language.toLowerCase().startsWith('en-') || language == 'en',
      orElse: () => 'en-US',
    );
  }

  Future<void> _startAudioMeter(
    JSObject recognition,
    ValueChanged<double> onLevel,
  ) async {
    try {
      final devices = web.window.navigator.mediaDevices;
      final ctor =
          globalContext['AudioContext'] ?? globalContext['webkitAudioContext'];
      if (ctor == null) return;
      final context = (ctor as JSFunction).callAsConstructorVarArgs<JSObject>();
      _audioContext = context;
      // Resume in the tap, before awaiting microphone permission on Safari.
      _audioAction(context, 'resume');
      final audioConstraints = <String, Object>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      }.jsify()!;
      final stream = await devices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: audioConstraints,
              video: false.toJS,
            ),
          )
          .toDart;
      if (!identical(_recognition, recognition) ||
          !identical(_audioContext, context)) {
        for (final track in stream.getTracks().toDart) {
          track.stop();
        }
        return;
      }
      _meterStream = stream;
      final source = context.callMethodVarArgs<JSObject>(
        'createMediaStreamSource'.toJS,
        [stream],
      );
      _audioSource = source;
      final analyser = context.callMethodVarArgs<JSObject>(
        'createAnalyser'.toJS,
      );
      analyser['fftSize'] = 256.toJS;
      source.callMethodVarArgs('connect'.toJS, [analyser]);
      final samples = Uint8List(256);
      // Only measure locally; never record, upload, or connect to speakers.
      _meterTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        analyser.callMethodVarArgs('getByteTimeDomainData'.toJS, [
          samples.toJS,
        ]);
        var energy = 0.0;
        for (final sample in samples) {
          final amplitude = (sample - 128) / 128;
          energy += amplitude * amplitude;
        }
        onLevel((math.sqrt(energy / samples.length) * 4).clamp(0.0, 1.0));
      });
    } catch (error) {
      Logger.e('Motchi voice meter unavailable', error: error);
      if (identical(_recognition, recognition)) _stopAudioMeter();
    }
  }

  void _audioAction(JSObject context, String method) {
    try {
      final pending = context.callMethodVarArgs<JSObject>(method.toJS);
      pending.callMethodVarArgs('catch'.toJS, [
        ((JSAny? error) {
          Logger.e('Motchi audio $method failed', error: error);
        }).toJS,
      ]);
    } catch (error) {
      Logger.e('Motchi audio $method failed', error: error);
    }
  }

  void _stopAudioMeter() {
    _meterTimer?.cancel();
    _meterTimer = null;
    _audioSource?.callMethodVarArgs('disconnect'.toJS);
    _audioSource = null;
    for (final track
        in _meterStream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      track.stop();
    }
    _meterStream = null;
    final context = _audioContext;
    _audioContext = null;
    if (context != null) {
      _audioAction(context, 'close');
    }
  }

  void cancelRecognition() {
    final rec = _recognition;
    _finishSpeech(null);
    if (rec != null) {
      try {
        rec.callMethodVarArgs('abort'.toJS);
      } catch (error) {
        Logger.e('Motchi microphone could not close', error: error);
      }
    }
  }

  void stopRecognition() {
    _stopAudioMeter();
    try {
      _recognition?.callMethodVarArgs('stop'.toJS);
      if (_speech != null) {
        _speechTimeout?.cancel();
        _speechTimeout = Timer(const Duration(seconds: 3), () {
          _finishSpeech(_speechTranscript, abort: true);
        });
      }
    } catch (error) {
      _finishSpeech(null, error: error);
    }
  }

  void _finishSpeech(String? transcript, {Object? error, bool abort = false}) {
    final pending = _speech;
    _speech = null;
    _speechTimeout?.cancel();
    _speechTimeout = null;
    _speechTranscript = null;
    final rec = _recognition;
    _recognition = null;
    _stopAudioMeter();
    final visibilityListener = _voiceVisibilityListener;
    if (visibilityListener != null) {
      web.document.removeEventListener('visibilitychange', visibilityListener);
      _voiceVisibilityListener = null;
    }
    if (rec != null) {
      rec['onresult'] = null;
      rec['onerror'] = null;
      rec['onend'] = null;
      if (error != null || abort) {
        try {
          rec.callMethodVarArgs('abort'.toJS);
        } catch (abortError) {
          Logger.e('Motchi microphone could not close', error: abortError);
        }
      }
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
    _pasteListener = ((web.ClipboardEvent event) {
      final items = event.clipboardData?.items;
      if (items == null) return;
      final length = items.length;
      for (int i = 0; i < length; i++) {
        final item = items[i];
        if (item.type.startsWith('image/')) {
          final file = item.getAsFile();
          if (file != null) {
            final reader = web.FileReader();
            reader.addEventListener(
              'loadend',
              ((web.Event _) {
                final result = reader.result;
                final text = result.isA<JSString>()
                    ? (result as JSString).toDart
                    : null;
                if (text != null && text.contains(',')) {
                  final base64Data = text.split(',').last;
                  final ext = item.type.split('/').last;
                  onPasteDataUri('data:image/$ext;base64,$base64Data');
                }
              }).toJS,
            );
            reader.readAsDataURL(file);
          }
          break;
        }
      }
    }).toJS;
    web.window.addEventListener('paste', _pasteListener);
  }

  void uninstallPasteListener() {
    final listener = _pasteListener;
    if (listener == null) return;
    web.window.removeEventListener('paste', listener);
    _pasteListener = null;
  }

  bool get isSpeechSupported {
    if (globalContext.has('webkitSpeechRecognition')) return true;
    if (globalContext.has('SpeechRecognition')) return true;
    return false;
  }

  Future<String?> recognizeOnce({
    String? lang,
    ValueChanged<String>? onTranscript,
    ValueChanged<double>? onAudioLevel,
  }) {
    cancelRecognition();
    final ctor =
        globalContext['webkitSpeechRecognition'] ??
        globalContext['SpeechRecognition'];
    if (ctor == null) return Future.value(null);
    final pending = Completer<String?>();
    _speech = pending;
    final rec = (ctor as JSFunction).callAsConstructorVarArgs<JSObject>();
    _recognition = rec;
    _voiceVisibilityListener = ((web.Event _) {
      if (web.document.hidden) {
        _finishSpeech(_speechTranscript, abort: true);
      }
    }).toJS;
    web.document.addEventListener(
      'visibilitychange',
      _voiceVisibilityListener,
    );
    rec['lang'] = (lang ?? speechLanguage).toJS;
    rec['interimResults'] = true.toJS;
    rec['maxAlternatives'] = 1.toJS;
    rec['continuous'] = true.toJS;
    rec['onresult'] = ((JSAny? event) {
      if (!identical(_recognition, rec)) return;
      try {
        // Keep the latest full result list: interim words can be revised, and
        // mobile browsers may end listening without sending a final result.
        final browserEvent = event as JSObject;
        final results = browserEvent.getProperty<JSObject>('results'.toJS);
        final words = <String>[];
        final length = (results.getProperty<JSNumber>('length'.toJS)).toDartInt;
        for (var i = 0; i < length; i++) {
          final result = results.getProperty<JSObject>(i.toJS);
          final alternative = result.getProperty<JSObject>(0.toJS);
          final transcript = alternative['transcript'];
          final text = transcript.isA<JSString>()
              ? (transcript as JSString).toDart.trim()
              : null;
          if (text != null && text.isNotEmpty) words.add(text);
        }
        _speechTranscript = words.isEmpty ? null : words.join(' ');
        onTranscript?.call(_speechTranscript ?? '');
      } catch (error) {
        _finishSpeech(null, error: error);
      }
    }).toJS;
    rec['onerror'] = ((JSAny? event) {
      if (!identical(_recognition, rec)) return;
      final browserEvent = event as JSObject;
      final code = browserEvent['error']?.dartify()?.toString() ?? 'unknown';
      if (code == 'no-speech') {
        _finishSpeech(_speechTranscript, abort: true);
      } else {
        _finishSpeech(null, error: StateError(code));
      }
    }).toJS;
    rec['onend'] = ((JSAny? _) {
      if (identical(_recognition, rec)) _finishSpeech(_speechTranscript);
    }).toJS;
    // Start directly in the mic tap so Safari retains user activation.
    try {
      rec.callMethodVarArgs('start'.toJS);
      if (_speech != null) {
        _speechTimeout = Timer(const Duration(minutes: 2), stopRecognition);
        if (onAudioLevel != null) {
          unawaited(_startAudioMeter(rec, onAudioLevel));
        }
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
    final blob = web.Blob([bytes.toJS].toJS);
    final objectUrl = web.URL.createObjectURL(blob);
    final completer = Completer<String>();
    try {
      final img = web.HTMLImageElement();
      img.addEventListener(
        'load',
        ((web.Event _) {
          // A JS callback cannot be an async function (its Future return type
          // has no JS equivalent), so the async work is detached here.
          unawaited(() async {
          try {
            final scale = math.min(
              1.0,
              maxDim / math.max(img.naturalWidth, img.naturalHeight),
            );
            final w = (img.naturalWidth * scale).round().clamp(1, 4096);
            final h = (img.naturalHeight * scale).round().clamp(1, 4096);
            final canvas = web.HTMLCanvasElement()
              ..width = w
              ..height = h;
            final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
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
            completer.complete(canvas.toDataURL(mime, quality?.toJS));
          } catch (e) {
            completer.completeError(e);
          } finally {
            web.URL.revokeObjectURL(objectUrl);
          }
          }());
        }).toJS,
      );
      img.addEventListener(
        'error',
        ((web.Event _) {
          web.URL.revokeObjectURL(objectUrl);
          if (!completer.isCompleted) {
            completer.completeError(Exception('Image could not be loaded'));
          }
        }).toJS,
      );
      img.src = objectUrl;
      await completer.future;
    } catch (e) {
      web.URL.revokeObjectURL(objectUrl);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    return completer.future;
  }
}
