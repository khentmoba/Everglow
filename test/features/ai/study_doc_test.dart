import 'dart:typed_data';
import 'dart:ui';

import 'package:everglow/features/ai/data/services/study_doc_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('truncateStudyText', () {
    test('keeps short text as-is', () {
      final result = truncateStudyText('  hello  ', 100);
      expect(result.text, 'hello');
      expect(result.truncated, isFalse);
    });

    test('cuts long text and flags it', () {
      final result = truncateStudyText('abcdefghij', 5);
      expect(result.text, 'abcde');
      expect(result.truncated, isTrue);
    });
  });

  group('uncapped sources', () {
    test('grounds answers on the full text with no cut note', () {
      final doc = StudyDoc(
        fileName: 'big.pdf',
        text: 'x' * 100000,
        truncated: false,
      );
      final block = buildSourcesBlock([doc]);
      expect(block, contains('x' * 1000));
      expect(block, isNot(contains('Cut here')));
    });

    test('keeps a whole PDF past the old 15k cut', () async {
      final document = PdfDocument();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      for (var p = 0; p < 10; p++) {
        final page = document.pages.add();
        for (var line = 0; line < 40; line++) {
          page.graphics.drawString(
            'Mochi uncapped p$p l$line ${'z' * 50}',
            font,
            bounds: Rect.fromLTWH(0, line * 20, 500, 20),
          );
        }
      }
      final bytes = Uint8List.fromList(await document.save());
      document.dispose();

      final service = StudyDocService(
        pickFile: () async => (name: 'big.pdf', bytes: bytes),
      );
      final doc = await service.pickAndExtract();
      expect(doc, isNotNull);
      expect(doc!.truncated, isFalse);
      expect(doc.text.length, greaterThan(15000));
    });
  });

  group('buildSourcesBlock', () {
    const doc = StudyDoc(fileName: 'notes.pdf', text: 'photosynthesis', truncated: false);

    test('names every source and grounds the answer', () {
      final block = buildSourcesBlock([doc]);
      expect(block, contains('notes.pdf'));
      expect(block, contains('photosynthesis'));
      expect(block, contains('ONLY these sources'));
    });

    test('notes when a source was cut', () {
      const cut = StudyDoc(fileName: 'big.pdf', text: 'start', truncated: true);
      expect(buildSourcesBlock([cut]), contains('Cut here'));
      expect(buildSourcesBlock([doc]), isNot(contains('Cut here')));
    });
  });

  group('StudyPrompts', () {
    test('chips all carry a real prompt', () {
      expect(StudyPrompts.chips, hasLength(4));
      for (final chip in StudyPrompts.chips) {
        expect(chip.$1, isNotEmpty);
        expect(chip.$2, isNotEmpty);
      }
    });
  });

  group('extractPdfText', () {
    test('round-trips text through a generated PDF', () async {
      final document = PdfDocument();
      document.pages
          .add()
          .graphics
          .drawString('Mochi study test', PdfStandardFont(PdfFontFamily.helvetica, 12));
      final bytes = Uint8List.fromList(await document.save());
      document.dispose();

      expect(extractPdfText(bytes), contains('Mochi study test'));
    });

    test('rejects garbage bytes with a friendly error', () {
      expect(
        () => extractPdfText(Uint8List.fromList([0, 1, 2, 3, 4])),
        throwsA(isA<StudyDocException>()),
      );
    });
  });
}
