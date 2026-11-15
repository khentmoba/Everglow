class MotchiQuality {
  const MotchiQuality();

  static const Set<String> _thinkingTriggers = {
    'plan',
    'planning',
    'itinerary',
    'decide',
    'decision',
    'help me decide',
    'help us decide',
    'compare',
    'comparison',
    'pros and cons',
    'analyze',
    'analysis',
    'deep dive',
    'anniversary',
    'surprise',
    'relationship',
    'why are we',
  };

  bool shouldAutoThink(String message) {
    final text = message.trim();
    if (text.length < 12) return false;
    if (text.length >= 240) return true;
    final lower = text.toLowerCase();
    if ('?'.allMatches(lower).length >= 2) return true;
    final sentenceCount = '.!?'.allMatches(lower).length;
    if (sentenceCount >= 2 && text.length >= 80) {
      final hasTrigger = _thinkingTriggers.any(
        (word) => lower.contains(word),
      );
      if (hasTrigger) return true;
    }
    if (text.length >= 15) {
      final hasTrigger = _thinkingTriggers.any(
        (word) => RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lower),
      );
      if (hasTrigger) return true;
    }
    return false;
  }
}

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