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

    test('stays live after first event and keeps delivering later events',
        () async {
      final source = StreamController<int>();
      final received = <int>[];

      final subscription = withFirestoreTimeout(
        source.stream,
        duration: const Duration(milliseconds: 100),
        label: 'live-stream',
      ).listen(received.add);

      source.add(1);
      // Wait longer than the timeout. Firestore snapshot streams are
      // allowed to be quiet after the first emission, so this must not
      // close the wrapped stream.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      source.add(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await subscription.cancel();
      await source.close();

      expect(received, equals([1, 2]));
    });
  });
}
