import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

      expect(
        result,
        equals([
          [1, 2, 3],
          [4, 5, 6],
        ]),
      );
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
          )
          .listen(results.add, onError: errors.add)
          .asFuture<void>()
          .catchError((_) {});

      expect(results, isEmpty);
      // Stream should have closed (not errored) via timeout
    });

    test('handles empty stream correctly', () async {
      final emptyStream = const Stream<List<int>>.empty();

      final results = await withFirestoreTimeout(
        emptyStream,
        duration: const Duration(seconds: 1),
        label: 'empty-stream',
      ).toList();

      expect(results, isEmpty);
    });

    test(
      'stays live after first event and keeps delivering later events',
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
      },
    );

    test('re-attaches when the first attempt hangs', () async {
      var calls = 0;
      Stream<List<int>> factory() {
        calls++;
        if (calls == 1) {
          return Stream<List<int>>.fromFuture(Completer<List<int>>().future);
        }
        return Stream<List<int>>.value([1, 2]);
      }

      final result = await withFirestoreTimeout(
        factory(),
        resubscribe: factory,
        duration: const Duration(milliseconds: 100),
        retryDelay: const Duration(milliseconds: 50),
        label: 'hang-then-ok',
      ).toList();

      expect(result, equals([
        [1, 2],
      ]));
      expect(calls, 2);
    });

    test('re-attaches when the first attempt errors before any data',
        () async {
      var calls = 0;
      Stream<List<int>> factory() {
        calls++;
        if (calls == 1) {
          return Stream<List<int>>.error(Exception('boom'));
        }
        return Stream<List<int>>.value([7]);
      }

      final result = await withFirestoreTimeout(
        factory(),
        resubscribe: factory,
        duration: const Duration(seconds: 2),
        retryDelay: const Duration(milliseconds: 50),
        label: 'error-then-ok',
      ).toList();

      expect(result, equals([
        [7],
      ]));
      expect(calls, 2);
    });

    test('surfaces a TimeoutException when every attempt hangs', () async {
      var calls = 0;
      Stream<List<int>> factory() {
        calls++;
        return Stream<List<int>>.fromFuture(Completer<List<int>>().future);
      }

      final results = <List<int>>[];
      final errDone = Completer<Object>();
      final subscription = withFirestoreTimeout(
        factory(),
        resubscribe: factory,
        duration: const Duration(milliseconds: 100),
        retryDelay: const Duration(milliseconds: 50),
        maxAttempts: 2,
        label: 'always-hang',
      ).listen(results.add, onError: errDone.complete);
      // NOTE: do not chain .asFuture() here — on this SDK the future
      // claims the error and the listen onError never fires.
      final seenError = await errDone.future.timeout(
        const Duration(seconds: 5),
      );
      await subscription.cancel();

      expect(results, isEmpty);
      expect(seenError, isA<TimeoutException>());
      expect(calls, 2);
    });

    test('does not re-attach after the listener unsubscribes', () async {
      var calls = 0;
      Stream<List<int>> factory() {
        calls++;
        return Stream<List<int>>.fromFuture(Completer<List<int>>().future);
      }

      final subscription = withFirestoreTimeout(
        factory(),
        resubscribe: factory,
        duration: const Duration(milliseconds: 80),
        retryDelay: const Duration(milliseconds: 200),
        label: 'cancelled',
      ).listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await subscription.cancel();
      // Both the budget and the backoff windows pass here; neither may
      // trigger a second attach after cancel.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(calls, 1);
    });
  });

  group('firestoreErrorHint', () {
    test('names common failure modes', () {
      expect(firestoreErrorHint(null), 'Could not load');
      expect(firestoreErrorHint(TimeoutException('slow')), 'Timed out');
      expect(
        firestoreErrorHint(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        contains('Access denied'),
      );
      expect(
        firestoreErrorHint(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
        ),
        'Network hiccup',
      );
      expect(
        firestoreErrorHint(
          Exception('SocketException: Failed host lookup'),
        ),
        'You may be offline',
      );
      expect(firestoreErrorHint(Exception('kaboom')), 'Could not load');
    });
  });
}
