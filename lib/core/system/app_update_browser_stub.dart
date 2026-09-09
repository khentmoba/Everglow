/// No-op twin of `app_update_browser_web.dart` for native builds (store
/// updates) and VM tests: every member just keeps the shared API compiling
/// off-web.
class AppUpdateBrowser {
  AppUpdateBrowser._();

  static final AppUpdateBrowser instance = AppUpdateBrowser._();

  /// Always false off-web: there is no page to update.
  bool get supported => false;

  bool get isHidden => false;

  bool get isOffline => false;

  bool get isVideoPlaying => false;

  void reload() {}

  void Function() listen({
    required void Function() onHidden,
    required void Function() onVisible,
    required void Function() onOnline,
  }) =>
      () {};
}
