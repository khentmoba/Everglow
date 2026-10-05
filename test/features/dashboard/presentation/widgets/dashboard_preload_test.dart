import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/dashboard_preload.dart';

void main() {
  group('DashboardPreload.subscribe', () {
    test('listens to every stream and releases all on dispose', () async {
      final first = StreamController<int>();
      final second = StreamController<String>();
      addTearDown(() async {
        await first.close();
        await second.close();
      });

      final preload = DashboardPreload.subscribe([first.stream, second.stream]);
      expect(first.hasListener, isTrue);
      expect(second.hasListener, isTrue);

      preload.dispose();
      // dispose() cancels without awaiting; flush before asserting.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(first.hasListener, isFalse);
      expect(second.hasListener, isFalse);
    });

    test('a failing stream only logs and never throws', () async {
      final failing = StreamController<int>();
      addTearDown(failing.close);

      final preload = DashboardPreload.subscribe([failing.stream]);
      failing.addError(StateError('offline'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      preload.dispose();
      // Reaching here without throwing is the assertion: warmup must
      // never break Home, even when a query errors.
    });

    test('warmUp with no user attaches nothing and touches no services', () {
      // Empty username returns before any service is constructed, so this
      // is safe without Firebase and mirrors the sections (they render
      // empty for empty usernames too).
      final preload = DashboardPreload.warmUp(userName: '', isCouple: false);
      preload.dispose();
    });
  });
}
