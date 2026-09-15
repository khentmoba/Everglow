import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/presentation/widgets/dashboard_load_tracker.dart';

void main() {
  group('DashboardLoadTracker', () {
    test('starts at 0% with the door label', () {
      final tracker = DashboardLoadTracker();
      expect(tracker.progress, 0.0);
      expect(tracker.isComplete, isFalse);
      expect(tracker.done, 0);
      expect(tracker.total, DashboardLoadTracker.signals.length);
      expect(tracker.currentLabel, 'opening the door…');
      tracker.dispose();
    });

    test('progress climbs only on real marks, one step per signal', () {
      final tracker = DashboardLoadTracker();
      final total = tracker.total;
      var marked = 0;
      for (final signal in DashboardLoadTracker.signals) {
        tracker.mark(signal);
        marked++;
        expect(tracker.done, marked);
        expect(tracker.progress, closeTo(marked / total, 1e-9));
      }
      expect(tracker.isComplete, isTrue);
      tracker.dispose();
    });

    test('marks are idempotent and unknown keys are ignored', () {
      final tracker = DashboardLoadTracker();
      tracker.mark(DashboardLoadSignal.garden);
      tracker.mark(DashboardLoadSignal.garden);
      tracker.mark('offscreen-section-12');
      expect(tracker.done, 1);
      expect(tracker.progress, closeTo(1 / tracker.total, 1e-9));
      expect(tracker.isComplete, isFalse);
      tracker.dispose();
    });

    test('label always names the first still-pending signal', () {
      final tracker = DashboardLoadTracker();
      tracker.mark(DashboardLoadSignal.auth);
      expect(tracker.currentLabel, 'gathering memories…');
      tracker.mark(DashboardLoadSignal.memories);
      tracker.mark(DashboardLoadSignal.dates);
      tracker.mark(DashboardLoadSignal.letters);
      expect(tracker.currentLabel, 'waking the garden…');
      tracker.dispose();
    });

    test('notifies listeners exactly once per new signal', () {
      final tracker = DashboardLoadTracker();
      var calls = 0;
      tracker.addListener(() => calls++);
      tracker.mark(DashboardLoadSignal.auth);
      tracker.mark(DashboardLoadSignal.auth);
      tracker.mark('nope');
      expect(calls, 1);
      tracker.dispose();
    });
  });
}
