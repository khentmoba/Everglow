import 'package:everglow/core/theme/section_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(SectionFonts.resetWarmedGlyphsForTesting);
  tearDown(SectionFonts.resetWarmedGlyphsForTesting);

  testWidgets(
    'warmFallbackGlyphs skips ASCII, deduplicates non-ASCII runes, and resets',
    (tester) async {
      SectionFonts.warmFallbackGlyphs([
        'Plain ASCII title 123',
        '',
      ], force: true);
      expect(SectionFonts.warmedGlyphCountForTesting, 0);

      SectionFonts.warmFallbackGlyphs([
        '「Manga」 ①②',
        '「Repeated」 ①',
      ], force: true);
      expect(SectionFonts.warmedGlyphCountForTesting, 4);

      await tester.pump();
      expect(tester.takeException(), isNull);

      SectionFonts.resetWarmedGlyphsForTesting();
      expect(SectionFonts.warmedGlyphCountForTesting, 0);
    },
  );
}
