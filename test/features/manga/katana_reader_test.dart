import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/presentation/katana/reader_settings_sheet.dart';

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
