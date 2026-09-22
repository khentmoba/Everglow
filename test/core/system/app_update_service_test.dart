import 'package:everglow/core/system/app_update_browser.dart';
import 'package:everglow/core/system/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fake browser bridge: drives visibility, playback, and reloads without a
/// page, so the update notification state machine is testable on the VM.
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

  group('update notification state machine', () {
    test('new build readies, shows update available, and never auto-reloads', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser);
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
      expect(browser.reloaded, isFalse);

      // Even if tab is hidden, tick occurs, or time passes: NEVER auto-reload!
      browser.hidden = true;
      browser.onHidden!();
      service.tick();
      expect(browser.reloaded, isFalse);
      expect(service.updateAvailable, isTrue);

      // Only manual user action applies the reload
      service.applyNow();
      expect(browser.reloaded, isTrue);
      expect(service.updateAvailable, isFalse);
    });

    test('dismiss hides the notification without reloading', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b');
      expect(service.updateAvailable, isTrue);
      expect(service.isDismissed, isFalse);

      service.dismiss();
      expect(service.isDismissed, isTrue);
      expect(service.snoozed, isTrue);
      expect(service.updateAvailable, isFalse);
      expect(browser.reloaded, isFalse);

      // Tab switching or hiding while dismissed still does not reload
      browser.hidden = true;
      browser.onHidden!();
      expect(browser.reloaded, isFalse);
    });

    test('subsequent newer build re-arms the notification after dismissal', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b');
      expect(service.updateAvailable, isTrue);

      service.dismiss();
      expect(service.updateAvailable, isFalse);

      // Server later reports build 'c'
      await service.noteLiveBuild('c');
      expect(service.latestBuild, 'c');
      expect(service.isDismissed, isFalse);
      expect(service.updateAvailable, isTrue);
      expect(browser.reloaded, isFalse);
    });

    test('snooze alias acts as dismiss', () async {
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(browser: browser);
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b');
      expect(service.updateAvailable, isTrue);

      service.snooze();
      expect(service.isDismissed, isTrue);
      expect(service.updateAvailable, isFalse);
    });

    test('checkNow picks up a deploy end to end without auto-reloading', () async {
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
      );
      addTearDown(service.dispose);

      await service.start();
      expect(service.bootBuild, 'a');
      expect(service.updateAvailable, isFalse);

      live = 'b';
      await service.checkNow();

      expect(service.ready, isTrue);
      expect(service.updateAvailable, isTrue);
      expect(browser.reloaded, isFalse);

      service.applyNow();
      expect(browser.reloaded, isTrue);
    });

    test('failed warm still readies: user can still choose to restart', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final browser = FakeUpdateBrowser();
      final service = AppUpdateService(
        browser: browser,
        httpClient: client,
      );
      addTearDown(service.dispose);

      await service.start();
      await service.noteLiveBuild('a');
      await service.noteLiveBuild('b', 'main.dart.js?v=b');

      expect(service.ready, isTrue);
      expect(service.updateAvailable, isTrue);
      expect(browser.reloaded, isFalse);
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
