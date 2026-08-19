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
// BUILD=$buildConst
const CACHE='everglow-$buildConst';
const ASSETS=['flutter_bootstrap.js','main.dart.js'];
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS).catch(()=>{})));});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;const u=new URL(e.request.url);const p=u.pathname;if(p==='/version.json'||p==='/sw.js'||p==='/index.html'){e.respondWith(fetch(e.request,{cache:'no-store'}));return;}let hit=false;for(const a of ASSETS) if(p.endsWith(a)) hit=true;if(hit){e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(res=>{caches.open(CACHE).then(c=>c.put(e.request,res.clone()));return res;})));return;}});
''';

  File('web/sw.js').writeAsStringSync(sw);
  File('web/version.json').writeAsStringSync(
    '{"build": "$buildConst"}\n',
  );
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
