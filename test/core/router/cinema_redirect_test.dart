import 'package:everglow/core/router/app_error_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cinema shell gives cinema-only profiles (Breyan / Octagram) an
/// Anime button, but the router guard used to bounce `/anime` straight
/// back to `/cinema` — so the button looked dead. This locks the
/// allow-list: cinema + anime pass, couple pages bounce.
void main() {
  group('AppErrorPage.cinemaOnlyRedirect', () {
    test('lets cinema-only profiles reach anime', () {
      expect(AppErrorPage.cinemaOnlyRedirect('/anime'), isNull);
    });

    test('lets cinema-only profiles stay in cinema and gateway', () {
      expect(AppErrorPage.cinemaOnlyRedirect('/'), isNull);
      expect(AppErrorPage.cinemaOnlyRedirect('/cinema'), isNull);
      expect(
        AppErrorPage.cinemaOnlyRedirect('/cinema/video/123?type=movie'),
        isNull,
      );
    });

    test('bounces couple-only pages back to cinema', () {
      expect(AppErrorPage.cinemaOnlyRedirect('/dashboard'), '/cinema');
      expect(AppErrorPage.cinemaOnlyRedirect('/chat'), '/cinema');
      expect(AppErrorPage.cinemaOnlyRedirect('/books'), '/cinema');
    });
  });
}
