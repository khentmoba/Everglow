import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Max PDF file size Mochi will open (10 MB keeps memory and payloads sane).
const int kMaxStudyPdfBytes = 10 * 1024 * 1024;

/// Max sources per study session. Source text itself is uncapped — the
/// whole PDF goes to Mochi every turn.
const int kMaxStudyDocs = 3;

/// A PDF study doc attached to the current Mochi study session.
/// The live session keeps the full text; history stores a snapshot
/// (see trimSourcesForStorage) so giant PDFs still fit Firestore.
class StudyDoc {
  final String fileName;
  final String text;

  /// True only for older history restores (or trimmed history snapshots)
  /// where just the start of the PDF was kept.
  final bool truncated;

  const StudyDoc({
    required this.fileName,
    required this.text,
    required this.truncated,
  });
}

/// Friendly failure for anything the user can fix (too big, no text, ...).
class StudyDocException implements Exception {
  final String message;
  StudyDocException(this.message);

  @override
  String toString() => message;
}

/// Trims [text] to [maxChars], reporting whether anything was cut.
/// Live sessions no longer trim; only history snapshots use this so giant
/// PDFs still fit Firestore (see trimSourcesForStorage).
({String text, bool truncated}) truncateStudyText(String text, int maxChars) {
  final cleaned = text.trim();
  if (cleaned.length <= maxChars) return (text: cleaned, truncated: false);
  return (text: cleaned.substring(0, maxChars).trimRight(), truncated: true);
}

/// Formats attached sources as the grounding block prepended to every
/// study question. Display text never contains this — chat bubbles show
/// the question only, so long PDFs never flood the screen.
String buildSourcesBlock(List<StudyDoc> docs) {
  final buffer = StringBuffer()
    ..writeln('Study sources (${docs.length}): '
        '${docs.map((d) => '"${d.fileName}"').join(', ')}.');
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

/// One-tap study asks used as quick chips while a doc is attached.
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

  /// Plain-text Quiz ask for when the Canvas toggle is OFF — no hidden
  /// block instruction, so Mochi creates no interactive data at all.
  static const quizPlain =
      'Quiz us on this! Ask 5 multiple-choice questions based ONLY on the material above. '
      'Ask them all now with A–D options, wait for our answers, then correct us gently. '
      'Plain text only — no hidden blocks.';

  /// Plain-text Flashcards ask for when the Canvas toggle is OFF.
  static const flashcardsPlain =
      'Make us flashcards from this — show each card as "Front: ..." then "Back: ..." lines, 10 cards max, based ONLY on the material above. '
      'Plain text only — no hidden blocks.';

  /// Chips honoring the Canvas toggle: when OFF, Quiz/Flashcards ask in
  /// plain text so Mochi creates no interactive quiz data at all.
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

/// Picks a single PDF file: its display name plus raw bytes.
/// Returns null when the user cancels.
typedef PickPdfFile = Future<({String name, Uint8List bytes})?> Function();

Future<({String name, Uint8List bytes})?> pickPdfFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  if (file == null) return null; // user cancelled
  final bytes = await file.readAsBytes();
  return (name: file.name, bytes: bytes);
}

/// Picks a PDF and extracts its text. Thin wrapper around file_picker +
/// Syncfusion so the screen stays dumb; pure helpers above hold the rules.
class StudyDocService {
  final PickPdfFile pickFile;

  StudyDocService({PickPdfFile? pickFile}) : pickFile = pickFile ?? pickPdfFile;

  Future<StudyDoc?> pickAndExtract() async {
    final file = await pickFile();
    if (file == null) return null; // user cancelled
    final bytes = file.bytes;
    if (bytes.lengthInBytes > kMaxStudyPdfBytes) {
      throw StudyDocException('That PDF is over 10 MB — try a smaller one.');
    }
    final text = extractPdfText(bytes);
    if (text.trim().isEmpty) {
      throw StudyDocException(
        'Mochi could not find any text in there — it may be scanned photos. Try a text-based PDF.',
      );
    }
    return StudyDoc(fileName: file.name, text: text.trim(), truncated: false);
  }
}

/// Extracts plain text from PDF [bytes]. Throws [StudyDocException] when
/// the file is not a readable PDF.
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
