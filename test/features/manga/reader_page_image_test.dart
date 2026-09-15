import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/manga/presentation/widgets/reader_page_image.dart';

/// Cache backend that fails every load at once, so the retry path runs
/// without real network or disk I/O (the default manager needs
/// path_provider, which has no test implementation).
class _FailingCacheManager extends CacheManager {
  _FailingCacheManager() : super(Config('reader-page-image-test'));

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    return Stream<FileResponse>.error(Exception('network down'));
  }
}

Widget _page({
  void Function()? onError,
  Widget? secondaryAction,
  Duration firstRetryDelay = const Duration(milliseconds: 50),
  int maxAutoRetries = 2,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ReaderPageImage(
        imageUrl: 'https://example.com/page-7.jpg',
        pageNumber: 7,
        slotColor: const Color(0xFF14141C),
        accentColor: Colors.pink,
        mutedColor: Colors.white38,
        maxAutoRetries: maxAutoRetries,
        firstRetryDelay: firstRetryDelay,
        cacheManager: _FailingCacheManager(),
        onError: onError,
        secondaryAction: secondaryAction,
      ),
    ),
  );
}

void main() {
  /// Steps past every backoff (50 + 100 + 200ms by default) while
  /// letting each async failure propagate before the next timer.
  Future<void> pumpToExhaustion(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('ReaderPageImage', () {
    testWidgets('shows the page number while loading', (tester) async {
      await tester.pumpWidget(_page());

      expect(find.text('Page 7'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('retries by itself, then shows a per-page retry slot', (
      tester,
    ) async {
      await tester.pumpWidget(_page());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // First failure schedules a silent retry — never a black gap.
      expect(find.text('Retrying page 7…'), findsOneWidget);
      expect(find.text('Page 7 failed to load'), findsNothing);

      // Past every backoff: the error slot with a per-page retry.
      await pumpToExhaustion(tester);
      expect(find.text('Page 7 failed to load'), findsOneWidget);
      expect(find.text('Tap to retry'), findsOneWidget);
    });

    testWidgets('notifies the parent on failure for fallback URLs', (
      tester,
    ) async {
      var errors = 0;
      await tester.pumpWidget(_page(onError: () => errors++));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(errors, greaterThan(0));
    });

    testWidgets('tap-to-retry touches only the page, without crashing', (
      tester,
    ) async {
      await tester.pumpWidget(_page());
      await pumpToExhaustion(tester);
      expect(find.text('Page 7 failed to load'), findsOneWidget);

      await tester.tap(find.text('Tap to retry'));
      await tester.pump();

      // Retry resets the budget: the page goes back to loading /
      // retrying instead of staying stuck on the error.
      expect(
        find.text('Page 7 failed to load'),
        findsNothing,
      );
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );
    });

    testWidgets('shows the secondary action in the error slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        _page(secondaryAction: const Text('Try another server')),
      );
      await pumpToExhaustion(tester);

      expect(find.text('Page 7 failed to load'), findsOneWidget);
      expect(find.text('Try another server'), findsOneWidget);
    });

    testWidgets('web implementation uses gapless Image.network', (
      tester,
    ) async {
      ReaderPageImage.debugUseWebImplementation = true;
      addTearDown(() => ReaderPageImage.debugUseWebImplementation = null);

      await tester.pumpWidget(_page());

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).gaplessPlayback,
        isTrue,
      );
    });

    testWidgets('precachePage ignores empty urls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('home'))),
      );
      final context = tester.element(find.text('home'));
      await ReaderPageImage.precachePage(context, '');
      expect(find.text('home'), findsOneWidget);
    });
  });
}
