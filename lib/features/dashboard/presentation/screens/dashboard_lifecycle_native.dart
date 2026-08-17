import 'package:flutter/foundation.dart';

/// No-op on non-web platforms; app lifecycle is handled by Flutter.
class DashboardLifecycle {
  void install(VoidCallback onPageHidden) {}

  void uninstall() {}
}
