import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
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
}
