import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../config/env_config.dart';

/// Activates Firebase App Check after Firebase.initializeApp and before any
/// protected backend call. A failure is logged, never bypassed: the gateway
/// endpoint independently rejects requests without a valid App Check token.
Future<void> activateAppCheck() async {
  final siteKey = EnvConfig.appCheckWebSiteKey;
  if (siteKey.isEmpty) {
    throw StateError('APP_CHECK_WEB_SITE_KEY is required');
  }

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider(siteKey),
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );
}
