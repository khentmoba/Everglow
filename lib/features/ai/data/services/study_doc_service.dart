import 'package:flutter/foundation.dart' show Uint8List, compute, kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const int kMaxStudyPdfBytes = 10 * 1024 * 1024;

const int kMaxStudyDocs = 3;

class StudyDoc {
  final String fileName;
  final String text;

  final bool truncated;

  const StudyDoc({
    required this.fileName,
    required this.text,
    required this.truncated,
  });
}

class StudyDocException implements Exception {
  final String message;
  StudyDocException(this.message);

  @override
  String toString() => message;
}

({String text, bool truncated}) truncateStudyText(String text, int maxChars) {
  final cleaned = text.trim();
  if (cleaned.length <= maxChars) return (text: cleaned, truncated: false);
  return (text: cleaned.substring(0, maxChars).trimRight(), truncated: true);
}

String buildSourcesBlock(List<StudyDoc> docs) {
  final buffer = StringBuffer()
    ..writeln(
      'Study sources (${docs.length}): '
      '${docs.map((d) => '"${d.fileName}"').join(', ')}.',
    );
  for (final doc in docs) {
    buffer
      ..writeln('--- ${doc.fileName} ---')
      ..writeln(doc.text);
    if (doc.truncated) {
      buffer.writeln('[Cut here to fit — this is the start of the PDF.]');
    }
  }
  buffer.write('Answer using ONLY these sources.');
  return buffer.toString();
}

abstract final class StudyPrompts {
  static const summarize =
      'Summarize this for us so we can study it — key points first, then details. Keep it warm and simple.';
  static const quiz =
      'Quiz us on this! Ask 5 multiple-choice questions based ONLY on the material above. '
      'Ask them all now with A–D options, wait for our answers, then correct us gently. '
      'After the friendly quiz, append a hidden fenced block named quiz-json with the same questions as JSON: '
      '[{"q":"question","options":["a","b","c","d"],"answer":0,"why":"one-line gentle explanation"}] '
      'where answer is the 0-based index of the correct option. JSON only inside the block, no commentary.';
  static const flashcards =
      'Make us flashcards from this — show each card as "Front: ..." then "Back: ..." lines, 10 cards max, based ONLY on the material above. '
      'After the friendly cards, append a hidden fenced block named flashcards-json with the same cards as JSON: '
      '[{"front":"...","back":"..."}]. JSON only inside the block, no commentary.';
  static const explain =
      'Explain this simply, like we are seeing it for the first time. Use everyday examples.';

  static const List<(String, String)> chips = [
    ('Summarize 📝', summarize),
    ('Quiz us ✍️', quiz),
    ('Flashcards 🃏', flashcards),
    ('Explain simply 💡', explain),
  ];

  static const quizPlain =
      'Quiz us on this! Ask 5 multiple-choice questions based ONLY on the material above. '
      'Ask them all now with A–D options, wait for our answers, then correct us gently. '
      'Plain text only — no hidden blocks.';

  static const flashcardsPlain =
      'Make us flashcards from this — show each card as "Front: ..." then "Back: ..." lines, 10 cards max, based ONLY on the material above. '
      'Plain text only — no hidden blocks.';

  static List<(String, String)> chipsFor({required bool canvasOn}) {
    if (canvasOn) return chips;
    return [
      ('Summarize 📝', summarize),
      ('Quiz us ✍️', quizPlain),
      ('Flashcards 🃏', flashcardsPlain),
      ('Explain simply 💡', explain),
    ];
  }
}

typedef PickPdfFile = Future<({String name, Uint8List bytes})?> Function();

Future<({String name, Uint8List bytes})?> pickPdfFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return (name: file.name, bytes: bytes);
}

class StudyDocService {
  final PickPdfFile pickFile;

  StudyDocService({PickPdfFile? pickFile}) : pickFile = pickFile ?? pickPdfFile;

  Future<StudyDoc?> pickAndExtract() async {
    final file = await pickFile();
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes.lengthInBytes > kMaxStudyPdfBytes) {
      throw StudyDocException('That PDF is over 10 MB — try a smaller one.');
    }
    final text = await extractPdfTextAsync(bytes);
    if (text.trim().isEmpty) {
      throw StudyDocException(
        'Motchi could not find any text in there — it may be scanned photos. Try a text-based PDF.',
      );
    }
    return StudyDoc(fileName: file.name, text: text.trim(), truncated: false);
  }
}

Future<String> extractPdfTextAsync(Uint8List bytes) async {
  if (!kIsWeb) return compute(extractPdfText, bytes);
  await Future<void>.delayed(Duration.zero);
  PdfDocument? document;
  try {
    document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = StringBuffer();
    for (var page = 0; page < document.pages.count; page++) {
      await Future<void>.delayed(Duration.zero);
      text.writeln(
        extractor.extractText(startPageIndex: page, endPageIndex: page),
      );
    }
    return text.toString();
  } catch (_) {
    throw StudyDocException('That file is not a readable PDF.');
  } finally {
    document?.dispose();
  }
}

String extractPdfText(Uint8List bytes) {
  try {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  } catch (_) {
    throw StudyDocException('That file is not a readable PDF.');
  }
}
