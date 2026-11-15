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
