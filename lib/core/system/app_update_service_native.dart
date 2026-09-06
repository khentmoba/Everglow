import 'package:flutter/foundation.dart';

/// Native no-op twin of `app_update_service_web.dart`: version polling only
/// makes sense on web (native builds update through the store), so every
/// member here just keeps the shared API compiling off-web.
class AppUpdateService extends ChangeNotifier {
  static const pollInterval = Duration(minutes: 15);

  String? get bootBuild => null;
  String? get latestBuild => null;
  bool get updateAvailable => false;

  void dismiss() {}

  Future<void> start() async {}
  Future<void> checkNow() async {}
  Future<String?> fetchLiveBuild() async => null;

  static String? parseBuild(String body) => null;
}
