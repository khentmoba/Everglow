import 'package:everglow/core/router/app_error_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppErrorPage.homeRouteFor', () {
    test('logged-out user goes to the gate', () {
      expect(
        AppErrorPage.homeRouteFor(
          isAuthenticated: false,
          isCinemaOnlyUser: false,
        ),
        '/',
      );
    });

    test('couple user goes to the dashboard', () {
      expect(
        AppErrorPage.homeRouteFor(
          isAuthenticated: true,
          isCinemaOnlyUser: false,
        ),
        '/dashboard',
      );
    });

    test('cinema-only user goes to cinema', () {
      expect(
        AppErrorPage.homeRouteFor(
          isAuthenticated: true,
          isCinemaOnlyUser: true,
        ),
        '/cinema',
      );
    });
  });
}
