import 'dart:async';

import 'package:everglow/features/dashboard/presentation/widgets/dashboard_load_tracker.dart';
import 'package:everglow/features/dashboard/presentation/widgets/xp_progress_section.dart';
import 'package:everglow/features/xp/domain/models/user_progress.dart';
import 'package:everglow/features/xp/presentation/widgets/xp_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

UserProgress _progress(String uid) => UserProgress(
  uid: uid,
  xpTotal: 120,
  level: 3,
  streak: 4,
  lastActivity: DateTime.utc(2026, 9, 18),
);

Future<void> _pumpXp(
  WidgetTester tester,
  DashboardLoadTracker tracker, {
  required String? uid,
  required Stream<UserProgress?> Function(String uid)? watchProgress,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: tracker,
          child: XpProgressSection(uid: uid, watchProgress: watchProgress),
        ),
      ),
    ),
  );
}

void main() {
  group('XpProgressSection stars load signal', () {
    testWidgets('does NOT mark on optimistic first paint', (tester) async {
      final tracker = DashboardLoadTracker();
      addTearDown(tracker.dispose);
      final controller = StreamController<UserProgress?>();
      addTearDown(controller.close);

      await _pumpXp(
        tester,
        tracker,
        uid: 'xp-optimistic',
        watchProgress: (_) => controller.stream,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The zero-state bar paints instantly, but Firestore has said
      // nothing — the veil percent must not move.
      expect(tracker.done, 0);

      // The first real snapshot settles it.
      controller.add(_progress('xp-optimistic'));
      await tester.pump();
      await tester.pump();

      expect(tracker.done, 1);
    });

    testWidgets('marks when Firestore answers "no doc" (null)', (tester) async {
      final tracker = DashboardLoadTracker();
      addTearDown(tracker.dispose);
      final controller = StreamController<UserProgress?>();
      addTearDown(controller.close);

      await _pumpXp(
        tester,
        tracker,
        uid: 'xp-null-doc',
        watchProgress: (_) => controller.stream,
      );
      await tester.pump();
      expect(tracker.done, 0);

      // Null is a real answer ("no doc yet"), not a guess — it counts.
      // (Seeding runs in the background; the zero-state paint is truthful.)
      controller.add(null);
      await tester.pump();
      await tester.pump();

      expect(tracker.done, 1);
    });

    testWidgets('marks only after retries are exhausted on failure', (
      tester,
    ) async {
      final tracker = DashboardLoadTracker();
      addTearDown(tracker.dispose);
      // Broadcast: every silent retry re-listens to the stream.
      final controller = StreamController<UserProgress?>.broadcast();
      addTearDown(controller.close);

      await _pumpXp(
        tester,
        tracker,
        uid: 'xp-failing',
        watchProgress: (_) => controller.stream,
      );
      await tester.pump();

      // Four failed attempts (initial + 3 retries over 2+3+4s). None of
      // the transient failures may move the veil.
      controller.addError(StateError('offline'));
      await tester.pump();
      expect(tracker.done, 0);

      // Attempt 2 fails after the 2s backoff — still retrying.
      await tester.pump(const Duration(seconds: 2));
      controller.addError(StateError('offline'));
      await tester.pump();
      expect(tracker.done, 0);

      // Attempt 3 fails after the 3s backoff — still retrying.
      await tester.pump(const Duration(seconds: 3));
      controller.addError(StateError('offline'));
      await tester.pump();
      expect(tracker.done, 0);

      // Attempt 4 fails after the 4s backoff — budget spent, final.
      // The error state is settled, so the veil can stop waiting even
      // though no XP arrived (the optimistic bar stays on screen).
      await tester.pump(const Duration(seconds: 4));
      controller.addError(StateError('offline'));
      await tester.pump();
      await tester.pump();
      expect(tracker.done, 1);
      expect(find.byType(XPProgressBar), findsOneWidget);
    });

    testWidgets('marks settled-empty when there is no uid to load', (
      tester,
    ) async {
      final tracker = DashboardLoadTracker();
      addTearDown(tracker.dispose);

      await _pumpXp(
        tester,
        tracker,
        uid: null,
        watchProgress: (_) => const Stream.empty(),
      );
      await tester.pump();
      await tester.pump();

      // Nothing to fetch and the card renders empty — settled, not stuck.
      expect(tracker.done, 1);
    });
  });
}
