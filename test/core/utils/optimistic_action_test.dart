import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/core/utils/optimistic_action.dart';

void main() {
  group('OptimisticAction.run', () {
    test('calls apply immediately, then succeeds and returns result', () async {
      var applyCalled = false;
      var rollbackCalled = false;
      var successCalled = false;
      String? successValue;

      final result = await OptimisticAction.run<String>(
        apply: () {
          applyCalled = true;
        },
        action: () async {
          expect(applyCalled, isTrue);
          return 'ok';
        },
        rollback: () {
          rollbackCalled = true;
        },
        onSuccess: (val) {
          successCalled = true;
          successValue = val;
        },
      );

      expect(applyCalled, isTrue);
      expect(rollbackCalled, isFalse);
      expect(successCalled, isTrue);
      expect(successValue, equals('ok'));
      expect(result, equals('ok'));
    });

    test('calls rollback and onError when action throws', () async {
      var applyCalled = false;
      var rollbackCalled = false;
      Object? capturedError;

      final result = await OptimisticAction.run<String>(
        apply: () {
          applyCalled = true;
        },
        action: () async {
          throw Exception('network failure');
        },
        rollback: () {
          rollbackCalled = true;
        },
        onError: (err, _) {
          capturedError = err;
        },
      );

      expect(applyCalled, isTrue);
      expect(rollbackCalled, isTrue);
      expect(capturedError, isA<Exception>());
      expect(result, isNull);
    });

    test('survives an exception in apply cleanly', () async {
      var rollbackCalled = false;

      final result = await OptimisticAction.run<String>(
        apply: () {
          throw StateError('apply failed');
        },
        action: () async => 'should not run',
        rollback: () {
          rollbackCalled = true;
        },
      );

      expect(rollbackCalled, isFalse);
      expect(result, isNull);
    });
  });

  group('OptimisticSet', () {
    test('markAdded reflects presence before server confirms', () {
      final set = OptimisticSet<String>();
      final serverItems = ['a', 'b'];

      expect(set.contains('c', serverItems), isFalse);
      set.markAdded('c');
      expect(set.contains('c', serverItems), isTrue);
      expect(set.hasPendingChanges, isTrue);

      final effective = set.applyTo(serverItems);
      expect(effective, containsAll(['a', 'b', 'c']));

      // Server catches up:
      set.reconcile(['a', 'b', 'c']);
      expect(set.hasPendingChanges, isFalse);
      expect(set.contains('c', ['a', 'b', 'c']), isTrue);
    });

    test('markRemoved hides item before server confirms', () {
      final set = OptimisticSet<String>();
      final serverItems = ['a', 'b', 'c'];

      set.markRemoved('b');
      expect(set.contains('b', serverItems), isFalse);
      expect(set.applyTo(serverItems), equals(['a', 'c']));
      expect(set.hasPendingChanges, isTrue);

      // Server catches up:
      set.reconcile(['a', 'c']);
      expect(set.hasPendingChanges, isFalse);
      expect(set.contains('b', ['a', 'c']), isFalse);
    });

    test('rollback restores original behavior', () {
      final set = OptimisticSet<String>();
      final serverItems = ['a', 'b'];

      set.markAdded('c');
      expect(set.contains('c', serverItems), isTrue);
      set.rollbackAdd('c');
      expect(set.contains('c', serverItems), isFalse);

      set.markRemoved('a');
      expect(set.contains('a', serverItems), isFalse);
      set.rollbackRemove('a');
      expect(set.contains('a', serverItems), isTrue);
    });

    test('exposes added, removed, isAdded, and isRemoved', () {
      final set = OptimisticSet<int>();
      set.markAdded(101);
      set.markRemoved(202);

      expect(set.isAdded(101), isTrue);
      expect(set.isAdded(202), isFalse);
      expect(set.isRemoved(202), isTrue);
      expect(set.isRemoved(101), isFalse);
      expect(set.added, contains(101));
      expect(set.removed, contains(202));
    });
  });

  group('OptimisticMap', () {
    test(
      'setOptimistic overrides server value and reconciles when matched',
      () {
        final map = OptimisticMap<String, double>();

        expect(map.get('movie_1', 0.0), equals(0.0));
        map.setOptimistic('movie_1', 1.0);
        expect(map.isPending('movie_1'), isTrue);
        expect(map.get('movie_1', 0.0), equals(1.0));

        // Server still has old:
        map.reconcile('movie_1', 0.0);
        expect(map.isPending('movie_1'), isTrue);

        // Server has confirmed new:
        map.reconcile('movie_1', 1.0);
        expect(map.isPending('movie_1'), isFalse);
        expect(map.get('movie_1', 1.0), equals(1.0));
      },
    );

    test('rollback reverts override', () {
      final map = OptimisticMap<String, String>();

      map.setOptimistic('key', 'optimistic');
      expect(map.get('key', 'server'), equals('optimistic'));

      map.rollback('key');
      expect(map.get('key', 'server'), equals('server'));
    });

    test('exposes overrides map', () {
      final map = OptimisticMap<String, int>();
      map.setOptimistic('star', 5);
      expect(map.overrides['star'], equals(5));
    });
  });
}
