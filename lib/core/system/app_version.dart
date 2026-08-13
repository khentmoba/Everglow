/// Single source of truth for the Everglow app version.
///
/// Web builds cannot read `pubspec.yaml` at runtime, so the value is
/// duplicated here deliberately. Keep it in sync with the `version:`
/// field in `pubspec.yaml`; the analyzer and tests guard regressions.
abstract final class AppVersion {
  static const String current = '6.0.0+1';

  /// User-facing semantic version without the build suffix.
  static String get display => current.split('+').first;
}
