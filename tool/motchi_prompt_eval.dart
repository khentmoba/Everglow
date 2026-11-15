// ignore_for_file: avoid_print
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
