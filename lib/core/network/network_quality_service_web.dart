import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

enum NetworkQuality {
  fast,
  moderate,
  slow,
}

/// Detects network quality and data-saving mode on web.
class NetworkQualityService {
  NetworkQualityService._();

  static final NetworkQualityService instance = NetworkQualityService._();

  final ValueNotifier<NetworkQuality> qualityNotifier =
      ValueNotifier<NetworkQuality>(NetworkQuality.fast);

  @visibleForTesting
  static NetworkQuality? debugOverrideQuality;

  @visibleForTesting
  static bool? debugOverrideSaveData;

  @visibleForTesting
  static void debugReset() {
    debugOverrideQuality = null;
    debugOverrideSaveData = null;
    instance.qualityNotifier.value = NetworkQuality.fast;
  }

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _updateQuality();

    try {
      final nav = web.window.navigator as JSObject;
      if (nav.has('connection')) {
        final conn = nav['connection'] as JSObject?;
        if (conn != null && conn.has('addEventListener')) {
          conn.callMethod(
            'addEventListener'.toJS,
            'change'.toJS,
            (() {
              _updateQuality();
            }).toJS,
          );
        }
      }
    } catch (_) {
      // Browser does not support navigator.connection event listener.
    }
  }

  void _updateQuality() {
    qualityNotifier.value = _computeQuality();
  }

  NetworkQuality _computeQuality() {
    if (debugOverrideQuality != null) return debugOverrideQuality!;

    try {
      final params = Uri.base.queryParameters;
      final netParam = params['network']?.toLowerCase();
      if (netParam == 'slow' || netParam == '2g' || netParam == '3g') {
        return NetworkQuality.slow;
      }
      if (netParam == 'moderate') return NetworkQuality.moderate;
      if (netParam == 'fast' || netParam == '4g') return NetworkQuality.fast;
    } catch (_) {
      // Uri.base query parameters not available in this environment.
    }

    try {
      final nav = web.window.navigator as JSObject;
      if (nav.has('connection')) {
        final conn = nav['connection'] as JSObject?;
        if (conn != null) {
          final saveData = (conn['saveData'] as JSBoolean?)?.toDart ?? false;
          if (saveData) return NetworkQuality.slow;

          final effectiveType =
              (conn['effectiveType'] as JSString?)?.toDart.toLowerCase();
          if (effectiveType == 'slow-2g' ||
              effectiveType == '2g' ||
              effectiveType == '3g') {
            return NetworkQuality.slow;
          }

          final rtt = (conn['rtt'] as JSNumber?)?.toDartDouble;
          if (rtt != null && rtt > 500) {
            return NetworkQuality.slow;
          }
          if (rtt != null && rtt > 250) {
            return NetworkQuality.moderate;
          }
        }
      }
    } catch (_) {
      // Browser does not support navigator.connection API (e.g. Safari).
    }

    return NetworkQuality.fast;
  }

  NetworkQuality get quality => debugOverrideQuality ?? qualityNotifier.value;

  bool get isSlowConnection => quality == NetworkQuality.slow;

  bool get isSaveData {
    if (debugOverrideSaveData != null) return debugOverrideSaveData!;

    try {
      final params = Uri.base.queryParameters;
      final saveParam = params['savedata']?.toLowerCase();
      if (saveParam == '1' || saveParam == 'true') return true;
      if (saveParam == '0' || saveParam == 'false') return false;
    } catch (_) {
      // Query parameters unavailable.
    }

    try {
      final nav = web.window.navigator as JSObject;
      if (nav.has('connection')) {
        final conn = nav['connection'] as JSObject?;
        if (conn != null) {
          return (conn['saveData'] as JSBoolean?)?.toDart ?? false;
        }
      }
    } catch (_) {
      // navigator.connection unsupported.
    }

    return false;
  }
}
