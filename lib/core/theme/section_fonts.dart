import 'package:flutter/services.dart';

/// Bundled section fonts load before their screen, rather than at the doorway.
class SectionFonts {
  static Future<void>? _reading;
  static Future<void>? _anime;

  static Future<void> reading() => _reading ??=
      _load('DM Sans', [
        'DMSans-Regular.ttf',
        'DMSans-Medium.ttf',
        'DMSans-SemiBold.ttf',
        'DMSans-Bold.ttf',
      ]).catchError((Object error, StackTrace stack) {
        _reading = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<void> anime() => _anime ??=
      Future.wait([
        reading(),
        _load('Bebas Neue', ['BebasNeue-Regular.ttf']),
      ]).then<void>((_) {}).catchError((Object error, StackTrace stack) {
        _anime = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<void> _load(String family, List<String> files) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/google_fonts/$file'));
    }
    return loader.load();
  }
}
