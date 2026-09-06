import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Max PDF file size Mochi will open (10 MB keeps memory and payloads sane).
const int kMaxStudyPdfBytes = 10 * 1024 * 1024;

/// Max extracted characters kept per doc. ~3.5k tokens, so the doc fits
/// alongside Mochi's system prompt and recent history.
const int kMaxStudyChars = 15000;

/// Max sources per study session and max source text overall (~7k tokens).
/// Keeps every turn inside the proxy's input budget with room to spare.
const int kMaxStudyDocs = 3;
const int kMaxStudyTotalChars = 30000;

/// A PDF study doc attached to the current Mochi chat only.
/// Nothing is saved — a new chat drops it.
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

/// Friendly failure for anything the user can fix (too big, no text, ...).
class StudyDocException implements Exception {
  final String message;
  StudyDocException(this.message);

  @override
  String toString() => message;
}

/// Trims [text] to [maxChars], reporting whether anything was cut.
({String text, bool truncated}) truncateStudyText(String text, int maxChars) {
  final cleaned = text.trim();
  if (cleaned.length <= maxChars) return (text: cleaned, truncated: false);
  return (text: cleaned.substring(0, maxChars).trimRight(), truncated: true);
}

/// Total source characters currently attached.
int studyTotalChars(Iterable<StudyDoc> docs) =>
    docs.fold(0, (sum, doc) => sum + doc.text.length);

/// Trims [candidate] to fit the session's shared budget.
/// Throws [StudyDocException] when the shelf is too full to be useful.
StudyDoc fitStudyDoc(StudyDoc candidate, List<StudyDoc> current) {
  final room = kMaxStudyTotalChars - studyTotalChars(current);
  if (room < 1000) {
    throw StudyDocException('Sources are full — remove one first.');
  }
  if (candidate.text.length <= room) return candidate;
  final cut = truncateStudyText(candidate.text, room);
  return StudyDoc(
    fileName: candidate.fileName,
    text: cut.text,
    truncated: true,
  );
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
      'Quiz us on this! Ask 5 multiple-choice questions based ONLY on the material above. Ask them all now, wait for our answers, then correct us gently.';
  static const flashcards =
      'Make us flashcards from this — one question line followed by its answer line, 10 cards max, based ONLY on the material above.';
  static const explain =
      'Explain this simply, like we are seeing it for the first time. Use everyday examples.';

  static const List<(String, String)> chips = [
    ('Summarize 📝', summarize),
    ('Quiz us ✍️', quiz),
    ('Flashcards 🃏', flashcards),
    ('Explain simply 💡', explain),
  ];
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
    final cut = truncateStudyText(text, kMaxStudyChars);
    return StudyDoc(fileName: file.name, text: cut.text, truncated: cut.truncated);
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
