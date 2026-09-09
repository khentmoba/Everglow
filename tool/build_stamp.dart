// Shared build stamp: "<pubspec version>-<short commit>"
// (e.g. "6.1.0+1-869a488").
//
// Used by generate_sw.dart (service-worker cache names + version.json) and
// build_web.dart (core-shell cache-bust query) so every stamp in one build
// agrees. The stamp is inherently a deploy-time value: committed copies in
// web/ are refreshed by CI on every deploy.
import "dart:io";

String buildStamp() {
  final pubspec = File("pubspec.yaml").readAsStringSync();
  final version =
      RegExp(r"version:\s*(\S+)").firstMatch(pubspec)?.group(1) ?? "0.0.0+0";

  var commit = "";
  try {
    final result = Process.runSync("git", ["rev-parse", "--short", "HEAD"]);
    if (result.exitCode == 0) commit = (result.stdout as String).trim();
  } catch (_) {
    // Not a git checkout (or git missing): version-only stamp.
  }
  return commit.isNotEmpty ? "$version-$commit" : version;
}
