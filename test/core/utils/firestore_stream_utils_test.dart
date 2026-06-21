import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/utils/firestore_stream_utils.dart';

void main() {
  group('withFirestoreTimeout', () {
    test('emits data normally when stream responds within timeout', () async {
      final stream = Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
      ]);

      final result = await withFirestoreTimeout(
        stream,
        duration: const Duration(seconds: 2),
        label: 'test-stream',
      ).toList();

      expect(result, equals([
        [1, 2, 3],
        [4, 5, 6],
      ]));
    });

    test('closes stream when it hangs beyond timeout', () async {
      // A stream that never emits
      final hangingStream = Stream<List<int>>.fromFuture(
        Completer<List<int>>().future,
      );

      final results = <List<int>>[];
      final errors = <Object>[];

      await withFirestoreTimeout(
        hangingStream,
        duration: const Duration(milliseconds: 100),
        label: 'hanging-stream',
      ).listen(
        results.add,
        onError: errors.add,
      ).asFuture<void>().catchError((_) {});

      expect(results, isEmpty);
      // Stream should have closed (not errored) via timeout
    });

    test('handles empty stream correctly', () async {
      final emptyStream = Stream<List<int>>.empty();

      final results = await withFirestoreTimeout(
        emptyStream,
        duration: const Duration(seconds: 1),
        label: 'empty-stream',
      ).toList();

      expect(results, isEmpty);
    });
  });
}
