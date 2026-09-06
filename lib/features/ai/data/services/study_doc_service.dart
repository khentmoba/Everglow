import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Max PDF file size Mochi will open (10 MB keeps memory and payloads sane).
const int kMaxStudyPdfBytes = 10 * 1024 * 1024;

/// Max extracted characters kept per doc. ~3.5k tokens, so the doc fits
/// alongside Mochi's system prompt and recent history.
const int kMaxStudyChars = 15000;

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

/// Wraps the extracted doc text and the user's ask into one chat message.
/// The model needs no special prompt — the brackets say what the text is.
String buildStudyMessage({
  required StudyDoc doc,
  required String userPrompt,
}) {
  final buffer = StringBuffer()
    ..writeln('📄 Study material from "${doc.fileName}":')
    ..writeln(doc.text);
  if (doc.truncated) {
    buffer.writeln('[Material cut here to fit — this is the start of the PDF.]');
  }
  buffer
    ..writeln()
    ..write(userPrompt.trim().isEmpty ? StudyPrompts.summarize : userPrompt.trim());
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
