import 'package:everglow/core/system/app_update_browser.dart';
import 'package:everglow/core/system/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fake browser bridge: drives visibility, playback, and reloads without a
/// page, so the auto-update state machine is testable on the VM.
class FakeUpdateBrowser implements AppUpdateBrowser {
  bool hidden = false;
  bool offline = false;
  bool videoPlaying = false;
  bool reloaded = false;
  bool listenCancelled = false;
  void Function()? onHidden;
  void Function()? onVisible;
  void Function()? onOnline;

  @override
  bool get supported => true;

  @override
  bool get isHidden => hidden;

  @override
  bool get isOffline => offline;

  @override
  bool get isVideoPlaying => videoPlaying;

  @override
  void reload() {
    reloaded = true;
  }

  @override
  void Function() listen({
    required void Function() onHidden,
    required void Function() onVisible,
    required void Function() onOnline,
  }) {
    this.onHidden = onHidden;
    this.onVisible = onVisible;
    this.onOnline = onOnline;
    return () {
      listenCancelled = true;
    };
  }
}

void main() {
  test('parseBuild extracts the build stamp', () {
    expect(
      AppUpdateService.parseBuild(
        '{"build": "6.0.0+1-abc1234", "core": "main.dart.js?v=6.0.0+1-abc1234"}\n',
      ),
      '6.0.0+1-abc1234',
    );
  });

  test('parseBuild returns null for garbage', () {
    expect(AppUpdateService.parseBuild('not json'), isNull);
    expect(AppUpdateService.parseBuild('{}'), isNull);
    expect(AppUpdateService.parseBuild('{"build": ""}'), isNull);
    expect(AppUpdateService.parseBuild('{"build": 42}'), isNull);
  });

  test('parseCore extracts the version-busted shell URL', () {
    expect(
      AppUpdateService.parseCore(
        '{"build": "6.0.0+1-abc1234", "core": "main.dart.js?v=6.0.0+1-abc1234"}\n',
      ),
      'main.dart.js?v=6.0.0+1-abc1234',
    );
  });

  test('parseCore returns null when missing or garbage', () {
    expect(AppUpdateService.parseCore('{"build": "a"}'), isNull);
    expect(AppUpdateService.parseCore('{"core": ""}'), isNull);
    expect(AppUpdateService.parseCore('{"core": 42}'), isNull);
    expect(AppUpdateService.parseCore('not json'), isNull);
  });

  group('auto-update state machine', () {
    test('new build readies, counts down, then reloads', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser, countdownTotal: 3);
      addTearDown(service.dispose);

      await service.start();
      expect(browser.onHidden, isNotNull);
      expect(browser.onVisible, isNotNull);
      expect(browser.onOnline, isNotNull);

      await service.noteLiveBuild('a');
      expect(service.bootBuild, 'a');
      expect(service.updateAvailable, isFalse);

      await service.noteLiveBuild('b');
      expect(service.ready, isTrue);
      expect(service.updateAvailable, isTrue);
      expect(service.countdownSeconds, 3);

      service.tick();
      expect(service.countdownSeconds, 2);
      service.tick();
      service.tick();

      expect(browser.reloaded, isTrue);
      expect(service.updateAvailable, isFalse);
    });

    test('hidden tab switches at once, with no countdown', () async {
      final browser = FakeUpdateBrowser()..hidden = true;
      final service = AppUpdateService(browser: browser, countdownTotal: 30);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b');

      expect(browser.reloaded, isTrue);
      expect(service.countdownSeconds, isNull);
    });

    test('playing video holds the countdown until the tab hides', () async {
      final browser = FakeUpdateBrowser()..videoPlaying = true;
      final service = AppUpdateService(browser: browser, countdownTotal: 30);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b');

      // Banner shows, but movie night is never interrupted.
      expect(service.updateAvailable, isTrue);
      expect(service.countdownSeconds, isNull);

      browser
        ..videoPlaying = false
        ..hidden = true;
      browser.onHidden!();

      expect(browser.reloaded, isTrue);
    });

    test('pressing play mid-countdown pauses it', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser, countdownTotal: 30);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b');
      expect(service.countdownSeconds, 30);

      browser.videoPlaying = true;
      service.tick();

      expect(service.countdownSeconds, isNull);
      expect(service.updateAvailable, isTrue);
      expect(browser.reloaded, isFalse);
    });

    test('snooze pauses every auto path until it expires', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser, countdownTotal: 30);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b');
      expect(service.updateAvailable, isTrue);

      service.snooze();
      expect(service.snoozed, isTrue);
      expect(service.updateAvailable, isFalse);
      expect(service.countdownSeconds, isNull);

      // Even hiding the tab respects the snooze.
      browser.hidden = true;
      browser.onHidden!();
      expect(browser.reloaded, isFalse);

      service.debugExpireSnooze();
      browser.onHidden!();
      expect(browser.reloaded, isTrue);
    });

    test('checkNow picks up a deploy end to end', () async {
      var live = 'a';
      final client = MockClient((request) async {
        if (request.url.path == '/version.json') {
          return http.Response(
            '{"build": "$live", "core": "main.dart.js?v=$live"}',
            200,
          );
        }
        return http.Response('shell-bytes', 200);
      });
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(
        browser: browser,
        httpClient: client,
        countdownTotal: 2,
      );
      addTearDown(service.dispose);

      await service.start();
      expect(service.bootBuild, 'a');
      expect(service.updateAvailable, isFalse);

      live = 'b';
      await service.checkNow();

      expect(service.ready, isTrue);
      expect(service.countdownSeconds, 2);
      service.tick();
      service.tick();
      expect(browser.reloaded, isTrue);
    });

    test('failed warm still readies: the reload streams instead', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(
        browser: browser,
        httpClient: client,
        countdownTotal: 1,
      );
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b', 'main.dart.js?v=b');

      expect(service.ready, isTrue);
      service.tick();
      expect(browser.reloaded, isTrue);
    });

    test('same build means no update', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('a');

      expect(service.ready, isFalse);
      expect(service.updateAvailable, isFalse);
      expect(browser.reloaded, isFalse);
    });

    test('offline checks are skipped', () async {
      final browser = FakeUpdateBrowser()..offline = true;
      final service = AppUpdateService(browser: browser);
      addTearDown(service.dispose);

      await service.start();
      await service.checkNow();

      expect(service.bootBuild, isNull);
      expect(service.updateAvailable, isFalse);
    });

    test('unsupported bridge stays quiet', () async {
      final service = AppUpdateService();
      addTearDown(service.dispose);

      // On the VM the default bridge is the no-op stub: start is a safe
      // no-op and checks never produce a build (relative fetch fails).
      await service.start();
      await service.checkNow();

      expect(service.bootBuild, isNull);
      expect(service.updateAvailable, isFalse);
    });

    test('dispose cancels the browser listeners', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser);

      await service.start();
      service.dispose();

      expect(browser.listenCancelled, isTrue);
    });
  });
}
