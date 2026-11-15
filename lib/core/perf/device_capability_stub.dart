import 'package:flutter/foundation.dart';

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

  static int get hardwareConcurrency =>
      debugOverrideCores ?? PlatformDispatcher.instance.views.length;

  static double? get deviceMemory => debugOverrideMemory;

  static bool get isLowEndDevice {
    if (debugOverrideLowEnd != null) return debugOverrideLowEnd!;
    if (debugOverrideCores != null && debugOverrideCores! <= 4) return true;
    if (debugOverrideMemory != null && debugOverrideMemory! <= 4.0) return true;
    return false;
  }
}
