import 'dart:js_interop';

@JS('__everglowDesktopVersion')
external JSString? get _version;

@JS('__everglowCheckForUpdates')
external void _checkForUpdates();

/// Only updater-capable desktop builds publish this bridge.
class DesktopApp {
  static String? get version => _version?.toDart;
  static void checkForUpdates() => _checkForUpdates();
}
