import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/manga/data/services/chapter_source_selection.dart';

void main() {
  test(
    'primary success does not wait for a hanging lower-priority source',
    () async {
      final hanging = Completer<String?>();
      expect(
        await firstUsableChapterSource([
          Future.value('primary'),
          hanging.future,
        ], (value) => value.isNotEmpty),
        'primary',
      );
      hanging.completeError(StateError('late failure'));
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'retains source priority and skips errors and unusable responses',
    () async {
      final primary = Completer<String?>();
      final selected = firstUsableChapterSource([
        primary.future,
        Future<String?>.error(StateError('down')),
        Future.value(''),
        Future.value('fallback'),
      ], (value) => value.isNotEmpty);
      primary.complete(null);
      expect(await selected, 'fallback');
    },
  );
}
