import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class DeviceCapability {
  DeviceCapability._();

  @visibleForTesting
  static bool? debugOverrideLowEnd;

  @visibleForTesting
  static int? debugOverrideCores;

  @visibleForTesting
  static double? debugOverrideMemory;

  @visibleForTesting
  static void debugReset() {
    debugOverrideLowEnd = null;
    debugOverrideCores = null;
    debugOverrideMemory = null;
  }

  static int get hardwareConcurrency {
    if (debugOverrideCores != null) return debugOverrideCores!;
    try {
      final cores = web.window.navigator.hardwareConcurrency;
      if (cores > 0) return cores;
    } catch (_) {
      // hardwareConcurrency unavailable on this browser.
    }
    return 4;
  }

  static double? get deviceMemory {
    if (debugOverrideMemory != null) return debugOverrideMemory;
    try {
      final nav = web.window.navigator as JSObject;
      if (nav.has('deviceMemory')) {
        final mem = (nav['deviceMemory'] as JSNumber?)?.toDartDouble;
        if (mem != null && mem > 0) return mem;
      }
    } catch (_) {
      // deviceMemory unavailable on non-Chromium browsers.
    }
    return null;
  }

  static bool get isLowEndDevice {
    if (debugOverrideLowEnd != null) return debugOverrideLowEnd!;

    try {
      final params = Uri.base.queryParameters;
      final flag = params['lowend'];
      if (flag != null) {
        final lower = flag.trim().toLowerCase();
        if (lower == '1' || lower == 'true') return true;
        if (lower == '0' || lower == 'false') return false;
      }
    } catch (_) {
      // Uri.base not available or failed to read query parameters.
    }

    final cores = hardwareConcurrency;
    if (cores > 0 && cores <= 4) return true;

    final mem = deviceMemory;
    if (mem != null && mem <= 4.0) return true;

    return false;
  }
}
