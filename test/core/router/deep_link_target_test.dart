import 'package:everglow/core/router/route_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The router bounces logged-out deep links to `/?from=<intended page>`
/// so a PR preview link lands straight on the fixed screen after one
/// login. `deepLinkTarget` reads that value back; the `from` param comes
/// from the URL bar, so anything but a safe internal path must fall back
/// to the default home.
void main() {
  group('deepLinkTarget', () {
    test('returns the remembered page for a plain internal path', () {
      expect(
        deepLinkTarget(
          Uri(path: '/', queryParameters: {'from': '/cinema'}),
          cinemaOnly: false,
        ),
        '/cinema',
      );
    });

    test('keeps query params on the remembered page', () {
      expect(
        deepLinkTarget(
          Uri(
            path: '/',
            queryParameters: {
              'from': '/cinema/video/123?title=Foo&type=movie',
            },
          ),
          cinemaOnly: false,
        ),
        '/cinema/video/123?title=Foo&type=movie',
      );
    });

    test('returns null when there is no from param', () {
      expect(
        deepLinkTarget(Uri(path: '/'), cinemaOnly: false),
        isNull,
      );
    });

    test('returns null when from points at the gateway itself', () {
      expect(
        deepLinkTarget(
          Uri(path: '/', queryParameters: {'from': '/'}),
          cinemaOnly: false,
        ),
        isNull,
      );
    });

    test('rejects external URLs', () {
      expect(
        deepLinkTarget(
          Uri(
            path: '/',
            queryParameters: {'from': 'https://evil.example/cinema'},
          ),
          cinemaOnly: false,
        ),
        isNull,
      );
    });

    test('rejects protocol-relative URLs', () {
      expect(
        deepLinkTarget(
          Uri(path: '/', queryParameters: {'from': '//evil.example/cinema'}),
          cinemaOnly: false,
        ),
        isNull,
      );
    });

    test('rejects paths with parent traversal', () {
      expect(
        deepLinkTarget(
          Uri(path: '/', queryParameters: {'from': '/cinema/../../admin'}),
          cinemaOnly: false,
        ),
        isNull,
      );
    });

    test('keeps cinema-only users inside /cinema', () {
      expect(
        deepLinkTarget(
          Uri(path: '/', queryParameters: {'from': '/dashboard'}),
          cinemaOnly: true,
        ),
        isNull,
      );
      expect(
        deepLinkTarget(
          Uri(path: '/', queryParameters: {'from': '/cinema'}),
          cinemaOnly: true,
        ),
        '/cinema',
      );
    });
  });
}
