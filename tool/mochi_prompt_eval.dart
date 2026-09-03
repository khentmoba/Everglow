// ignore_for_file: avoid_print
// Offline Mochi routing eval — zero LLM cost.
//
// Scores a keyword router (mirroring the pinned routing policy in
// `functions/mochi_prompt_v1.md`) against `functions/test/mochi_eval_cases.json`.
// Use it as the tuning baseline: when the persona or tool set changes,
// add/adjust cases here and in the JSON, then compare scores across runs.
//
// Run from repo root: `dart tool/mochi_prompt_eval.dart`
// Advisory only (always exits 0) — the hard CI check is `node eval_gate.js`.
// Upgrade path: swap [_route] for a live `proxyAIv2` call (needs
// AGNES_API_KEY) and score tool-choice + groundedness with an LLM judge.
import 'dart:convert';
import 'dart:io';

typedef _Rule = ({String tool, List<List<String>> anyGroups});

/// Ordered rules: first rule whose EVERY group has ANY keyword wins.
/// Mirrors "prefer custom tools; web_search only for current/external info;
// no tools for plain chat" from the pinned prompt.
const List<_Rule> _rules = [
  (tool: 'add_to_watchlist', anyGroups: [
    ['watchlist'],
    ['add', 'save', 'put']
  ]),
  (tool: 'mark_watchlist_item_watched', anyGroups: [
    ['watched', 'finished watching', 'mark']
  ]),
  (tool: 'get_watchlist', anyGroups: [
    ['watchlist']
  ]),
  (tool: 'update_book_progress', anyGroups: [
    ['percent', 'through', 'finished chapter', 'progress']
  ]),
  (tool: 'add_book_to_our_books', anyGroups: [
    ['our books', 'reading list'],
    ['add']
  ]),
  (tool: 'search_books', anyGroups: [
    ['book']
  ]),
  (tool: 'search_anime', anyGroups: [
    ['anime']
  ]),
  (tool: 'search_movies', anyGroups: [
    ['movie', 'film', 'show to watch', 'real movie']
  ]),
  (tool: 'save_to_starlight_jar', anyGroups: [
    ['save'],
    ['note', 'jar', 'starlight', 'this']
  ]),
  (tool: 'read_starlight_jar', anyGroups: [
    ['starlight'],
    ['read', 'show', 'revisit']
  ]),
  (tool: 'set_mood', anyGroups: [
    ['feeling', 'i feel', 'my mood', 'i am happy', 'i am sad', 'i am tired']
  ]),
  (tool: 'create_reminder', anyGroups: [
    ['remind']
  ]),
  (tool: 'plan_date_night', anyGroups: [
    ['plan a'],
    ['date night', 'date']
  ]),
  (tool: 'get_date_ideas', anyGroups: [
    ['date idea']
  ]),
  (tool: 'get_weather', anyGroups: [
    ['weather']
  ]),
  (tool: 'read_chat_messages', anyGroups: [
    ['chat'],
    ['said', 'say in', 'what did']
  ]),
  (tool: 'send_sanctuary_message', anyGroups: [
    ['sanctuary', 'tell clair', 'tell khent'],
    ['tell', 'send', 'relay']
  ]),
  (tool: 'remember_fact', anyGroups: [
    ['remember that', 'remember this']
  ]),
  (tool: 'read_memories', anyGroups: [
    ['remember about', 'what do you remember']
  ]),
  (tool: 'get_memory_trivia', anyGroups: [
    ['quiz']
  ]),
  (tool: 'get_relationship_insights', anyGroups: [
    ['pattern']
  ]),
  (tool: 'get_today_recap', anyGroups: [
    ['recap']
  ]),
  (tool: 'get_xp_stats', anyGroups: [
    ['level', 'xp']
  ]),
  (tool: 'create_journal_entry', anyGroups: [
    ['journal']
  ]),
  (tool: 'add_calendar_event', anyGroups: [
    ['calendar'],
    ['add']
  ]),
  (tool: 'get_calendar_events', anyGroups: [
    ['coming up', 'this month', 'upcoming']
  ]),
  (tool: 'log_habit', anyGroups: [
    ['habit']
  ]),
  (tool: 'add_bucket_item', anyGroups: [
    ['bucket list']
  ]),
  (tool: 'add_trip', anyGroups: [
    ['trip to', 'plan a trip']
  ]),
  (tool: 'search_spotify', anyGroups: [
    ['play some', 'spotify', 'song for us']
  ]),
  (tool: 'get_gallery', anyGroups: [
    ['photo']
  ]),
  (tool: 'get_garden', anyGroups: [
    ['garden']
  ]),
  (tool: 'web_search', anyGroups: [
    ['right now', 'price of', 'latest', 'news']
  ]),
];

List<String> _route(String message) {
  final lower = message.toLowerCase();
  for (final rule in _rules) {
    final hit =
        rule.anyGroups.every((g) => g.any((k) => lower.contains(k)));
    if (hit) return [rule.tool];
  }
  return const [];
}

void main() {
  final casesFile = File('functions/test/mochi_eval_cases.json');
  if (!casesFile.existsSync()) {
    print('cases file not found — run from repo root');
    exit(2);
  }
  final cases =
      (jsonDecode(casesFile.readAsStringSync()) as List).cast<Map>();
  var correct = 0;
  final misses = <String>[];
  for (final c in cases) {
    final got = _route(c['message'] as String);
    final want = ((c['expectedTools'] as List?) ?? []).cast<String>();
    final ok = got.length == want.length &&
        got.every((t) => want.contains(t));
    if (ok) {
      correct++;
    } else {
      misses.add('${c['id']}: want=$want got=$got');
    }
  }
  final score = cases.isEmpty ? 0.0 : correct / cases.length;
  print('mochi routing eval: $correct/${cases.length} '
      '(${(score * 100).toStringAsFixed(1)}%)');
  for (final m in misses) {
    print('  miss $m');
  }
  print('baseline: keep this >= 80% when tuning the persona or tools.');
}
