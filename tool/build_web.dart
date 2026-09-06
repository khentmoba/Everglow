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
