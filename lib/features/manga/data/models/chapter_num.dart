// Shared chapter-number helpers for every manga source.
//
// Scanlation sites format the same chapter many ways ("1", "1.0", "001").
// These keep sorting, matching, and dedupe consistent no matter which
// source a title came from.

/// Numeric value of a chapter string for sorting. Non-numeric → 0.
double chapterNumValue(String raw) => double.tryParse(raw) ?? 0;

/// Normalize a chapter number so "1", "1.0", "001" all map to "1".
/// Returns empty string if [raw] is empty, or [raw] itself when it is
/// not numeric (e.g. "Special").
String normalizeChapterNum(String raw) {
  if (raw.isEmpty) return '';
  final n = double.tryParse(raw);
  if (n == null) return raw;
  // Use integer representation when there's no fractional part
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toString();
}

/// True when two chapter strings name the same chapter, accounting for
/// formatting differences (e.g. "1" vs "1.0" vs "001").
bool chaptersMatch(String a, String b) {
  if (a == b) return true;
  final na = double.tryParse(a);
  final nb = double.tryParse(b);
  if (na != null && nb != null) return na == nb;
  return false;
}
