// Silent-catch guard: no new empty `catch (...) {}` blocks in lib/.
// Prevents the class of bug where a Firestore read, auth token fetch, or
// proxy call fails and the failure vanishes with no Logger.e line, so a
// live break (blank card, dead rail, missing letters) is undiagnosable at
// 2am. Audit (PR kill-silent-catches-data-paths): 36 fully-empty catches
// existed; the ones hiding data-path failures now log.
//
// Rule: any `catch (...) { }` whose body is only whitespace must be covered
// by the allowlist below. Video-player JS-interop and the ErrorWidget
// fallback are deliberately silent (see each reason); everything else must
// log. Comment-only bodies are out of scope: the author documented intent.
//
// Usage: dart tool/ci/check_silent_catches.dart
import 'dart:convert';
import 'dart:io';

// Lenient read: one non-UTF8 source file must not break the scan.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

/// Fully-empty catch blocks. `\s` spans newlines, so `catch (_) {` followed
/// by a lone `}` on its own line still counts.
final _emptyCatch = RegExp(r'catch\s*(?:<[^>]*>)?\s*\([^)]*\)\s*\{\s*\}');

/// file -> how many empty catches were reviewed and kept on purpose.
const Map<String, int> _allowlist = {
  // The error UI itself: must never throw while rendering another error.
  'lib/core/system/app_error_widget.dart': 3,
  // Boot config read that falls back to a default when dotenv is not
  // loaded yet (running before EnvConfig.load in tests/build).
  'lib/core/config/env_config.dart': 1,
  // FlutterError handler: only extracts a widget label for the log line
  // that follows it, which already logs via Logger.e.
  'lib/main.dart': 1,
  // Deliberate policy, documented at the call site: a dead external link
  // is not worth an error banner mid-chat.
  'lib/features/ai/presentation/widgets/motchi_widgets_tools.dart': 1,
  // Load-veil no-op: DailyBloom is pumped in tests and routes without a
  // DashboardLoadTracker, so a missing provider is expected here.
  'lib/features/daily_bloom/presentation/widgets/daily_bloom.dart': 1,
  // JS-interop and video players: guards around browser calls that throw
  // on detached elements. Silent by design (Khent: keep these).
  'lib/features/ai/presentation/widgets/motchi_web_bridge_web.dart': 1,
  'lib/features/cinema/presentation/widgets/trailer_player_web.dart': 1,
  'lib/features/jukebox/data/services/spotify_player_service_web.dart': 1,
  'lib/features/watch_party/presentation/widgets/hls_server_player.dart': 7,
};

int _lineAt(String src, int offset) {
  var line = 1;
  for (var i = 0; i < offset; i++) {
    if (src.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

String _snippet(String src, RegExpMatch m) {
  final start = src.lastIndexOf('\n', m.start) + 1;
  var end = src.indexOf('\n', m.end);
  if (end == -1) end = src.length;
  return src.substring(start, end).trim();
}

Future<void> main() async {
  final failures = <String>[];
  var kept = 0;
  var total = 0;

  final files = await Directory('lib')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    final src = await readTolerant(file);
    final hits = _emptyCatch.allMatches(src).toList();
    if (hits.isEmpty) continue;
    total += hits.length;

    final allowed = _allowlist[path] ?? 0;
    if (allowed >= hits.length) {
      kept += hits.length;
      continue;
    }
    kept += allowed;
    final detail = hits
        .skip(allowed)
        .map((m) => '  $path:${_lineAt(src, m.start)}: ${_snippet(src, m)}')
        .join('\n');
    failures.add(
      '$path: ${hits.length - allowed} new empty catch block(s) swallow '
      'failures silently.\n$detail',
    );
  }

  if (failures.isNotEmpty) {
    stderr.writeln(
      '[silent-catches] FAIL: silent catch blocks hide production failures. '
      'Add Logger.e(..., error: e, stackTrace: st), or allowlist the file '
      'with a reason if the silence is truly deliberate.\n'
      '${failures.join('\n')}',
    );
    exit(1);
  }
  stdout.writeln(
    '[silent-catches] OK: $total empty catch blocks, $kept allowlisted, '
    '0 new.',
  );
}
