import 'package:everglow/core/router/route_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RouteMemory.bootLocation = null;
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
