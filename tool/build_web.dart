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
}

/// Rewrites the core-shell URL to `main.dart.js?v=<build stamp>` in the
/// emitted loader + preload, so every build is a distinct service-worker
/// cache key (see generate_sw.dart). Without this, filenames are stable
/// across Flutter builds and a post-deploy reload can boot stale bytes
/// from the still-active old worker — near-certain on slow lines.
///
/// Only quoted references are touched, so a `main.dart.js.map` source-map
/// reference (source-mapped builds) can never be corrupted. Fails the
/// build loudly when the expected reference is missing: a silent miss
/// here would mean silently stale updates.
void _stampCoreShell() {
  final busted = 'main.dart.js?v=${buildStamp()}';
  var bootstrapHits = 0;
  for (final path in [
    "build/web/flutter_bootstrap.js",
    "build/web/flutter.js",
    "build/web/index.html",
  ]) {
    final file = File(path);
    if (!file.existsSync()) {
      // flutter.js is an emitted spare (the page loads the inlined copy in
      // flutter_bootstrap.js); the other two must exist.
      if (path.endsWith("flutter.js")) continue;
      throw StateError("[build_web] missing $path; cannot stamp core shell.");
    }
    final src = file.readAsStringSync();
    final hits = '"main.dart.js"'.allMatches(src).length;
    if (hits > 0) {
      file.writeAsStringSync(src.replaceAll('"main.dart.js"', '"$busted"'));
    }
    if (path.endsWith("flutter_bootstrap.js")) bootstrapHits = hits;
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
    final ver = await Process.run("flutter", ["--version", "--machine"]);
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
