// ignore_for_file: avoid_print
// Everglow web build wrapper: prefers the engine-revision-pinned gstatic
// CanvasKit CDN over self-hosting canvaskit/*.wasm (~7 MB).
//
// Why: the CDN URL contains the engine revision, so it is immutable per
// Flutter version AND shared across every Flutter site — many users already
// have it cached before their first Everglow visit. Self-hosted canvaskit/
// files reuse stable filenames across builds, so they can never be marked
// immutable safely.
//
// Safety: resolves the revision from `flutter --version --machine`, then
// verifies the CDN file answers 200 before trusting it. A missing file,
// offline CI, or unknown engine falls back to a plain self-hosted build
// (slower cold start, still correct) — a bad CDN guess can never break
// a deploy.
//
// Usage: dart tool/build_web.dart -- --release --no-source-maps
//        [--dart-define=KEY=VALUE ...]
import "dart:convert";
import "dart:io";

import "build_stamp.dart";

/// The WebAssembly core, emitted next to main.dart.js by `--wasm` builds.
const _wasmCoreFiles = ["main.dart.wasm", "main.dart.mjs"];

Future<void> main(List<String> args) async {
  // WebAssembly is on by default: the build then holds both cores and the
  // Flutter loader picks per browser (wasm on Chrome-family, JS elsewhere,
  // including Safari). `--no-wasm` builds the JS core only.
  final wasm = !args.contains("--no-wasm");
  final buildArgs = args.where((a) => a != "--" && a != "--no-wasm").toList();
  final canvaskitUrl = await _resolveCanvaskitUrl();
  final cmd = [
    "build",
    "web",
    if (wasm && !buildArgs.contains("--wasm")) "--wasm",
    ...buildArgs,
  ];
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
    runInShell: Platform.isWindows, // Flutter is a .bat command on Windows.
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

/// Discovers all deferred JS chunks in build/web, pairs them with the
/// engine-pinned CanvasKit URL, and writes a rich version.json so the
/// service worker and web idle preloader can warm the full offline app
/// shell in the background without blocking first paint.
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
  final wasmCore = [
    for (final file in _wasmCoreFiles)
      if (File('build/web/$file').existsSync()) '$file?v=$stamp',
  ];
  final data = <String, dynamic>{
    'build': stamp,
    'core': busted,
    if (wasmCore.length == _wasmCoreFiles.length) 'wasmCore': wasmCore,
    'canvaskit': canvaskitUrl ?? '/canvaskit/',
    'parts': parts,
  };
  final jsonStr = '${jsonEncode(data)}\n';
  File('build/web/version.json').writeAsStringSync(jsonStr);
  print('[build_web] version.json stamped with ${parts.length} deferred parts');
}

/// Emits `<link rel="modulepreload">` for the Firebase JS SDK modules into the
/// built index.html, so their ~500KB is fetched while the shell is still
/// downloading instead of after `main.dart.js` has evaluated.
///
/// `firebase_core_web` injects these from `_initializeCore()`, which only runs
/// inside `Firebase.initializeApp()` — measured at ~1230ms into a cold load,
/// strictly serial behind the 1.3MB shell. They are ES modules, so a
/// modulepreload lands in the module map that the later `import()` reuses.
///
/// The version comes from the resolved `firebase_core_web` package, never a
/// hand-written constant, so a dependency bump cannot leave a stale preload
/// downloading a module nothing imports. Fails the build when the placeholder
/// or the version is missing: silently skipping would quietly restore the
/// serial load this exists to remove.
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

/// Reads `supportedFirebaseJsSdkVersion` from the resolved `firebase_core_web`
/// package, i.e. the exact version `firebase_core` will import at runtime.
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

/// Rewrites the core-shell URL to `main.dart.js?v=<build stamp>` in the
/// emitted Flutter loader, so every build is a distinct service-worker
/// cache key (see generate_sw.dart). Without this, filenames are stable
/// across Flutter builds and a post-deploy reload can boot stale bytes
/// from the still-active old worker — near-certain on slow lines.
///
/// The page itself never references the shell: a `<link rel=preload>` for a
/// worker-served URL is discarded by Chrome (cross-world mismatch) and only
/// wastes the download, so index.html no longer carries one.
///
/// Only quoted references are touched, so a `main.dart.js.map` source-map
/// reference (source-mapped builds) can never be corrupted. Fails the
/// build loudly when the expected reference is missing: a silent miss
/// here would mean silently stale updates.
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
      // flutter.js is an emitted spare (the page loads the inlined copy in
      // flutter_bootstrap.js), so only the bootstrap is required.
      if (path.endsWith("flutter.js")) continue;
      throw StateError("[build_web] missing $path; cannot stamp core shell.");
    }
    final src = file.readAsStringSync();
    var updated = src;
    final hits = '"main.dart.js"'.allMatches(src).length;
    if (hits > 0) {
      updated = updated.replaceAll('"main.dart.js"', '"$busted"');
    }
    // WebAssembly builds also emit main.dart.wasm + its main.dart.mjs glue;
    // they need the same per-build URL or the worker could serve old bytes.
    for (final file in _wasmCoreFiles) {
      updated = updated.replaceAll('"$file"', '"$file?v=$stamp"');
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
