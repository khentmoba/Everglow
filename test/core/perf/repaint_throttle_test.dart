import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/perf/repaint_throttle.dart';

void main() {
  group('RepaintThrottle', () {
    late DateTime now;
    DateTime clock() => now;

    RepaintThrottle build({Duration interval = kAmbienceRepaintInterval}) =>
        RepaintThrottle(interval: interval, clock: clock);

    setUp(() => now = DateTime(2026, 1, 1));

    test('forwards the first tick immediately', () {
      final t = build();
      var notifications = 0;
      t.addListener(() => notifications++);

      t.onSourceTick();

      expect(notifications, 1);
      expect(t.forwardedCount, 1);
      expect(t.droppedCount, 0);
    });

    test('drops ticks arriving inside the interval', () {
      final t = build();
      var notifications = 0;
      t.addListener(() => notifications++);

      t.onSourceTick();
      now = now.add(const Duration(milliseconds: 10));
      t.onSourceTick();
      now = now.add(const Duration(milliseconds: 10));
      t.onSourceTick();

      expect(notifications, 1);
      expect(t.forwardedCount, 1);
      expect(t.droppedCount, 2);
    });

    test('forwards again once the interval has elapsed', () {
      final t = build();
      var notifications = 0;
      t.addListener(() => notifications++);

      t.onSourceTick();
      now = now.add(kAmbienceRepaintInterval);
      t.onSourceTick();

      expect(notifications, 2);
      expect(t.forwardedCount, 2);
    });

    test('caps a 60 Hz stream at roughly 30 fps', () {
      final t = build();
      var notifications = 0;
      t.addListener(() => notifications++);

      for (var i = 0; i < 60; i++) {
        t.onSourceTick();
        now = now.add(const Duration(milliseconds: 16));
      }

      expect(notifications, lessThanOrEqualTo(31));
      expect(notifications, greaterThanOrEqualTo(29));
      expect(t.droppedCount, greaterThan(25));
    });

    test('a stopped source forwards nothing at all', () {
      final t = build();
      var notifications = 0;
      t.addListener(() => notifications++);

      t.onSourceTick();
      final afterFirst = notifications;

      t.stopSource();
      for (var i = 0; i < 120; i++) {
        t.onSourceTick();
        now = now.add(const Duration(milliseconds: 16));
      }

      expect(notifications, afterFirst, reason: 'a paused layer must schedule no frames');
      expect(t.isForwarding, isFalse);
    });

    test('resuming forwards the next tick immediately', () {
      final t = build();
      var notifications = 0;
      t.addListener(() => notifications++);

      t.stopSource();
      for (var i = 0; i < 10; i++) {
        t.onSourceTick();
        now = now.add(const Duration(milliseconds: 16));
      }
      expect(notifications, 0);

      t.resumeSourceIfStopped();
      t.onSourceTick();

      expect(notifications, 1);
      expect(t.isForwarding, isTrue);
    });
  });
}
