import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/core/perf/repaint_throttle.dart';

/// The dashboard's ambient layer is rate-limited by a [RepaintThrottle] instead
/// of repainting at the display rate. These tests drive an injected clock, so
/// they assert the cap exactly instead of inferring it from frame-cost timings
/// that move with whatever machine the suite runs on.
void main() {
  group('RepaintThrottle', () {
    late DateTime now;
    DateTime clock() => now;

    // Defaults to the interval the dashboard ambience actually ships with, so
    // this pins the real cap rather than a convenient stand-in.
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

      t.onSourceTick(); // t=0, forwarded
      now = now.add(const Duration(milliseconds: 10));
      t.onSourceTick(); // 10ms later, well inside the 32ms window -> dropped
      now = now.add(const Duration(milliseconds: 10));
      t.onSourceTick(); // 20ms after the first, still inside -> dropped

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
      // One second of 60 Hz ticks (16ms apart) is what a display-rate
      // animation would deliver. The cap should let through ~30.
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
