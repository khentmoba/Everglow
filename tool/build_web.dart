// ignore_for_file: avoid_print
import "dart:convert";
import "dart:io";

import "build_stamp.dart";

Future<void> main(List<String> args) async {
  final buildArgs = args.where((a) => a != "--").toList();
  final canvaskitUrl = await _resolveCanvaskitUrl();
  final cmd = ["build", "web", ...buildArgs];
  if (canvaskitUrl != null) {
    cmd.add("--dart-define=FLUTTER_WEB_CANVASKIT_URL=$canvaskitUrl");
  } else {
    print(
      "[build_web] WARNING: gstatic CanvasKit unverified; "
      "self-hosting canvaskit/ (slower cold start, still correct).",
    );
  }
  print("[build_web] running: flutter ${cmd.join(' ')}");
  final proc = await Process.start(
    "flutter",
    cmd,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final code = await proc.exitCode;
  if (code != 0) {
    print("[build_web] flutter build web failed (exit $code)");
    exit(code);
  }
  if (canvaskitUrl != null) {
    print("[build_web] CanvasKit served from $canvaskitUrl");
  }
  _stampCoreShell();
  _stampFirebasePreload();
  _stampVersionJson(canvaskitUrl);
}

void _stampVersionJson(String? canvaskitUrl) {
  final stamp = buildStamp();
  final busted = 'main.dart.js?v=$stamp';
  final dir = Directory('build/web');
  final parts = <String>[];
  if (dir.existsSync()) {
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('main.dart.js_') && name.endsWith('.part.js')) {
          parts.add(name);
        }
      }
    }
    parts.sort();
  }
  final data = <String, dynamic>{
    'build': stamp,
    'core': busted,
    'canvaskit': canvaskitUrl ?? '/canvaskit/',
    'parts': parts,
  };
  final jsonStr = '${jsonEncode(data)}\n';
  File('build/web/version.json').writeAsStringSync(jsonStr);
  print('[build_web] version.json stamped with ${parts.length} deferred parts');
}

void _stampFirebasePreload() {
  const startMarker = "<!-- EVERGLOW_FIREBASE_PRELOAD_START -->";
  const endMarker = "<!-- EVERGLOW_FIREBASE_PRELOAD_END -->";
  final index = File("build/web/index.html");
  if (!index.existsSync()) {
    throw StateError("[build_web] missing build/web/index.html; cannot stamp Firebase preload.");
  }
  final version = _firebaseJsSdkVersion();
  final links = [
    for (final service in ["app", "auth", "firestore", "messaging", "storage"])
      "  <link rel=\"modulepreload\" crossorigin=\"anonymous\" "
          "href=\"https://www.gstatic.com/firebasejs/$version/firebase-$service.js\">",
  ].join("\n");
  final src = index.readAsStringSync();
  final start = src.indexOf(startMarker);
  final end = src.indexOf(endMarker);
  if (start < 0 || end < start) {
    throw StateError(
      "[build_web] index.html is missing the Firebase preload markers; "
      "update _stampFirebasePreload.",
    );
  }
  final updated = src.replaceRange(start, end + endMarker.length, links);
  index.writeAsStringSync(updated);
  print("[build_web] Firebase SDK preloaded at $version (5 modules)");
}

String _firebaseJsSdkVersion() {
  final config = File(".dart_tool/package_config.json");
  if (!config.existsSync()) {
    throw StateError("[build_web] missing .dart_tool/package_config.json; run flutter pub get.");
  }
  final decoded = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
  final packages = (decoded["packages"] as List).cast<Map<String, dynamic>>();
  final entry = packages.firstWhere(
    (p) => p["name"] == "firebase_core_web",
    orElse: () => throw StateError(
      "[build_web] firebase_core_web is not resolved; cannot stamp the Firebase preload.",
    ),
  );
  final rootUri = entry["rootUri"] as String;
  final root = rootUri.startsWith("file:")
      ? Uri.parse(rootUri).toFilePath()
      : rootUri;
  final versionFile = File("$root/lib/src/firebase_sdk_version.dart");
  if (!versionFile.existsSync()) {
    throw StateError(
      "[build_web] ${versionFile.path} is missing; firebase_core_web layout changed.",
    );
  }
  final match = RegExp(
    r'''supportedFirebaseJsSdkVersion\s*=\s*['"]([^'"]+)['"]''',
  ).firstMatch(versionFile.readAsStringSync());
  if (match == null) {
    throw StateError(
      "[build_web] could not read supportedFirebaseJsSdkVersion from ${versionFile.path}.",
    );
  }
  return match.group(1)!;
}

void _stampCoreShell() {
  final stamp = buildStamp();
  final busted = 'main.dart.js?v=$stamp';
  var bootstrapHits = 0;
  for (final path in [
    "build/web/flutter_bootstrap.js",
    "build/web/flutter.js",
  ]) {
    final file = File(path);
    if (!file.existsSync()) {
      if (path.endsWith("flutter.js")) continue;
      throw StateError("[build_web] missing $path; cannot stamp core shell.");
    }
    final src = file.readAsStringSync();
    var updated = src;
    final hits = '"main.dart.js"'.allMatches(src).length;
    if (hits > 0) {
      updated = updated.replaceAll('"main.dart.js"', '"$busted"');
    }
    if (path.endsWith("flutter_bootstrap.js")) {
      bootstrapHits = hits;
      updated = 'window.__EVERGLOW_BUILD__ = "$stamp";\n$updated';
    }
    file.writeAsStringSync(updated);
  }
  if (bootstrapHits == 0) {
    throw StateError(
      '[build_web] flutter_bootstrap.js has no "main.dart.js" reference; '
      'Flutter output changed — update _stampCoreShell.',
    );
  }
  print("[build_web] core shell stamped: $busted");
}

Future<String?> _resolveCanvaskitUrl() async {
  try {
    final ver = await Process.run("flutter", [
      "--version",
      "--machine",
    ], runInShell: Platform.isWindows);
    if (ver.exitCode != 0) return null;
    final decoded = jsonDecode(ver.stdout as String) as Map<String, dynamic>;
    final rev = (decoded["engineRevision"] as String?)?.trim();
    if (rev == null || rev.isEmpty) return null;
    final url = "https://www.gstatic.com/flutter-canvaskit/$rev/";
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.headUrl(Uri.parse("${url}canvaskit.js"));
      final res = await req.close().timeout(const Duration(seconds: 15));
      await res.drain();
      if (res.statusCode == 200) return url;
      print("[build_web] gstatic check returned ${res.statusCode} for $url");
      return null;
    } finally {
      client.close();
    }
  } catch (e) {
    print("[build_web] CanvasKit CDN check failed ($e); falling back.");
    return null;
  }
}
