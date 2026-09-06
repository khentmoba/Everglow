import 'dart:typed_data';

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

  group('study shelf', () {
    const a = StudyDoc(fileName: 'a.pdf', text: 'aaa', truncated: false);
    const b = StudyDoc(fileName: 'b.pdf', text: 'bb', truncated: false);

    test('totals source characters', () {
      expect(studyTotalChars([a, b]), 5);
      expect(studyTotalChars(const []), 0);
    });

    test('keeps docs that fit the budget', () {
      expect(fitStudyDoc(a, [b]).text, 'aaa');
    });

    test('trims a doc to the remaining room', () {
      final full = StudyDoc(
        fileName: 'big.pdf',
        text: 'x' * kMaxStudyTotalChars,
        truncated: false,
      );
      final fitted = fitStudyDoc(full, [a]);
      expect(fitted.text.length, kMaxStudyTotalChars - 3);
      expect(fitted.truncated, isTrue);
    });

    test('refuses when the shelf is full', () {
      final full = StudyDoc(
        fileName: 'full.pdf',
        text: 'x' * (kMaxStudyTotalChars - 500),
        truncated: false,
      );
      expect(
        () => fitStudyDoc(a, [full]),
        throwsA(isA<StudyDocException>()),
      );
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
