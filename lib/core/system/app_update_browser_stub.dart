class AppUpdateBrowser {
  AppUpdateBrowser._();

  static final AppUpdateBrowser instance = AppUpdateBrowser._();

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
