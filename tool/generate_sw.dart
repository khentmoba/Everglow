// ignore_for_file: avoid_print
// Build tool: prints the generated build stamp for CI logs.
import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final versionMatch = RegExp(r'version:\s*(\S+)').firstMatch(pubspec);
  final version = versionMatch?.group(1) ?? '0.0.0+0';

  final commitHash = _run('git', ['rev-parse', '--short', 'HEAD']).trim();
  final buildConst = commitHash.isNotEmpty ? '$version-$commitHash' : version;

  final sw = '''
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', () => {
  self.registration.unregister();
});
''';

  File('web/sw.js').writeAsStringSync(sw);
  print('sw.js written with BUILD = $buildConst');
}

String _run(String executable, List<String> args) {
  try {
    final result = Process.runSync(executable, args);
    return result.exitCode == 0
        ? (result.stdout as String).trim()
        : '';
  } catch (_) {
    return '';
  }
}
