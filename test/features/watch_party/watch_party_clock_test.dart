import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/watch_party/data/services/watch_party_clock.dart';

void main() {
  group('WatchPartyClock', () {
    test('serverNow follows the observed offset', () {
      var local = DateTime.utc(2026, 1, 1, 12);
      final clock = WatchPartyClock(now: () => local);
      // The server timestamp is two seconds ahead of the local clock.
      clock.observe(local.add(const Duration(seconds: 2)));
      expect(clock.serverNow, local.add(const Duration(seconds: 2)));

      local = local.add(const Duration(minutes: 1));
      expect(clock.serverNow, local.add(const Duration(seconds: 2)));
    });

    test('keeps the largest sample so network delay cannot drag it back', () {
      var local = DateTime.utc(2026, 1, 1, 12);
      final clock = WatchPartyClock(now: () => local);
      clock.observe(local.add(const Duration(seconds: 3)));
      // A slower delivery looks like a smaller offset; it must not win.
      clock.observe(local.add(const Duration(milliseconds: 500)));
      expect(clock.offset, const Duration(seconds: 3));
    });

    test('re-learns the offset after a stale sample', () {
      var local = DateTime.utc(2026, 1, 1, 12);
      final clock = WatchPartyClock(now: () => local);
      clock.observe(local.add(const Duration(seconds: 5)));
      expect(clock.offset, const Duration(seconds: 5));

      local = local.add(const Duration(minutes: 30));
      clock.observe(local.subtract(const Duration(seconds: 1)));
      expect(clock.offset, const Duration(seconds: -1));
    });

    test('clamps an absurd offset instead of jumping the video', () {
      var local = DateTime.utc(2026, 1, 1, 12);
      final clock = WatchPartyClock(now: () => local);
      clock.observe(local.add(const Duration(hours: 2)));
      expect(clock.offset, WatchPartyClock.maxOffset);
    });

    test('offsetSeconds mirrors the offset', () {
      var local = DateTime.utc(2026, 1, 1, 12);
      final clock = WatchPartyClock(now: () => local);
      clock.observe(local.add(const Duration(milliseconds: 1500)));
      expect(clock.offsetSeconds, closeTo(1.5, 0.001));
    });
  });
}
