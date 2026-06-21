import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final versionMatch = RegExp(r'version:\s*(\S+)').firstMatch(pubspec);
  final version = versionMatch?.group(1) ?? '0.0.0+0';

  final commitHash = _run('git', ['rev-parse', '--short', 'HEAD']).trim();
  final buildConst = commitHash.isNotEmpty ? '$version-$commitHash' : version;

  final sw = '''
const BUILD = '$buildConst';
let isUpdate = false;

self.addEventListener('install', (event) => {
  isUpdate = !!self.registration.active;
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(keys.map((key) => caches.delete(key)));
    }).then(() => {
      return self.clients.claim();
    }).then(() => {
      if (isUpdate) {
        return self.clients.matchAll().then((clients) => {
          clients.forEach((client) => {
            client.postMessage({ type: 'NEW_VERSION', version: '$buildConst' });
          });
        });
      }
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
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
