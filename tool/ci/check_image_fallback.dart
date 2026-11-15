import 'dart:io';

import '_io.dart';

const Set<String> _naturalSizeKeeps = <String>{
  'lib/features/gallery/presentation/screens/photo_viewer_screen.dart',
  'lib/features/manga/presentation/widgets/reader_page_image.dart',
};

class _ImageNetworkCall {
  _ImageNetworkCall(this.line, this.hasCacheWidth);

  final int line;
  final bool hasCacheWidth;
}

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
