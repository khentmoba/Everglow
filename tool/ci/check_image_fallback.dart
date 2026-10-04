// Image-fallback guard: no bare Image.network outside the shared wrapper.
// Prevents the PR #119 class: covers/posters blanking to placeholders with
// no retry because a call site bypassed the hardened image path.
//
// Two rules, both about a raw Image.network that skipped AppNetworkImage:
//   1. it must have an errorBuilder (loadingBuilder alone is not enough: a 404
//      with only a loadingBuilder still ends on a blank/grey frame), and
//   2. it must set cacheWidth.
// New screens should prefer AppNetworkImage, which adds caching, cacheWidth,
// and release-visible logging on top.
//
// Rule 2 exists because a missing cacheWidth is invisible in review and
// expensive on a phone: per the memory table in docs/PERF_NOTES.md a natural
// decode is ~3.5 MB against ~0.36 MB decoded to a 128px thumb, so one call
// site can quietly cost more than the decoded image cache ceiling. Found this
// way in tonight_screen.dart, where date-option thumbnails filled a 76px slot
// at full natural resolution.
//
// Usage: dart tool/ci/check_image_fallback.dart
import 'dart:io';

import '_io.dart';

/// Files allowed to decode at natural size, because showing the image at full
/// resolution is the point. Everything else must pick a decode width.
///
/// Keep this list short and justified — an unlisted file is a failure.
const Set<String> _naturalSizeKeeps = <String>{
  // Full-screen photo zoom: the viewer is already showing the largest size the
  // user can reach, so a smaller decode would be visible.
  'lib/features/gallery/presentation/screens/photo_viewer_screen.dart',
  // Manga reader pages: pages are read at high zoom, one page at a time.
  'lib/features/manga/presentation/widgets/reader_page_image.dart',
};

/// One `Image.network(` call site, and whether its own argument list sets a
/// decode width.
class _ImageNetworkCall {
  _ImageNetworkCall(this.line, this.hasCacheWidth);

  final int line;
  final bool hasCacheWidth;
}

/// Finds each `Image.network(` call and inspects only its own arguments.
///
/// The window runs from the call to the start of the next call (or 600 chars,
/// whichever comes first) — long enough for a normal argument list, short
/// enough that it cannot reach an unrelated call site.
List<_ImageNetworkCall> _imageNetworkCalls(String src) {
  const needle = 'Image.network(';
  final calls = <_ImageNetworkCall>[];
  var from = 0;
  while (true) {
    final at = src.indexOf(needle, from);
    if (at < 0) break;
    final start = at + needle.length;
    final next = src.indexOf(needle, start);
    final end = next < 0 ? src.length : next;
    final window = src.substring(
      start,
      end > start + 600 ? start + 600 : end,
    );
    calls.add(
      _ImageNetworkCall(
        '\n'.allMatches(src.substring(0, at)).length + 1,
        window.contains('cacheWidth'),
      ),
    );
    from = start;
  }
  return calls;
}

Future<void> main() async {
  final failures = <String>[];
  var usages = 0;

  final files = await Directory('lib')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  for (final file in files) {
    // Normalise separators: the keep list is written with forward slashes so
    // it matches regardless of the platform running the guard.
    final path = file.path.replaceAll('\\', '/');
    if (path.endsWith('lib/shared/widgets/app_network_image.dart')) {
      continue;
    }
    final src = await readTolerant(file);
    if (!src.contains('Image.network(')) continue;
    usages++;
    if (!src.contains('errorBuilder')) {
      failures.add(
        '$path: raw Image.network without errorBuilder. '
        'Use AppNetworkImage or add an error fallback (PR #119).',
      );
    }

    // cacheWidth is checked per call site, not per file: a file with one
    // correct usage must not launder a second uncapped one. Each window ends
    // where the next call begins, so a call cannot borrow its neighbour's
    // cacheWidth.
    for (final call in _imageNetworkCalls(src)) {
      if (call.hasCacheWidth || _naturalSizeKeeps.contains(path)) continue;
      failures.add(
        '$path:${call.line}: raw Image.network without cacheWidth. '
        'Use AppNetworkImage, or pass cacheWidth for the size you display '
        '(see the table in docs/PERF_NOTES.md).',
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
