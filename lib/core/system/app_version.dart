abstract final class AppVersion {
  static const String current = '6.3.0+1';

  static String get display => current.split('+').first;
}
