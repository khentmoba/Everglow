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

/// A runnable mini-app from Mochi — a game, a page, a tool — as one
/// self-contained HTML file. Rendered in a sandboxed preview (scripts run,
/// but the frame can't touch the app or the network identity).
class HtmlArtifact {
  final String title;
  final String html;

  const HtmlArtifact({required this.title, required this.html});
}

/// What an assistant reply contains, after parsing.
class StudyArtifacts {
  final List<QuizQuestion> quiz;
  final List<Flashcard> flashcards;
  final List<HtmlArtifact> html;

  const StudyArtifacts({
    this.quiz = const [],
    this.flashcards = const [],
    this.html = const [],
  });

  bool get hasQuiz => quiz.isNotEmpty;
  bool get hasFlashcards => flashcards.isNotEmpty;
  bool get hasHtml => html.isNotEmpty;
  bool get isEmpty => !hasQuiz && !hasFlashcards && !hasHtml;
}

/// Max items kept per artifact (prompts ask 5 quiz / 10 cards; room to spare).
const int kMaxQuizQuestions = 12;
const int kMaxFlashcards = 20;

/// Max HTML kept per app block (~30KB, matching the server prompt cap).
/// Oversize blocks are dropped so a runaway reply can't flood the chat.
const int kMaxHtmlChars = 30000;
const int kMaxHtmlArtifacts = 3;

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
    html: _parseHtmlArtifactBlocks(
      text,
    ).take(kMaxHtmlArtifacts).toList(),
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
    r'```\s*(quiz[\s_-]*json|quiz|flashcards?[\s_-]*json|flashcards?|html[\s_-]*artifacts?|html)[\s\S]*$',
    caseSensitive: false,
  ).firstMatch(withoutComplete);
  if (open != null) {
    return withoutComplete.substring(0, open.start).trimRight();
  }
  return withoutComplete;
}

// ─── Fenced JSON (primary) ──────────────────────────────────────

// Tolerant fence: tag may have extra spaces and the body may start on the
// same line (` ```quiz-json [...]``` ). The model doesn't always emit the
// exact fence shape, so accept close variants — unknown tags (e.g. dart)
// are still left alone by [_withoutFencedBlocks].
final _fencePattern = RegExp(r'```[ \t]*([\w-]+)[ \t]*\n?([\s\S]*?)```');

/// Canonical artifact tags. The model sometimes emits `quiz_json`,
/// `quizjson`, `quiz`, or plain `html` — treat those as the same block.
String _normTag(String tag) {
  final t = tag.toLowerCase().replaceAll('_', '-');
  if (t == 'quiz-json' || t == 'quizjson' || t == 'quiz') return 'quiz-json';
  if (t == 'flashcards-json' ||
      t == 'flashcardsjson' ||
      t == 'flashcards' ||
      t == 'flash-cards-json' ||
      t == 'flashcard-json' ||
      t == 'flashcard') {
    return 'flashcards-json';
  }
  if (t == 'html-artifact' ||
      t == 'htmlartifact' ||
      t == 'html-artifacts' ||
      t == 'html') {
    return 'html-artifact';
  }
  return t;
}

String _withoutFencedBlocks(String text) {
  return text.replaceAllMapped(_fencePattern, (m) {
    if (_normTag(m.group(1)!) == 'quiz-json' ||
        _normTag(m.group(1)!) == 'flashcards-json' ||
        _normTag(m.group(1)!) == 'html-artifact') {
      return '';
    }
    return m.group(0)!;
  });
}

Iterable<String> _fencedBodies(String text, String tag) sync* {
  for (final m in _fencePattern.allMatches(text)) {
    if (_normTag(m.group(1)!) != tag) continue;
    final body = m.group(2)!.trim();
    if (body.isNotEmpty) yield body;
  }
}

/// Decode a JSON list leniently. The model sometimes wraps the array in
/// prose ("Here is the JSON: [...] hope it helps!"), adds trailing commas,
/// or emits one object per line — a strict single jsonDecode would drop
/// the whole block and the chat would fall back to plain text.
List _decodeJsonList(String body) {
  // 1. Strict decode first (fast path for well-formed blocks).
  try {
    final decoded = jsonDecode(body);
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in const ['questions', 'cards', 'items', 'data']) {
        if (decoded[key] is List) return decoded[key] as List;
      }
    }
  } catch (_) {
    // Fall through to lenient extraction.
  }
  // 2. Extract the outermost [...] (or {...}) span, dropping surrounding prose.
  final arraySpan = _outerSpan(body, '[', ']');
  if (arraySpan != null) {
    try {
      final decoded = jsonDecode(_stripTrailingCommas(arraySpan));
      if (decoded is List) return decoded;
    } catch (_) {
      // Fall through to per-object scan.
    }
    // 3. Last resort: parse each {...} object inside the span individually
    // so one bad entry can't sink the whole quiz.
    final items = <dynamic>[];
    for (final span in _objectSpans(arraySpan)) {
      try {
        items.add(jsonDecode(_stripTrailingCommas(span)));
      } catch (_) {
        // Skip the bad entry, keep the rest.
      }
    }
    if (items.isNotEmpty) return items;
  }
  // 4. NDJSON: one JSON object per line, no enclosing array.
  final lines = <dynamic>[];
  for (final line in body.split('\n')) {
    final t = line.trim();
    if (!t.startsWith('{') || !t.endsWith('}')) continue;
    try {
      lines.add(jsonDecode(_stripTrailingCommas(t)));
    } catch (_) {
      // Skip bad lines.
    }
  }
  return lines;
}

/// Outermost balanced [open..close] span in [s], or null when unbalanced.
String? _outerSpan(String s, String open, String close) {
  final start = s.indexOf(open);
  if (start == -1) return null;
  var depth = 0;
  var inStr = false;
  var escape = false;
  for (var i = start; i < s.length; i++) {
    final c = s[i];
    if (inStr) {
      if (escape) {
        escape = false;
      } else if (c == '\\') {
        escape = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
    } else if (c == open) {
      depth++;
    } else if (c == close) {
      depth--;
      if (depth == 0) return s.substring(start, i + 1);
    }
  }
  return null;
}

/// Every top-level {...} object span inside [arraySpan].
Iterable<String> _objectSpans(String arraySpan) sync* {
  var depth = 0;
  var start = -1;
  var inStr = false;
  var escape = false;
  for (var i = 0; i < arraySpan.length; i++) {
    final c = arraySpan[i];
    if (inStr) {
      if (escape) {
        escape = false;
      } else if (c == '\\') {
        escape = true;
      } else if (c == '"') {
        inStr = false;
      }
      continue;
    }
    if (c == '"') {
      inStr = true;
    } else if (c == '{') {
      if (depth == 0) start = i;
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0 && start != -1) {
        yield arraySpan.substring(start, i + 1);
        start = -1;
      }
    }
  }
}

String _stripTrailingCommas(String s) {
  return s.replaceAllMapped(
    RegExp(r',(\s*[}\]])'),
    (m) => m.group(1)!,
  );
}

List<QuizQuestion> _parseQuizJsonBlocks(String text) {
  final out = <QuizQuestion>[];
  for (final body in _fencedBodies(text, 'quiz-json')) {
    try {
      for (final item in _decodeJsonList(body)) {
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
  if (options.length < 2 || options.length > 6) return null;
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
      for (final item in _decodeJsonList(body)) {
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

// ─── HTML apps (preview canvas) ───────────────────────────────

List<HtmlArtifact> _parseHtmlArtifactBlocks(String text) {
  final out = <HtmlArtifact>[];
  for (final body in _fencedBodies(text, 'html-artifact')) {
    final html = body.trim();
    // Stay inside the size cap so one wild reply can't flood the chat
    // or the saved conversation.
    if (html.length < 20 || html.length > kMaxHtmlChars) continue;
    final lower = html.toLowerCase();
    final isFullPage =
        lower.contains('<html') || lower.contains('<!doctype');
    // Accept fragments too (a bare `style`/`div`/`script` game): the model
    // doesn't always emit a full document, so wrap fragments into one.
    // Anything without at least one HTML tag is prose, not an app.
    final hasTag = RegExp(r'<[a-z][a-z0-9-]*(\s[^<>]*)?>', caseSensitive: false)
        .hasMatch(html);
    if (!isFullPage && !hasTag) continue;
    out.add(
      HtmlArtifact(
        title: _htmlTitle(html),
        html: isFullPage ? html : _wrapHtmlFragment(html),
      ),
    );
  }
  return out;
}

/// Wrap a bare HTML fragment (no `html` wrapper) into a runnable page so
/// the sandboxed preview can run it as-is.
String _wrapHtmlFragment(String fragment) {
  final title = _htmlTitle(fragment);
  final safeTitle = title == 'Preview' ? 'Mochi Canvas' : title;
  return '<!DOCTYPE html><html><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<title>${_escapeHtml(safeTitle)}</title>'
      '<style>body{margin:0;padding:16px;font-family:system-ui,-apple-system,'
      'sans-serif;background:#fff;color:#111}*{box-sizing:border-box}</style>'
      '</head><body>$fragment</body></html>';
}

String _escapeHtml(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Title for the Preview button: <title> first, then an optional
/// <!-- title: ... --> note, else a plain fallback.
String _htmlTitle(String html) {
  final titleTag = RegExp(
    r'<title\s*>(.*?)</title\s*>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html)?.group(1)?.trim();
  if (titleTag != null && titleTag.isNotEmpty) {
    return titleTag.length > 80 ? '${titleTag.substring(0, 80)}…' : titleTag;
  }
  final comment = RegExp(
    r'<!--\s*title\s*:(.*?)-->',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html)?.group(1)?.trim();
  if (comment != null && comment.isNotEmpty) {
    return comment.length > 80 ? '${comment.substring(0, 80)}…' : comment;
  }
  return 'Preview';
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
    while (j < lines.length && options.length < 6) {
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
