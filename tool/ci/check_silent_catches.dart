import 'dart:io';

import '_io.dart';

final _emptyCatch = RegExp(r'catch\s*(?:<[^>]*>)?\s*\([^)]*\)\s*\{\s*\}');

const Map<String, int> _allowlist = {
  'lib/core/system/app_error_widget.dart': 3,
  'lib/core/config/env_config.dart': 1,
  'lib/main.dart': 1,
  'lib/features/ai/presentation/widgets/motchi_widgets_tools.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_motchi_sidebar.dart': 1,
  'lib/features/daily_bloom/presentation/widgets/daily_bloom.dart': 1,
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
