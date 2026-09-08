// Firebase hosting guard: pins the config shape that flipped twice
// (web-lite in b21bea7, full revert in aed17ec, PR #112/#114).
//
// Asserts against firebase.json:
// - hosting.public stays build/web (the Flutter artifact dir);
// - a catch-all "**" -> /index.html rewrite exists LAST (SPA fallback);
// - every /api/* rewrite points at a function (proxy/health surface);
// - security + cache header blocks are present (no silent header drop).
//
// Usage: dart tool/ci/check_firebase_hosting.dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final failures = <String>[];
  final file = File('firebase.json');
  if (!await file.exists()) {
    stderr.writeln('[hosting] firebase.json not found; run from repo root.');
    exit(2);
  }

  late Map<String, dynamic> cfg;
  try {
    cfg = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('[hosting] FAIL: firebase.json is not valid JSON: $e');
    exit(1);
  }

  final hosting = cfg['hosting'];
  if (hosting is! Map<String, dynamic>) {
    stderr.writeln('[hosting] FAIL: missing "hosting" block.');
    exit(1);
  }

  if (hosting['public'] != 'build/web') {
    failures.add(
      'hosting.public is "${hosting['public']}", expected "build/web". '
      'A lite/static swap here takes the Flutter app offline (PR #114).',
    );
  }

  final rewrites = hosting['rewrites'];
  if (rewrites is! List || rewrites.isEmpty) {
    failures.add('hosting.rewrites is missing or empty.');
  } else {
    final last = rewrites.last;
    if (last is! Map ||
        last['source'] != '**' ||
        last['destination'] != '/index.html') {
      failures.add(
        'last rewrite must be {"source": "**", "destination": "/index.html"} '
        '(SPA fallback); got: $last.',
      );
    }
    var apiCount = 0;
    for (final r in rewrites) {
      if (r is Map &&
          (r['source'] as String? ?? '').startsWith('/api/') &&
          (r['function'] as String? ?? '').isNotEmpty) {
        apiCount++;
      }
    }
    if (apiCount < 5) {
      failures.add(
        'only $apiCount /api/* -> function rewrites found; '
        'expected the proxy/health surface (>=5).',
      );
    }
  }

  final headers = hosting['headers'];
  if (headers is! List || headers.isEmpty) {
    failures.add('hosting.headers block is missing.');
  } else {
    final sources =
        headers.whereType<Map>().map((h) => h['source']).toSet();
    for (final need in ['**', '/index.html', '/version.json']) {
      if (!sources.contains(need)) {
        failures.add('hosting.headers lost its "$need" entry.');
      }
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('[hosting] OK: public dir, rewrites, headers pinned.');
    return;
  }
  stderr.writeln('[hosting] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
