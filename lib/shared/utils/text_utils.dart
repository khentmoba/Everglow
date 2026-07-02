/// Strip common markdown formatting from text.
String stripMarkdown(String text) {
  return text
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('*', '')
      .replaceAll('_', '')
      .replaceAll('`', '')
      .replaceAll('~~', '')
      .replaceAll('### ', '')
      .replaceAll('## ', '')
      .replaceAll('# ', '');
}

/// Extract media titles from an AI recommendation response.
///
/// Parses numbered/bulleted lists and returns clean title strings.
List<String> extractTitles(String text) {
  final titles = <String>[];
  final lines = text.split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    var cleaned = trimmed.replaceFirst(RegExp(r'^[\d]+[\.\)]\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^[-*]\s+'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^\*\*[\d]+\.?\*\*\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^["""]'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'["""]$'), '');
    cleaned = stripMarkdown(cleaned).trim();

    if (cleaned.length > 5 &&
        cleaned.contains(' ') &&
        cleaned[0] == cleaned[0].toUpperCase() &&
        !cleaned.contains('http') &&
        !cleaned.contains('watch') &&
        !cleaned.contains('recommend')) {
      final parenIdx = cleaned.indexOf(' (');
      if (parenIdx > 0) cleaned = cleaned.substring(0, parenIdx);
      titles.add(cleaned);
    }
  }
  return titles;
}
