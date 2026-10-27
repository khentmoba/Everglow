// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import '../utils/logger.dart';
import 'device_capability.dart';

/// Renders at [scale] device pixels per logical pixel, or applies an adaptive
/// cap when [scale] is null to protect slow/high-DPR devices.
///
/// Why this exists: an iPhone 15 Pro Max reports `devicePixelRatio` 3, so
/// Flutter Web draws into a 1290x2796 WebGL surface and re-draws every one of
/// those ~3.6M pixels on every frame (the web engine keeps draw lists, not
/// rendered bitmaps). Rendering at 2.0 roughly halves that fill cost (~55.6%
/// fewer pixels) while the layout stays identical.
///
/// On low-end devices (4 or fewer cores, <= 4GB RAM) with DPR > 1.75, capping
/// to 1.75 or 1.5 cuts the fill-rate cost by 65-75%, delivering a massive
/// speedup on budget hardware.
///
/// Timing matters: the physical size is computed once and cached, so this must
/// run before the first frame (or before a reload) to take effect.
void applyRenderScaleOverride(double? scale) {
  try {
    if (scale != null) {
      ui_web.debugOverrideDevicePixelRatio(scale);
      return;
    }

    // When scale is null (auto/device default), adaptively cap high-DPR screens.
    final nativeDpr = web.window.devicePixelRatio.toDouble();
    if (DeviceCapability.isLowEndDevice && nativeDpr > 1.75) {
      // Low-end device: cap at 1.75 to save up to 66% raster work.
      ui_web.debugOverrideDevicePixelRatio(1.75);
      Logger.i('[Perf] low-end device detected: adaptive DPR capped to 1.75 (from $nativeDpr)');
    } else if (nativeDpr >= 2.5) {
      final shortest = web.window.innerWidth < web.window.innerHeight
          ? web.window.innerWidth
          : web.window.innerHeight;
      if (shortest < 600) {
        // High-DPR phone screen: cap at 2.0 to halve composite fill cost.
        ui_web.debugOverrideDevicePixelRatio(2.0);
        Logger.i('[Perf] high-DPR phone detected: adaptive DPR capped to 2.0 (from $nativeDpr)');
      } else {
        ui_web.debugOverrideDevicePixelRatio(null);
      }
    } else {
      ui_web.debugOverrideDevicePixelRatio(null);
    }
  } catch (e) {
    Logger.e('[Perf] render scale override failed', error: e);
  }
}
