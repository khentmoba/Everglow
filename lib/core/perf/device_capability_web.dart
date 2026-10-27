import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Detects hardware capability (cores, RAM, low-end profile) on web.
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

  /// Logical processor count from `navigator.hardwareConcurrency`.
  static int get hardwareConcurrency {
    if (debugOverrideCores != null) return debugOverrideCores!;
    try {
      final cores = web.window.navigator.hardwareConcurrency;
      if (cores > 0) return cores;
    } catch (_) {
      // hardwareConcurrency unavailable on this browser.
    }
    return 4; // Safe default
  }

  /// Approximate RAM in gigabytes from `navigator.deviceMemory`.
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

  /// Whether the device is constrained by CPU or memory.
  ///
  /// Low-end criteria on web:
  /// - 4 or fewer CPU cores (budget phones, cheap tablets, throttled chips)
  /// - 4 GB or less RAM when reported by the browser
  /// - URL parameter `?lowend=1` or `?lowend=true` override
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
