// ignore_for_file: avoid_print
// Motchi routing eval — scores the LIVE router, zero LLM cost.
//
// Older versions of this file scored a hand-written keyword strawman
// that drifted from the shipped router (it read 53.7% while live
// routing was 100%). Now the routing comes from
// `tool/motchi_eval_bridge.js` (single source of truth:
// `selectToolNames` in `functions/motchi_tools.js`) and this file
// only scores recall: every case's expectedTools must be a subset of
// the live selection.
//
// Run from repo root: `dart tool/motchi_prompt_eval.dart`
// Advisory (always exits 0); the hard CI checks are `node --test`
// (`tool routing covers every eval case intent`) and `eval_gate.js`.
import 'dart:convert';
import 'dart:io';

void main() {
  final bridge = File('tool/motchi_eval_bridge.js');
  if (!bridge.existsSync()) {
    print('bridge not found — run from repo root');
    exit(2);
  }
  final res = Process.runSync('node', ['tool/motchi_eval_bridge.js']);
  if (res.exitCode != 0) {
    print('bridge failed:\n${res.stderr}');
    exit(2);
  }
  final decoded = jsonDecode(res.stdout as String) as Map;
  final cases = (decoded['cases'] as List).cast<Map>();
  var correct = 0;
  final misses = <String>[];
  for (final c in cases) {
    final want = ((c['expectedTools'] as List?) ?? []).cast<String>();
    final got = ((c['selected'] as List?) ?? []).cast<String>().toSet();
    final ok = want.every(got.contains);
    if (ok) {
      correct++;
    } else {
      final missing = want.where((t) => !got.contains(t)).join(',');
      misses.add('${c['id']}: missing=$missing (selected ${got.length})');
    }
  }
  final score = cases.isEmpty ? 0.0 : correct / cases.length;
  print(
    'motchi routing eval (live): $correct/${cases.length} '
    '(${(score * 100).toStringAsFixed(1)}%)',
  );
  for (final m in misses) {
    print('  miss $m');
  }
  if (score < 1) {
    print('live routing must cover every eval case — fix the router, not the cases.');
  } else {
    print('perfect: live router covers every eval intent.');
  }
}
