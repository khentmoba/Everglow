/// Heuristics that decide when Mochi should spend the extra reasoning
/// tokens on a deep-thinking pass instead of replying on the fast path.
///
/// Pure and deterministic so the behavior is unit-testable and stable
/// across client releases.
class MochiQuality {
  const MochiQuality();

  static const Set<String> _thinkingTriggers = {
    'plan',
    'planning',
    'decide',
    'decision',
    'compare',
    'why',
    'how',
    'explain',
    'think',
    'recommend',
    'suggest',
    'both',
    'us',
    'we',
    'date',
    'trip',
    'help',
    'relationship',
    'anniversary',
    'surprise',
  };

  /// A message gets deep thinking when it is genuinely complex: long,
  /// asks for analysis or planning, or touches both partners.
  bool shouldAutoThink(String message) {
    final text = message.trim();
    if (text.length >= 90) return true;
    if (text.length < 12) return false;

    final lower = text.toLowerCase();
    final hasTrigger = _thinkingTriggers.any(
      (word) => RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lower),
    );
    if (hasTrigger) return true;

    // Multiple question marks usually means a layered request.
    return '?'.allMatches(lower).length >= 2;
  }
}

/// Server-side context blocks are cheap to fetch but expensive to feed
/// a model. [selectContextBlocks] keeps the most relevant blocks for
/// the current question and always preserves the proactive digest.
class ContextSelector {
  const ContextSelector();

  List<MapEntry<String, String>> select(
    Map<String, String> blocks,
    String query, {
    int maxBlocks = 6,
    String alwaysKeep = 'proactive',
  }) {
    if (blocks.isEmpty) return const [];
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3)
        .toSet();

    final entries = blocks.entries.toList();
    if (tokens.isEmpty) {
      return entries.take(maxBlocks).toList();
    }

    entries.sort((a, b) {
      final scoreA = _scoreBlock(a.key, a.value, tokens);
      final scoreB = _scoreBlock(b.key, b.value, tokens);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return a.key.compareTo(b.key);
    });

    final result = <MapEntry<String, String>>[];
    final always = entries.where((e) => e.key == alwaysKeep).toList();
    final rest = entries.where((e) => e.key != alwaysKeep).toList();
    result.addAll(always);
    result.addAll(rest);
    return result.take(maxBlocks).toList();
  }

  double _scoreBlock(String key, String value, Set<String> tokens) {
    final haystack = '$key $value'.toLowerCase();
    var score = 0.0;
    for (final token in tokens) {
      if (haystack.contains(token)) score += 1.5;
    }
    return score;
  }
}
