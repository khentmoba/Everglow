import 'dart:io';

const pinned = {
  'test/features/cinema/netflix_poster_card_layout_test.dart':
      ['phone', 'overflow'],
  'test/features/books/book_cover_card_layout_test.dart':
      ['phone', 'overflow'],
  'test/shared/widgets/shelf/shelf_poster_card_layout_test.dart':
      ['phone', 'overflow'],
  'test/features/dashboard/presentation/widgets/feature_section_layout_test.dart':
      ['phone', 'overflow'],
  'test/features/dashboard/presentation/widgets/dashboard_top_actions_layout_test.dart':
      ['phone', 'tablet', 'overflow'],
};

Future<void> main() async {
  final failures = <String>[];

  for (final entry in pinned.entries) {
    final file = File(entry.key);
    if (!await file.exists()) {
      failures.add('${entry.key} is missing; card overflow can regress.');
      continue;
    }
    final src = (await file.readAsString()).toLowerCase();
    final missing =
        entry.value.where((m) => !src.contains(m)).toList();
    if (missing.isNotEmpty) {
      failures.add(
        '${entry.key} no longer covers small surfaces '
        '(missing: ${missing.join(", ")}).',
      );
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('[layout] OK: pinned card overflow tests intact.');
    return;
  }
  stderr.writeln('[layout] FAIL (${failures.length}):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exit(1);
}
