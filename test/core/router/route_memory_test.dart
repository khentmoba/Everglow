import 'package:everglow/core/router/route_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RouteMemory.bootLocation = null;
    RouteMemory.debugResetConsume();
  });

  group('restorableOrNull', () {
    test('keeps plain couple pages', () {
      expect(RouteMemory.restorableOrNull('/dashboard'), '/dashboard');
      expect(RouteMemory.restorableOrNull('/chat'), '/chat');
      expect(RouteMemory.restorableOrNull('/cinema'), '/cinema');
    });

    test('keeps the full query so parameterized pages reopen exactly', () {
      expect(
        RouteMemory.restorableOrNull('/cinema/video/123?title=Foo&type=movie'),
        '/cinema/video/123?title=Foo&type=movie',
      );
    });

    test('drops the gateway and its login-return form', () {
      expect(RouteMemory.restorableOrNull('/'), isNull);
      expect(RouteMemory.restorableOrNull('/?from=/chat'), isNull);
      expect(RouteMemory.restorableOrNull(''), isNull);
      expect(RouteMemory.restorableOrNull(null), isNull);
    });

    test('drops routes that need an in-memory extra payload', () {
      for (final path in RouteMemory.extraOnlyPaths) {
        expect(
          RouteMemory.restorableOrNull(path),
          isNull,
          reason: '$path shows the error page on plain reload',
        );
      }
    });

    test('drops external and sneaky locations', () {
      expect(RouteMemory.restorableOrNull('https://evil.example/chat'), isNull);
      expect(RouteMemory.restorableOrNull('//evil.example/chat'), isNull);
      expect(RouteMemory.restorableOrNull('/chat/../../admin'), isNull);
    });
  });

  group('bootRestoreTarget', () {
    const remembered = '/journal';
    final bareGateway = Uri.parse('/');

    test('logged-in bare gateway reopens the remembered page', () {
      expect(
        RouteMemory.bootRestoreTarget(
          authed: true,
          cinemaOnly: false,
          uri: bareGateway,
          remembered: remembered,
        ),
        '/journal',
      );
    });

    test('logged-out bare gateway hops through the login return flow', () {
      expect(
        RouteMemory.bootRestoreTarget(
          authed: false,
          cinemaOnly: false,
          uri: bareGateway,
          remembered: remembered,
        ),
        '/?from=%2Fjournal',
      );
    });

    test('real links always win over the restore', () {
      for (final uri in [
        Uri.parse('/cinema'),
        Uri.parse('/?from=/chat'),
        Uri.parse('/?dev=khent'),
        Uri.parse('/dashboard?perf=1'),
      ]) {
        expect(
          RouteMemory.bootRestoreTarget(
            authed: true,
            cinemaOnly: false,
            uri: uri,
            remembered: remembered,
          ),
          isNull,
          reason: '$uri must be left untouched',
        );
      }
    });

    test('nothing remembered means no restore', () {
      expect(
        RouteMemory.bootRestoreTarget(
          authed: true,
          cinemaOnly: false,
          uri: bareGateway,
          remembered: null,
        ),
        isNull,
      );
    });

    test('unsafe remembered pages are not restored', () {
      for (final bad in ['/manga/reader', '/', 'https://evil.example/x']) {
        expect(
          RouteMemory.bootRestoreTarget(
            authed: true,
            cinemaOnly: false,
            uri: bareGateway,
            remembered: bad,
          ),
          isNull,
          reason: '$bad must never be a restore target',
        );
      }
    });

    test('cinema-only users restore inside /cinema only', () {
      expect(
        RouteMemory.bootRestoreTarget(
          authed: true,
          cinemaOnly: true,
          uri: bareGateway,
          remembered: '/cinema',
        ),
        '/cinema',
      );
      expect(
        RouteMemory.bootRestoreTarget(
          authed: true,
          cinemaOnly: true,
          uri: bareGateway,
          remembered: '/journal',
        ),
        '/cinema',
      );
    });
  });

  group('consumeBootLocation', () {
    test('yields the page once, then nothing', () async {
      await RouteMemory.remember('/chat');
      await RouteMemory.load();
      expect(RouteMemory.consumeBootLocation(), '/chat');
      expect(RouteMemory.consumeBootLocation(), isNull);
    });
  });

  group('remember / load', () {
    test('round-trips a safe page through device storage', () async {
      await RouteMemory.remember('/journal');
      RouteMemory.bootLocation = null;
      await RouteMemory.load();
      expect(RouteMemory.bootLocation, '/journal');
    });

    test('never stores unsafe pages', () async {
      await RouteMemory.remember('/manga/reader');
      await RouteMemory.load();
      expect(RouteMemory.bootLocation, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(RouteMemory.storageKey), isNull);
    });

    test('an unsafe remember keeps the previous safe page', () async {
      await RouteMemory.remember('/chat');
      await RouteMemory.remember('/watch-party');
      RouteMemory.bootLocation = null;
      await RouteMemory.load();
      expect(RouteMemory.bootLocation, '/chat');
    });

    test('clear forgets the page', () async {
      await RouteMemory.remember('/chat');
      await RouteMemory.clear();
      expect(RouteMemory.bootLocation, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(RouteMemory.storageKey), isNull);
    });
  });
}
