import 'dart:convert';

/// Study artifacts — the Claude-Artifacts / Gemini-Canvas moment for Study.
///
/// When Mochi answers a "Quiz us" or "Flashcards" ask, the reply carries a
/// hidden machine-readable block (fenced JSON) alongside the warm human
/// text. This file turns that block into tappable data:
///
/// ```quiz-json
/// [{"q":"...","options":["a","b","c","d"],"answer":1,"why":"..."}]
/// ```
/// ```flashcards-json
/// [{"front":"...","back":"..."}]
/// ```
///
/// The fenced blocks are stripped before the markdown bubble renders, so
/// Clair never sees raw JSON — she sees the friendly text plus one big
/// "Try it" button that opens the interactive sheet.
///
/// A lenient fallback also parses plain-markdown quizzes/flashcards (for
/// older history sessions written before the structured prompts), but only
/// when the shape is unambiguous — a summary must never turn into cards.
class QuizQuestion {
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    this.explanation = '',
  });

  bool get hasAnswer => answerIndex >= 0 && answerIndex < options.length;
}

class Flashcard {
  final String front;
  final String back;

  const Flashcard({required this.front, required this.back});
}

/// What an assistant reply contains, after parsing.
class StudyArtifacts {
  final List<QuizQuestion> quiz;
  final List<Flashcard> flashcards;

  const StudyArtifacts({this.quiz = const [], this.flashcards = const []});

  bool get hasQuiz => quiz.isNotEmpty;
  bool get hasFlashcards => flashcards.isNotEmpty;
  bool get isEmpty => !hasQuiz && !hasFlashcards;
}

/// Max items kept per artifact (prompts ask 5 quiz / 10 cards; room to spare).
const int kMaxQuizQuestions = 12;
const int kMaxFlashcards = 20;

/// Parse every artifact in [text]. Never throws — bad blocks are skipped.
StudyArtifacts parseStudyArtifacts(String text) {
  final quiz = <QuizQuestion>[
    ..._parseQuizJsonBlocks(text),
    ..._parseQuizMarkdownFallback(_withoutFencedBlocks(text)),
  ];
  final cards = <Flashcard>[
    ..._parseFlashcardsJsonBlocks(text),
    ..._parseFlashcardsMarkdownFallback(_withoutFencedBlocks(text)),
  ];
  return StudyArtifacts(
    quiz: quiz.take(kMaxQuizQuestions).toList(),
    flashcards: cards.take(kMaxFlashcards).toList(),
  );
}

/// Remove the hidden JSON blocks so the chat bubble never shows raw JSON.
String stripArtifactBlocks(String text) {
  return _withoutFencedBlocks(text).trim();
}

/// Same idea for mid-stream drafts: drop complete blocks plus a trailing
/// unterminated fence, so half-streamed JSON never flashes on screen.
String stripStreamingArtifacts(String draft) {
  final withoutComplete = _withoutFencedBlocks(draft);
  final open = RegExp(
    r'```\s*(quiz-json|flashcards-json)[\s\S]*$',
    caseSensitive: false,
  ).firstMatch(withoutComplete);
  if (open != null) {
    return withoutComplete.substring(0, open.start).trimRight();
  }
  return withoutComplete;
}

// ─── Fenced JSON (primary) ──────────────────────────────────────

final _fencePattern = RegExp(r'```(\w[\w-]*)\s*\n([\s\S]*?)```');

String _withoutFencedBlocks(String text) {
  return text.replaceAllMapped(_fencePattern, (m) {
    final tag = m.group(1)!.toLowerCase();
    if (tag == 'quiz-json' || tag == 'flashcards-json') return '';
    return m.group(0)!;
  });
}

Iterable<String> _fencedBodies(String text, String tag) sync* {
  for (final m in _fencePattern.allMatches(text)) {
    if (m.group(1)!.toLowerCase() != tag) continue;
    final body = m.group(2)!.trim();
    if (body.isNotEmpty) yield body;
  }
}

List<QuizQuestion> _parseQuizJsonBlocks(String text) {
  final out = <QuizQuestion>[];
  for (final body in _fencedBodies(text, 'quiz-json')) {
    try {
      final decoded = jsonDecode(body);
      final list = decoded is List
          ? decoded
          : decoded is Map && decoded['questions'] is List
              ? decoded['questions'] as List
              : const [];
      for (final item in list) {
        final q = _quizFromJson(item);
        if (q != null) out.add(q);
      }
    } catch (_) {
      // One bad block never breaks the reply — skip it.
    }
  }
  return out;
}

QuizQuestion? _quizFromJson(dynamic item) {
  if (item is! Map) return null;
  final question = (item['q'] ?? item['question'] ?? '').toString().trim();
  final rawOptions = item['options'] ?? item['choices'];
  if (question.isEmpty || rawOptions is! List) return null;
  final options = rawOptions
      .map((o) => o.toString().trim())
      .where((o) => o.isNotEmpty)
      .toList();
  if (options.length < 2 || options.length > 5) return null;
  final answer = _answerToIndex(item['answer'], options.length);
  if (answer == null) return null;
  final why = (item['why'] ?? item['explanation'] ?? '').toString().trim();
  return QuizQuestion(
    question: question,
    options: options,
    answerIndex: answer,
    explanation: why,
  );
}

int? _answerToIndex(dynamic answer, int optionCount) {
  if (answer is int) {
    if (answer >= 0 && answer < optionCount) return answer;
    // 1-based number from the model (e.g. 2 means the 2nd option).
    if (answer >= 1 && answer <= optionCount) return answer - 1;
    return null;
  }
  if (answer is String) {
    final t = answer.trim().toUpperCase();
    if (t.length == 1) {
      final idx = t.codeUnitAt(0) - 'A'.codeUnitAt(0);
      if (idx >= 0 && idx < optionCount) return idx;
    }
    final asNum = int.tryParse(t);
    if (asNum != null) {
      // Accept 0-based or 1-based numbers.
      if (asNum >= 0 && asNum < optionCount) return asNum;
      if (asNum >= 1 && asNum <= optionCount) return asNum - 1;
    }
  }
  return null;
}

List<Flashcard> _parseFlashcardsJsonBlocks(String text) {
  final out = <Flashcard>[];
  for (final body in _fencedBodies(text, 'flashcards-json')) {
    try {
      final decoded = jsonDecode(body);
      final list = decoded is List
          ? decoded
          : decoded is Map && decoded['cards'] is List
              ? decoded['cards'] as List
              : const [];
      for (final item in list) {
        final card = _cardFromJson(item);
        if (card != null) out.add(card);
      }
    } catch (_) {
      // Skip bad blocks silently.
    }
  }
  return out;
}

Flashcard? _cardFromJson(dynamic item) {
  if (item is! Map) return null;
  final front = (item['front'] ?? item['q'] ?? item['question'] ?? '')
      .toString()
      .trim();
  final back =
      (item['back'] ?? item['a'] ?? item['answer'] ?? '').toString().trim();
  if (front.isEmpty || back.isEmpty) return null;
  if (front.length > 500 || back.length > 800) return null;
  return Flashcard(front: front, back: back);
}

// ─── Plain-markdown fallback (older sessions) ───────────────────
//
// Only fires on unambiguous shapes AND only when no JSON block of the
// same kind was found — structured output always wins.

List<QuizQuestion> _parseQuizMarkdownFallback(String text) {
  if (_fencedBodies(text, 'quiz-json').isNotEmpty) return const [];
  final lines = text.split('\n');
  final out = <QuizQuestion>[];
  var i = 0;
  while (i < lines.length) {
    final qMatch =
        RegExp(r'^\s*(?:\*{0,2}\s*)?(\d+)[.)]\s+(.{4,}?)\s*\*{0,2}\s*$')
            .firstMatch(lines[i]);
    if (qMatch == null) {
      i++;
      continue;
    }
    final question = _cleanInline(qMatch.group(2)!);
    final options = <String>[];
    var j = i + 1;
    while (j < lines.length && options.length < 5) {
      final opt = RegExp(r'^\s*(?:[-*•]\s*)?([A-E])[.)]\s+(.+?)\s*$')
          .firstMatch(lines[j]);
      if (opt == null) break;
      options.add(_cleanInline(opt.group(2)!));
      j++;
    }
    int answer = -1;
    String why = '';
    if (options.length >= 2 && j < lines.length) {
      final ans = RegExp(
        r'^\s*(?:[-*•]\s*)?(?:\*{0,2}\s*)?(?:answer|correct)\s*[:\-]\s*([A-Ea-e]|\d)\b\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(lines[j]);
      if (ans != null) {
        answer = _answerToIndex(ans.group(1)!, options.length) ?? -1;
        why = _cleanInline(ans.group(2) ?? '');
        j++;
      }
    }
    if (question.isNotEmpty && options.length >= 2 && answer >= 0) {
      out.add(
        QuizQuestion(
          question: question,
          options: options,
          answerIndex: answer,
          explanation: why,
        ),
      );
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

List<Flashcard> _parseFlashcardsMarkdownFallback(String text) {
  if (_fencedBodies(text, 'flashcards-json').isNotEmpty) return const [];
  final lines = [for (final l in text.split('\n')) l.trim()];
  final out = <Flashcard>[];
  var i = 0;
  var explicitHits = 0;
  while (i < lines.length) {
    final front = RegExp(
      r'^(?:Q\s*[:\-]|Front\s*[:\-]|Card\s+\d+\s*[:\-])\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(lines[i]);
    if (front == null) {
      i++;
      continue;
    }
    String? back;
    if (i + 1 < lines.length) {
      back = RegExp(r'^(?:A\s*[:\-]|Back\s*[:\-])\s*(.+)$', caseSensitive: false)
          .firstMatch(lines[i + 1])
          ?.group(1);
    }
    if (back != null && back.trim().isNotEmpty) {
      out.add(
        Flashcard(front: _cleanInline(front.group(1)!), back: _cleanInline(back)),
      );
      explicitHits++;
      i += 2;
    } else {
      i++;
    }
  }
  // Without at least 2 explicit Q/A pairs this is probably prose — bail.
  if (explicitHits < 2) return const [];
  return out;
}

/// Drop light markdown markers so quiz/card text reads clean on the sheet.
String _cleanInline(String s) {
  return s
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
      .trim();
}
