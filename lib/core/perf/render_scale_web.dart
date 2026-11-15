// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:ui_web' as ui_web;

import '../utils/logger.dart';

void applyRenderScaleOverride(double? scale) {
  try {
    ui_web.debugOverrideDevicePixelRatio(scale);
  } catch (e) {
    Logger.e('[Perf] render scale override failed', error: e);
  }
}

