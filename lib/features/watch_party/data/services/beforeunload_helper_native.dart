import 'package:flutter/foundation.dart';

/// No-op on non-web platforms; there is no page lifecycle to hook.
class BeforeUnloadHelper {
  void install(VoidCallback onUnload) {}

  void uninstall() {}
}
