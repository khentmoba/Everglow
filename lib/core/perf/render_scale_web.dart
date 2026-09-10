// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:ui_web' as ui_web;

import '../utils/logger.dart';

/// Renders at [scale] device pixels per logical pixel, or restores the
/// browser's own DPR when [scale] is null.
///
/// Why this exists: an iPhone 15 Pro Max reports `devicePixelRatio` 3, so
/// Flutter Web draws into a 1290x2796 WebGL surface and re-draws every one of
/// those ~3.6M pixels on every frame (the web engine keeps draw lists, not
/// rendered bitmaps). Rendering at 2.0 roughly halves that fill cost while the
/// layout stays identical: the engine measures the viewport in CSS pixels and
/// divides by the same DPR, so only the backbuffer resolution changes.
///
/// Timing matters: the physical size is computed once and cached, so this must
/// run before the first frame (or before a reload) to take effect.
void applyRenderScaleOverride(double? scale) {
  try {
    ui_web.debugOverrideDevicePixelRatio(scale);
  } catch (e) {
    Logger.e('[Perf] render scale override failed', error: e);
  }
}
