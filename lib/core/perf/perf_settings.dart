import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'render_scale.dart';

class PerfSettings {
  PerfSettings._();

  static const String _meterKey = 'perf_frame_meter_v1';
  static const String _scaleKey = 'perf_render_scale_v1';
  static const String _sizedDecodeKey = 'perf_sized_asset_decode_v1';

  static const double minScale = 1.0;
  static const double maxScale = 3.0;

  static final ValueNotifier<bool> frameMeter = ValueNotifier<bool>(false);

  static final ValueNotifier<double?> renderScale = ValueNotifier<double?>(
    null,
  );

  static final ValueNotifier<bool> sizedAssetDecode = ValueNotifier<bool>(true);

  static int? sizedDecodeWidth(int devicePixels) =>
      (sizedAssetDecode.value || !kIsWeb) ? devicePixels : null;

  static bool _loaded = false;

  static Future<void> load({Map<String, String>? queryParameters}) async {
    if (_loaded) return;
    _loaded = true;

    var meter = false;
    double? scale;
    var sizedDecode = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      meter = prefs.getBool(_meterKey) ?? false;
      scale = prefs.getDouble(_scaleKey);
      sizedDecode = prefs.getBool(_sizedDecodeKey) ?? true;
    } catch (e) {
      Logger.e('[Perf] could not read perf switches', error: e);
    }

    final params = queryParameters ?? Uri.base.queryParameters;
    final perfParam = params['perf'];
    final dprParam = params['dpr'];
    final sizedParam = params['sizeddecode'];
    if (perfParam != null) meter = _isOn(perfParam);
    if (dprParam != null) {
      if (_isReset(dprParam)) {
        scale = null;
      } else {
        scale = _parseScale(dprParam) ?? scale;
      }
    }
    if (sizedParam != null) sizedDecode = _isOn(sizedParam);

    frameMeter.value = meter;
    renderScale.value = _validScale(scale);
    sizedAssetDecode.value = sizedDecode;
    applyRenderScaleOverride(renderScale.value);

    if (perfParam != null || dprParam != null || sizedParam != null) {
      await _persist();
    }

    Logger.i(
      '[Perf] meter=${frameMeter.value} '
      'renderScale=${renderScale.value ?? 'device'} '
      'sizedAssetDecode=${sizedAssetDecode.value} '
      'viewDpr=${_viewDevicePixelRatio()?.toStringAsFixed(2) ?? 'n/a'}',
    );
  }

  static double? _viewDevicePixelRatio() {
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isEmpty) return null;
      return views.first.devicePixelRatio;
    } catch (e) {
      Logger.e('[Perf] could not read view DPR', error: e);
      return null;
    }
  }

  static Future<void> setFrameMeter(bool on) async {
    frameMeter.value = on;
    await _persist();
  }

  static Future<void> setRenderScale(double? scale) async {
    renderScale.value = _validScale(scale);
    applyRenderScaleOverride(renderScale.value);
    await _persist();
  }

  static double? nextRenderScale(double? current) {
    if (current == null) return 2.0;
    if (current >= 2.0) return 1.5;
    return null;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_meterKey, frameMeter.value);
      await prefs.setBool(_sizedDecodeKey, sizedAssetDecode.value);
      final scale = renderScale.value;
      if (scale == null) {
        await prefs.remove(_scaleKey);
      } else {
        await prefs.setDouble(_scaleKey, scale);
      }
    } catch (e) {
      Logger.e('[Perf] could not save perf switches', error: e);
    }
  }

  @visibleForTesting
  static void debugReset() {
    _loaded = false;
    frameMeter.value = false;
    renderScale.value = null;
    sizedAssetDecode.value = true;
  }

  static bool _isOn(String raw) {
    final value = raw.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'on' || value == 'yes';
  }

  static bool _isReset(String raw) {
    final value = raw.trim().toLowerCase();
    return value == '0' ||
        value == 'reset' ||
        value == 'device' ||
        value == 'auto' ||
        value == 'off' ||
        value == 'null';
  }

  static double? _validScale(double? scale) {
    if (scale == null) return null;
    if (!scale.isFinite || scale < minScale || scale > maxScale) return null;
    return scale;
  }

  static double? _parseScale(String raw) =>
      _validScale(double.tryParse(raw.trim()));
}
