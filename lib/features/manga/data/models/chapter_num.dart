double chapterNumValue(String raw) => double.tryParse(raw) ?? 0;

String normalizeChapterNum(String raw) {
  if (raw.isEmpty) return '';
  final n = double.tryParse(raw);
  if (n == null) return raw;
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toString();
}

bool chaptersMatch(String a, String b) {
  if (a == b) return true;
  final na = double.tryParse(a);
  final nb = double.tryParse(b);
  if (na != null && nb != null) return na == nb;
  return false;
}
