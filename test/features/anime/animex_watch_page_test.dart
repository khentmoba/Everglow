import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:everglow/features/anime/data/services/animex_stores.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_controller.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_player.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_tokens.dart';
import 'package:everglow/features/anime/presentation/widgets/animex/animex_watch_page.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnPageFinished(
    void Function(String url) onPageFinished,
  ) async {}

  @override
  Future<void> setOnWebResourceError(
    void Function(WebResourceError error) onWebResourceError,
  ) async {}
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakePlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakePlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakePlatformNavigationDelegate(params);
  }
}

MediaItem _sampleWatchItem() {
  return MediaItem(
    id: 'animex-test-1',
    tmdbId: 0,
    title: 'Vinland Saga',
    mediaType: 'tv',
    posterPath: '',
    backdropPath: '',
    year: '2019',
    status: 'to-watch',
    isAnime: true,
    addedAt: DateTime(2026, 1, 1),
    source: 'jikan',
    currentEpisode: 1,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  Widget buildTestApp(AnimeXController controller) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AnimexStores>.value(
          value: AnimexStores.instance,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AnimeXWatchPage(controller: controller),
        ),
      ),
    );
  }

  testWidgets(
    'AnimeXWatchPage player is constrained on desktop (1920x1080) and does not span full screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      // Find the player box widget.
      final playerFinder = find.byKey(const Key('animex-player-box'));
      expect(playerFinder, findsOneWidget);

      final playerSize = tester.getSize(playerFinder);

      // Verify the player is smaller and does NOT span 1920 or 1536.
      expect(playerSize.width, lessThanOrEqualTo(AnimeXTokens.watchPageMaxWidth));
      expect(playerSize.width, lessThan(1536));
      expect(playerSize.height, lessThanOrEqualTo(AnimeXTokens.playerMaxHeight));

      // With horizontal padding 24 on each side, content width should be 952.
      expect(playerSize.width, closeTo(952.0, 1.0));
      expect(playerSize.height, closeTo(952.0 * 9 / 16, 1.0));

      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'AnimeXWatchPage player scales down cleanly on short height screens',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      final playerFinder = find.byKey(const Key('animex-player-box'));
      expect(playerFinder, findsOneWidget);

      final playerSize = tester.getSize(playerFinder);

      // On 560px viewport height, height cap is (560 - 280) = 280px.
      expect(playerSize.height, lessThanOrEqualTo(280.0));
      // At 16:9, width should be 280 * 16 / 9 ~ 497.8px.
      expect(playerSize.width, closeTo(280.0 * 16 / 9, 2.0));

      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'AnimeXWatchPage player fits inside tablet and mobile screens',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = AnimeXController();
      controller.watchItem = _sampleWatchItem();

      await tester.pumpWidget(buildTestApp(controller));
      await tester.pump();

      final playerFinder = find.byKey(const Key('animex-player-box'));
      expect(playerFinder, findsOneWidget);

      final playerSize = tester.getSize(playerFinder);

      // Width is 768 - 48 = 720
      expect(playerSize.width, closeTo(720.0, 1.0));
      expect(playerSize.height, closeTo(720.0 * 9 / 16, 1.0));

      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
