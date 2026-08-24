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
class RoamingCat3DEngine extends ChangeNotifier {
  RoamingCat3DEngine._();

  static final RoamingCat3DEngine instance = RoamingCat3DEngine._();

  static const int _width = 256;
  static const int _height = 256;

  JSObject? _api;
  ui.Image? _image;
  bool _running = false;
  bool _decoding = false;
  bool _waitingForScript = false;
  int _lastDecodeAt = 0;

  ui.Image? get image => _image;

  /// Starts the render loop. Both dashboard layers share this one engine, so
  /// the 3D model is only rendered once per frame.
  void ensureRunning() {
    if (_running) return;
    _running = true;
    _pollForApi();
    _tick();
  }

  /// Pushes the current animation state into the JS renderer.
  void setParams(RoamingCatFrame frame) {
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
    void poll() {
      final api = globalContext.getProperty<JSObject>('EverglowCat3D'.toJS);
      if (!api.isUndefinedOrNull) {
        _api = api;
        _waitingForScript = false;
        return;
      }
      Timer(const Duration(milliseconds: 120), poll);
    }

    poll();
  }

  void _tick() {
    if (!_running) return;
    final api = _api;
    if (api != null && !_decoding) {
      final result = api.callMethod<JSUint8Array?>('renderToBytes'.toJS);
      if (result != null && !result.isUndefinedOrNull) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastDecodeAt > 32) {
          _lastDecodeAt = now;
          _decode(result.toDart);
        }
      }
    }
    web.window.requestAnimationFrame(((double _) => _tick()).toJS);
  }

  void _decode(Uint8List pixels) {
    _decoding = true;
    ui.decodeImageFromPixels(pixels, _width, _height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      _decoding = false;
      final old = _image;
      _image = image;
      old?.dispose();
      notifyListeners();
    });
  }
}
