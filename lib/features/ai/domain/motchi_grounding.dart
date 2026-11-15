class MotchiGrounding {
  const MotchiGrounding();

  List<String> extractTitles(String response) {
    final seen = <String>{};
    final titles = <String>[];
    void add(String raw) {
      final title = raw.trim();
      if (title.length < 2) return;
      if (seen.add(title.toLowerCase())) titles.add(title);
    }

    for (final m in RegExp(r'"([^"]{2,})"').allMatches(response)) {
      add(m.group(1)!);
    }
    for (final m in RegExp(r'\*\*([^*]{2,}?)\*\*').allMatches(response)) {
      add(m.group(1)!);
    }
    return titles;
  }

  bool titlesMatch(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return false;
    return x.contains(y) || y.contains(x);
  }

  List<String> findUnknownTitles(String response, List<String> knownTitles) {
    final known = knownTitles.where((t) => t.trim().isNotEmpty).toList();
    return extractTitles(response)
        .where((t) => !known.any((k) => titlesMatch(t, k)))
        .toList();
  }

  bool hasHallucinatedTitle(String response, List<String> knownTitles) =>
      findUnknownTitles(response, knownTitles).isNotEmpty;
}
