import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'render_scale.dart';

/// On-device performance tooling switches: the frame meter and the render scale.
///
/// Why these live in the app instead of a desktop DevTools session: "the
/// dashboard feels heavy" is only true on Khent's iPhone, in the installed PWA,
/// where a query string can't be edited and Safari's remote inspector isn't
/// reachable. So both switches are persisted and are surfaced in Creator Studio
/// → System (Khent's private panel). They are off by default — Clair never sees
/// the meter or a reduced render scale.
///
/// `?perf=1` and `?dpr=2` are the desktop shortcuts for the same two switches,
/// and they stick (saved) so the PWA picks them up on the next launch.
class PerfSettings {
  PerfSettings._();

  static const String _meterKey = 'perf_frame_meter_v1';
  static const String _scaleKey = 'perf_render_scale_v1';

  /// Accepted render-scale range. Below 1.0 is always a visible quality loss,
  /// above 3.0 is never worth testing on a phone.
  static const double minScale = 1.0;
  static const double maxScale = 3.0;

  /// Frame meter on/off. The HUD is not mounted at all while this is false.
  static final ValueNotifier<bool> frameMeter = ValueNotifier<bool>(false);

  /// Device pixels per logical pixel, or null for "the browser's own DPR".
  static final ValueNotifier<double?> renderScale = ValueNotifier<double?>(null);

  static bool _loaded = false;

  /// Reads the saved switches, then lets `?perf=` / `?dpr=` override them.
  ///
  /// Call before `runApp`: the engine caches the view's physical size, so a
  /// saved render scale has to be in place for the very first frame.
  ///
  /// [queryParameters] exists for tests; production always reads the real URL.
  static Future<void> load({Map<String, String>? queryParameters}) async {
    if (_loaded) return;
    _loaded = true;

    var meter = false;
    double? scale;
    try {
      final prefs = await SharedPreferences.getInstance();
      meter = prefs.getBool(_meterKey) ?? false;
      scale = prefs.getDouble(_scaleKey);
    } catch (e) {
      // Never let a prefs failure block boot: defaults are the safe answer.
      Logger.e('[Perf] could not read perf switches', error: e);
    }

    final params = queryParameters ?? Uri.base.queryParameters;
    final perfParam = params['perf'];
    final dprParam = params['dpr'];
    if (perfParam != null) meter = _isOn(perfParam);
    if (dprParam != null) scale = _parseScale(dprParam) ?? scale;

    frameMeter.value = meter;
    renderScale.value = _validScale(scale);
    applyRenderScaleOverride(renderScale.value);

    // A URL switch is a one-off instruction, so remember it: the PWA launches
    // from the manifest start_url and would otherwise lose it.
    if (perfParam != null || dprParam != null) await _persist();

    // Log what the *framework* ends up seeing, not just what we asked for.
    // Debug builds only (Logger.i is release-silent); in release the frame
    // meter's `dpr` readout is how you confirm the override landed.
    Logger.i(
      '[Perf] meter=${frameMeter.value} '
      'renderScale=${renderScale.value ?? 'device'} '
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

  /// Sets the render scale. On web this only lands after a reload — the view's
  /// physical size is computed once and cached — so callers should offer one.
  static Future<void> setRenderScale(double? scale) async {
    renderScale.value = _validScale(scale);
    applyRenderScaleOverride(renderScale.value);
    await _persist();
  }

  /// The cycle the frame meter's `dpr` line taps through:
  /// device → 2.0x → 1.5x → device.
  ///
  /// 2.0 first because that is the setting worth testing: it roughly halves the
  /// pixels the browser has to composite on a 3x phone while keeping the layout
  /// identical.
  static double? nextRenderScale(double? current) {
    if (current == null) return 2.0;
    if (current >= 2.0) return 1.5;
    return null;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_meterKey, frameMeter.value);
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

  /// Clears the "already loaded" latch and both switches. Tests only.
  @visibleForTesting
  static void debugReset() {
    _loaded = false;
    frameMeter.value = false;
    renderScale.value = null;
  }

  static bool _isOn(String raw) {
    final value = raw.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'on' || value == 'yes';
  }

  /// Returns null (→ device DPR) for anything unparsable or out of range, so a
  /// typo in a query string can never ship an unreadable UI.
  static double? _validScale(double? scale) {
    if (scale == null) return null;
    if (scale < minScale || scale > maxScale) return null;
    return scale;
  }

  static double? _parseScale(String raw) => _validScale(double.tryParse(raw.trim()));
}
