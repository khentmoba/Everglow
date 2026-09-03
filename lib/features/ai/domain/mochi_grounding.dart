/// Pure response-grounding helpers for Mochi (Phase 4 validation).
///
/// Mirrors the server-side title check: after the agent loop produces a
/// final reply, quoted/capitalized titles are extracted and verified
/// against TMDB-backed `knownTitles`. Anything left over is a candidate
/// hallucination the loop can self-heal on.
///
/// Pure and dependency-free so `flutter test` can verify the exact
/// behavior without Firestore or a TMDB key.
class MochiGrounding {
  const MochiGrounding();

  /// Titles mentioned in [response]: `"Quoted"` and `**Bold**` segments
  /// of at least 2 characters, de-duplicated case-insensitively while
  /// keeping first-seen order.
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

  /// Case-insensitive substring match in either direction, mirroring the
  /// watchlist title lookup (`titlesMatch` in `functions/mochi_tools.js`).
  bool titlesMatch(String a, String b) {
    final x = a.trim().toLowerCase();
    final y = b.trim().toLowerCase();
    if (x.isEmpty || y.isEmpty) return false;
    return x.contains(y) || y.contains(x);
  }

  /// Titles from [response] with no match in [knownTitles] (e.g. TMDB
  /// results). Empty when the reply names nothing verifiable.
  List<String> findUnknownTitles(String response, List<String> knownTitles) {
    final known = knownTitles.where((t) => t.trim().isNotEmpty).toList();
    return extractTitles(response)
        .where((t) => !known.any((k) => titlesMatch(t, k)))
        .toList();
  }

  /// Whether [response] names at least one title missing from
  /// [knownTitles] — the trigger for one self-healing regeneration round.
  bool hasHallucinatedTitle(String response, List<String> knownTitles) =>
      findUnknownTitles(response, knownTitles).isNotEmpty;
}
