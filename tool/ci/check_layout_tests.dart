// Layout-overflow gate: card widgets must keep phone/tablet tests.
// Prevents the #54/#56/#58 class: poster/book/shelf cards overflowing on
// Clair's phone and tablet (the top "looks broken" report). The repo
// convention is a layout test per card asserting no overflow at small
// surfaces (e.g. netflix_poster_card_layout_test, book_cover_card_layout,
// shelf_poster_card_layout, feature_section_layout).
//
// Rule: the pinned layout tests below must exist and mention small
// surfaces (phone/tablet/overflow markers). Deleting them fails the PR.
// New card/rail widgets should follow the same pattern and be pinned here.
//
// Usage: dart tool/ci/check_layout_tests.dart
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
