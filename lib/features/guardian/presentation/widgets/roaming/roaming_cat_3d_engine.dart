import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'roaming_guardian_cat.dart';

/// Bridges the offscreen three.js renderer (`web/cat_3d_engine.js`) into
/// Flutter as a stream of [ui.Image] frames.
///
/// The hidden WebGL canvas renders the real `chibi_cat.glb` every animation
/// frame; this engine copies those RGBA pixels into a Flutter image so the 3D
/// cat is painted as ordinary canvas content. That is what lets the same 3D
/// model walk genuinely *behind* dashboard widgets.
///
/// GPU stall fix: the JS side now runs at ~30fps with
/// preserveDrawingBuffer:false and a 192x192 canvas (down from 256) to cut
/// ReadPixels bandwidth ~44%. This Dart tick is gated to the same cadence
/// so we don't wake the GL pipeline at 60fps.
///
/// Battery fix: the loop pauses when the tab is hidden or when no widget is
/// listening ([setVisible]/[stop]), and the JS poll gives up after ~6s so a
/// blocked CDN can't spin a timer forever.
class RoamingCat3DEngine extends ChangeNotifier {
  RoamingCat3DEngine._() {
    _visibilityHandler = ((web.Event _) {
      if (web.document.visibilityState == 'hidden') {
        pause();
      } else if (_wantedRunning) {
        resume();
      }
    }).toJS;
    try {
      web.document.addEventListener(
        'visibilitychange',
        _visibilityHandler as web.EventListener,
      );
    } catch (_) {}
  }

  static final RoamingCat3DEngine instance = RoamingCat3DEngine._();

  static const int _width = 192;
  static const int _height = 192;
  // ~30fps -> 33ms between decoded frames. Matches JS TARGET_FRAME_MS.
  static const int _frameBudgetMs = 33;
  static const int _maxPollAttempts = 50;

  JSObject? _api;
  ui.Image? _image;
  bool _running = false;
  bool _wantedRunning = false;
  bool _paused = false;
  bool _decoding = false;
  bool _waitingForScript = false;
  bool _tickScheduled = false;
  int _lastDecodeAt = 0;
  int _pollAttempts = 0;
  JSAny? _visibilityHandler;

  ui.Image? get image => _image;
  bool get isRunning => _running && !_paused;
  int _activeViews = 0;

  /// Starts the render loop. Both dashboard layers share this one engine, so
  /// the 3D model is only rendered once per frame.
  void ensureRunning() {
    _wantedRunning = true;
    if (_running) {
      resume();
      return;
    }
    _running = true;
    _paused = web.document.visibilityState == 'hidden';
    _ensureMediaLibs();
    _pollForApi();
    _scheduleTick();
  }

  /// Temporarily halt frame readbacks (tab hidden / cat offscreen).
  /// Keeps the JS API warm so resume is instant.
  void pause() {
    _paused = true;
  }

  /// Resume after [pause] if [ensureRunning] was requested.
  void resume() {
    if (!_running) return;
    if (web.document.visibilityState == 'hidden') return;
    final wasPaused = _paused;
    _paused = false;
    if (wasPaused) _scheduleTick();
  }

  /// Hint from the UI: no layer currently shows the cat.
  void setVisible(bool visible) {
    if (visible) {
      _activeViews++;
      resume();
    } else {
      _activeViews = (_activeViews - 1).clamp(0, 1 << 30);
      if (_activeViews == 0) pause();
    }
  }

  /// Fully stop the loop and free the last frame. Call on dashboard dispose.
  void stop() {
    _wantedRunning = false;
    _running = false;
    _paused = false;
    _tickScheduled = false;
    final old = _image;
    _image = null;
    old?.dispose();
  }

  @override
  void dispose() {
    try {
      if (_visibilityHandler != null) {
        web.document.removeEventListener(
          'visibilitychange',
          _visibilityHandler! as web.EventListener,
        );
      }
    } catch (_) {}
    stop();
    super.dispose();
  }

  /// Pokes `index.html`'s lazy media loader so `cat_3d_engine.js` (+ three.js)
  /// starts downloading the moment the guardian mounts instead of waiting for
  /// the post-first-frame idle callback. No-op once loaded; safe to call
  /// before the loader exists (e.g. tests).
  void _ensureMediaLibs() {
    try {
      final fn = globalContext.getProperty<JSAny?>(
        '__everglowEnsureMediaLibs'.toJS,
      );
      if (fn != null && !fn.isUndefinedOrNull) {
        (fn as JSFunction).callAsFunction();
      }
    } catch (_) {}
  }

  /// Pushes the current animation state into the JS renderer.
  void setParams(RoamingCatFrame frame) {
    if (_paused) return;
    final api = _api;
    if (api == null) return;
    api.callMethod(
      'setParams'.toJS,
      <String, Object?>{
        'facing': frame.facing,
        'activity': frame.activity.name,
        'turning': frame.turning,
        'moving': frame.moving,
        'bob': frame.bob,
        'breath': frame.breath,
        'scale': frame.scale,
        'held': frame.held,
      }.jsify(),
    );
  }

  void _pollForApi() {
    if (_waitingForScript) return;
    _waitingForScript = true;
    _pollAttempts = 0;
    void poll() {
      if (!_running) {
        _waitingForScript = false;
        return;
      }
      _pollAttempts++;
      try {
        final api = globalContext.getProperty<JSObject>('EverglowCat3D'.toJS);
        if (!api.isUndefinedOrNull) {
          _api = api;
          _waitingForScript = false;
          return;
        }
      } catch (_) {}
      if (_pollAttempts >= _maxPollAttempts) {
        // CDN blocked or script failed — stop polling, stay on 2D fallback.
        _waitingForScript = false;
        return;
      }
      Timer(const Duration(milliseconds: 120), poll);
    }

    poll();
  }

  void _scheduleTick() {
    if (_tickScheduled || !_running) return;
    _tickScheduled = true;
    web.window.requestAnimationFrame(((double _) {
      _tickScheduled = false;
      _tick();
    }).toJS);
  }

  void _tick() {
    if (!_running || _paused) return;
    final api = _api;
    // Gate the whole GL readback to ~30fps so we don't stall the GPU at 60fps.
    if (api != null && !_decoding) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastDecodeAt >= _frameBudgetMs) {
        try {
          final result = api.callMethod<JSUint8Array?>('renderToBytes'.toJS);
          if (result != null && !result.isUndefinedOrNull) {
            _lastDecodeAt = now;
            _decode(result.toDart);
          }
        } catch (_) {
          // One bad frame must not kill the loop; try again next frame.
        }
      }
    }
    _scheduleTick();
  }

  void _decode(Uint8List pixels) {
    if (!_running || _paused) return;
    _decoding = true;
    ui.decodeImageFromPixels(pixels, _width, _height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      _decoding = false;
      if (!_running || _paused) {
        image.dispose();
        return;
      }
      final old = _image;
      _image = image;
      old?.dispose();
      notifyListeners();
    });
  }
}
