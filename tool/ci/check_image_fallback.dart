// Image-fallback guard: no bare Image.network outside the shared wrapper.
// Prevents the PR #119 class: covers/posters blanking to placeholders with
// no retry because a call site bypassed the hardened image path.
//
// Rule: any file under lib/ that calls Image.network( must either be
// lib/shared/widgets/app_network_image.dart itself or contain an
// errorBuilder (loadingBuilder alone is not enough: a 404 with only a
// loadingBuilder still ends on a blank/grey frame).
// New screens should prefer AppNetworkImage, which adds caching,
// cacheWidth, and release-visible logging on top.
//
// Usage: dart tool/ci/check_image_fallback.dart
import 'dart:convert';
import 'dart:io';

// Lenient read: one non-UTF8 source file (extended-ASCII) must not break
// the scan; all markers we look for are ASCII.
Future<String> readTolerant(File f) =>
    f.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));

Future<void> main() async {
  final failures = <String>[];
  var usages = 0;

  final files = await Directory('lib')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  for (final file in files) {
    if (file.path.endsWith('lib/shared/widgets/app_network_image.dart')) {
      continue;
    }
    final src = await readTolerant(file);
    if (!src.contains('Image.network(')) continue;
    usages++;
    if (!src.contains('errorBuilder')) {
      failures.add(
        '${file.path}: raw Image.network without errorBuilder. '
        'Use AppNetworkImage or add an error fallback (PR #119).',
      );
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('[images] OK: $usages raw usages all have fallbacks.');
    return;
  }
  stderr.writeln('[images] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
