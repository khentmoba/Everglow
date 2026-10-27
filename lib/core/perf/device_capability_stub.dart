import 'package:flutter/foundation.dart';

/// Detects hardware capability (cores, RAM, low-end profile) on native/test platforms.
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

  /// Logical processor count.
  static int get hardwareConcurrency =>
      debugOverrideCores ?? PlatformDispatcher.instance.views.length;

  /// Approximate RAM in gigabytes (null when unsupported).
  static double? get deviceMemory => debugOverrideMemory;

  /// Whether the device is constrained by CPU or memory.
  static bool get isLowEndDevice {
    if (debugOverrideLowEnd != null) return debugOverrideLowEnd!;
    if (debugOverrideCores != null && debugOverrideCores! <= 4) return true;
    if (debugOverrideMemory != null && debugOverrideMemory! <= 4.0) return true;
    return false;
  }
}
