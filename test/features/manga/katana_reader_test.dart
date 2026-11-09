import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/presentation/katana/chapter_picker_sheet.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';
import 'package:everglow/features/manga/presentation/katana/reader_settings_sheet.dart';
import 'package:everglow/features/manga/presentation/screens/katana_reader_screen.dart';

void main() {
  group('KatanaBookmark models & recommendation tests', () {
    test('round-trips recommendation fields through toFirestore and fromFirestore', () {
      final now = DateTime.now();
      final bookmark = KatanaBookmark(
        slug: 'solo-leveling',
        title: 'Solo Leveling',
        coverUrl: 'https://example.com/cover.jpg',
        addedAt: now,
        lastReadChapterId: 'c150',
        lastReadPage: 12,
        lastReadChapterTitle: 'Chapter 150',
        recommendedBy: 'khentsgdz',
        recommendationNote: 'You will love this manhwa!',
      );

      expect(bookmark.hasProgress, isTrue);
      expect(bookmark.isRecommended, isTrue);

      final data = bookmark.toFirestore();
      expect(data['slug'], equals('solo-leveling'));
      expect(data['recommendedBy'], equals('khentsgdz'));
      expect(data['recommendationNote'], equals('You will love this manhwa!'));

      final reconstructed = KatanaBookmark.fromFirestore(data, 'solo-leveling');
      expect(reconstructed.slug, equals('solo-leveling'));
      expect(reconstructed.recommendedBy, equals('khentsgdz'));
      expect(reconstructed.recommendationNote, equals('You will love this manhwa!'));
      expect(reconstructed.isRecommended, isTrue);
    });

    test('isRecommended is false when recommendedBy is empty', () {
      final bookmark = KatanaBookmark(
        slug: 'frieren',
        title: 'Frieren',
        coverUrl: '',
        addedAt: DateTime.now(),
      );

      expect(bookmark.isRecommended, isFalse);
    });
  });

  testWidgets('desktop wheel bridge scrolls the reader list', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) => scrollReaderWithWheel(event, controller),
          child: ListView(
            controller: controller,
            physics: const NeverScrollableScrollPhysics(),
            children: const [SizedBox(height: 600), SizedBox(height: 600)],
          ),
        ),
      ),
    );

    controller.jumpTo(200);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(ListView)),
        scrollDelta: const Offset(0, -120),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();

    expect(controller.offset, 80);
  });

  test('desktop web keeps mouse wheel on the reader scroller', () {
    expect(
      KatanaReaderScreen.isDesktopWeb(
        isWeb: true,
        platform: TargetPlatform.windows,
      ),
      isTrue,
    );
    expect(
      KatanaReaderScreen.isDesktopWeb(
        isWeb: true,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );
    expect(
      KatanaReaderScreen.isDesktopWeb(
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      KatanaReaderScreen.isDesktopWeb(
        isWeb: false,
        platform: TargetPlatform.windows,
      ),
      isFalse,
    );
  });

  group('Reader settings enum tests', () {
    test('ReaderMode has distinct readable labels', () {
      expect(ReaderMode.webtoon.label, contains('Webtoon'));
      expect(ReaderMode.pagedRTL.label, contains('Manga'));
      expect(ReaderMode.pagedLTR.label, contains('Western'));
    });

    test('ReaderThemeStyle defines appropriate background colors', () {
      expect(ReaderThemeStyle.oled.backgroundColor.toARGB32(), equals(0xFF000000));
      expect(ReaderThemeStyle.sepia.backgroundColor.toARGB32(), equals(0xFF1E1A17));
    });
  });

  group('KatanaReaderScreen initial page tests', () {
    test('defaults initialPage to 1', () {
      const reader = KatanaReaderScreen(
        slug: 'solo-leveling',
        chapterId: 'c1',
        chapters: [],
        mangaTitle: 'Solo Leveling',
      );
      expect(reader.initialPage, equals(1));
    });

    test('accepts custom initialPage for resuming reading', () {
      const reader = KatanaReaderScreen(
        slug: 'solo-leveling',
        chapterId: 'c1',
        chapters: [],
        mangaTitle: 'Solo Leveling',
        initialPage: 42,
      );
      expect(reader.initialPage, equals(42));
    });
  });

  group('paged item mapping', () {
    test('single-page mode maps a page to the item just before it', () {
      expect(pagedItemForPage(1, twoPage: false), 0);
      expect(pagedItemForPage(12, twoPage: false), 11);
    });

    test('two-page mode packs two pages per item', () {
      // The regression: resuming page 12 used to jump to item 11, which
      // shows pages 23-24. It must land on item 5 (pages 11-12).
      expect(pagedItemForPage(12, twoPage: true), 5);
      expect(pagedItemForPage(1, twoPage: true), 0);
      expect(pagedItemForPage(2, twoPage: true), 0);
      expect(pagedItemForPage(3, twoPage: true), 1);
      expect(pagedItemForPage(4, twoPage: true), 1);
    });

    test('the last item matches the PageView item count', () {
      // _buildPagedViewer builds ceil(pages / 2) + 1 items in two-page
      // mode, so the last reachable index is ceil(pages / 2).
      expect(lastPagedItem(10, twoPage: false), 10);
      expect(lastPagedItem(10, twoPage: true), 5);
      expect(lastPagedItem(9, twoPage: true), 5);
      expect(lastPagedItem(1, twoPage: true), 1);
    });
  });

  group('proportionalResumeOffset', () {
    test('splits the extent evenly across the pages', () {
      // 11 pages, target index 5 of 10 gaps -> halfway down the extent.
      expect(proportionalResumeOffset(5, 11, 1000), 500);
      expect(proportionalResumeOffset(0, 11, 1000), 0);
      expect(proportionalResumeOffset(10, 11, 1000), 1000);
    });

    test('never divides by zero on a single-page chapter', () {
      expect(proportionalResumeOffset(0, 1, 500), 0);
      expect(proportionalResumeOffset(0, 0, 500), 0);
    });
  });

  group('Sakura Noir Sanctuary header & chapter range chips', () {
    testWidgets(
      'KatanaSectionHeader hides decorative badge on narrow phones so title fits',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: KatanaSectionHeader(
                  title: 'Currently Reading',
                  badge: 'READING NOOK',
                  trailing: SizedBox(width: 86, height: 24),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Currently Reading'), findsOneWidget);
        expect(find.text('READING NOOK'), findsNothing);

        tester.view.physicalSize = const Size(800, 640);
        await tester.pump();
        expect(find.text('READING NOOK'), findsOneWidget);
      },
    );

    testWidgets(
      'ChapterPickerSheet renders range jump pills when over 50 chapters',
      (tester) async {
        final chapters = List<KatanaChapter>.generate(
          60,
          (i) => KatanaChapter(
            id: 'c${i + 1}',
            num: '${i + 1}',
            title: 'Chapter ${i + 1}',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChapterPickerSheet(
                chapters: chapters,
                currentChapter: chapters.first,
                onChapterSelected: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('All'), findsOneWidget);
        expect(find.text('1–50'), findsOneWidget);
        expect(find.text('51–60'), findsOneWidget);

        await tester.tap(find.text('51–60'));
        await tester.pump();
        expect(find.text('Chapter 60'), findsOneWidget);
        expect(find.text('Chapter 1'), findsNothing);
      },
    );
  });
}
