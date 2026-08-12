import 'dart:math';

import 'memory_fact.dart';

/// Scores facts against a free-text query so Mochi can pull the most
/// relevant handful from long-term memory instead of dumping the whole
/// book into every prompt.
class MemoryRetriever {
  const MemoryRetriever();

  List<MemoryFact> rank(
    List<MemoryFact> facts, {
    String query = '',
    DateTime? now,
    int max = 30,
  }) {
    final current = now ?? DateTime.now();
    final tokens = _tokens(query);
    final sorted = facts.toList()
      ..sort((a, b) {
        final scoreA = _score(a, tokens, current, query);
        final scoreB = _score(b, tokens, current, query);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        return b.fact.compareTo(a.fact);
      });
    if (max <= 0) return sorted;
    return sorted.take(max).toList();
  }

  double score(MemoryFact fact, String query, {DateTime? now}) {
    return _score(fact, _tokens(query), now ?? DateTime.now(), query);
  }

  double _score(
    MemoryFact fact,
    Set<String> tokens,
    DateTime now,
    String query,
  ) {
    var score = fact.confidence.clamp(0.1, 1.0);
    if (fact.pinned) score += 2.0;

    final createdAt = fact.createdAt;
    if (createdAt != null) {
      final ageDays = now.difference(createdAt).inDays;
      if (ageDays >= 0 && ageDays <= 30) score += 1.0;
    }
    if (fact.isOnThisDay(now)) score += 3.0;

    if (tokens.isEmpty) return score;

    final factText = '${fact.fact} ${fact.subject ?? ''} '
        '${fact.relation ?? ''} ${fact.object ?? ''} ${fact.category}'
            .toLowerCase();
    for (final token in tokens) {
      if (factText.contains(token)) score += 1.5;
    }

    final subject = fact.subject?.toLowerCase() ?? '';
    final object = fact.object?.toLowerCase() ?? '';
    for (final token in tokens) {
      if (subject.contains(token) || object.contains(token)) score += 2.0;
    }

    final phrase = query.toLowerCase();
    if (fact.fact.toLowerCase().contains(phrase) && phrase.length >= 4) {
      score += 3.0;
    }
    return score;
  }

  Set<String> _tokens(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3)
        .toSet();
  }
}

/// A multiple-choice question generated from real remembered facts.
class MemoryTriviaQuestion {
  final String question;
  final List<String> choices;
  final int answerIndex;
  final String explanation;

  const MemoryTriviaQuestion({
    required this.question,
    required this.choices,
    required this.answerIndex,
    required this.explanation,
  });

  bool isCorrect(int index) => index == answerIndex;
}

/// Turns Mochi's memory into a couple game. Questions blank out the
/// object of a structured memory and use other objects as distractors,
/// so every answer is grounded in a real fact.
class MemoryTriviaGenerator {
  final Random? _random;

  const MemoryTriviaGenerator() : _random = null;

  List<MemoryTriviaQuestion> generate(
    List<MemoryFact> facts, {
    int count = 5,
    Random? random,
  }) {
    final rng = random ?? _random ?? Random();
    final candidates = facts.where((f) {
      final object = f.object;
      final subject = f.subject ?? f.subjectLabel;
      return object != null && object.trim().isNotEmpty && subject.isNotEmpty;
    }).toList();

    candidates.shuffle(rng);
    final selected = candidates.take(count).toList();
    final distractorPool = <String>{
      ...candidates.map((f) => f.object ?? '').where((o) => o.isNotEmpty),
      ...candidates.map((f) => f.subjectLabel).where((s) => s.isNotEmpty),
    };

    return selected.map((fact) {
      final subject = fact.subject ?? fact.subjectLabel;
      final object = fact.object!.trim();
      final question = '${subject.trim()} ${fact.relation ?? ''} _____'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final choices = <String>[object];
      final pool = distractorPool.toList()..remove(object);
      pool.shuffle(rng);
      for (final candidate in pool) {
        if (choices.length >= 4) break;
        if (!choices.contains(candidate)) choices.add(candidate);
      }
      choices.shuffle(rng);
      return MemoryTriviaQuestion(
        question: question,
        choices: choices,
        answerIndex: choices.indexOf(object),
        explanation: fact.fact,
      );
    }).toList();
  }
}

/// A small, explainable pattern found in Everglow data. Kept pure so
/// tests can verify the exact insights without Firestore.
class RelationshipInsight {
  final String title;
  final String detail;
  final String category;

  const RelationshipInsight({
    required this.title,
    required this.detail,
    required this.category,
  });
}

class RelationshipInsights {
  const RelationshipInsights();

  List<RelationshipInsight> compute({
    required List<String> moods,
    required List<String> activities,
  }) {
    final insights = <RelationshipInsight>[];

    if (moods.isNotEmpty) {
      final counts = <String, int>{};
      for (final mood in moods) {
        final key = mood.trim().toLowerCase();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (counts.isNotEmpty) {
        final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
        insights.add(RelationshipInsight(
          title: 'Mood signal',
          detail: '"${top.key}" shows up most often in recent check-ins.',
          category: 'mood',
        ));
      }
    }

    if (activities.isNotEmpty) {
      final categories = <String, int>{};
      for (final activity in activities) {
        final lower = activity.toLowerCase();
        if (lower.contains('movie') ||
            lower.contains('watch') ||
            lower.contains('anime')) {
          categories['movie night'] = (categories['movie night'] ?? 0) + 1;
        } else if (lower.contains('game') ||
            lower.contains('valorant') ||
            lower.contains('mobile legends')) {
          categories['gaming'] = (categories['gaming'] ?? 0) + 1;
        } else if (lower.contains('food') ||
            lower.contains('eat') ||
            lower.contains('cook')) {
          categories['food'] = (categories['food'] ?? 0) + 1;
        } else if (lower.contains('date')) {
          categories['date'] = (categories['date'] ?? 0) + 1;
        }
      }
      if (categories.isNotEmpty) {
        final top = categories.entries
            .reduce((a, b) => a.value >= b.value ? a : b);
        insights.add(RelationshipInsight(
          title: 'Shared rhythm',
          detail: 'Recent activity leans toward ${top.key}.',
          category: 'activity',
        ));
      }
    }

    return insights;
  }
}
