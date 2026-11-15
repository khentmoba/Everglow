import 'package:flutter/foundation.dart';

enum NetworkQuality {
  fast,
  moderate,
  slow,
}

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

  void init() {}

  NetworkQuality get quality => debugOverrideQuality ?? qualityNotifier.value;

  bool get isSlowConnection => quality == NetworkQuality.slow;

  bool get isSaveData => debugOverrideSaveData ?? false;
}
