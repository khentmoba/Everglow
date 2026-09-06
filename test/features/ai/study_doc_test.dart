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

  group('buildStudyMessage', () {
    const doc = StudyDoc(fileName: 'notes.pdf', text: 'photosynthesis', truncated: false);

    test('wraps doc text, name, and prompt', () {
      final msg = buildStudyMessage(doc: doc, userPrompt: 'Quiz us');
      expect(msg, contains('notes.pdf'));
      expect(msg, contains('photosynthesis'));
      expect(msg, contains('Quiz us'));
    });

    test('defaults to summarize when prompt is empty', () {
      final msg = buildStudyMessage(doc: doc, userPrompt: '   ');
      expect(msg, contains(StudyPrompts.summarize));
    });

    test('notes when the material was cut', () {
      const cut = StudyDoc(fileName: 'big.pdf', text: 'start', truncated: true);
      expect(buildStudyMessage(doc: cut, userPrompt: 'hi'), contains('cut here'));
      expect(buildStudyMessage(doc: doc, userPrompt: 'hi'), isNot(contains('cut here')));
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
