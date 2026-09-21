import 'package:everglow/features/daily_bloom/data/models/garden_stats.dart';
import 'package:everglow/features/daily_bloom/data/services/garden_service.dart';
import 'package:everglow/features/daily_bloom/presentation/providers/garden_provider.dart';
import 'package:everglow/features/daily_bloom/presentation/widgets/daily_bloom.dart';
import 'package:everglow/features/dashboard/presentation/widgets/dashboard_load_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Always fails: every subscribe (initial + every retry) errors, so the
/// provider walks its whole retry budget and ends exhausted.
class _FailingSource implements GardenStatsSource {
  @override
  Stream<GardenStats> watchStats(String userId) =>
      Stream<GardenStats>.error(StateError('offline'));

  @override
  Stream<GardenStats> watchPartnerStats(String partnerUid) =>
      const Stream.empty();

  @override
  Future<void> recordInteraction(String userId) async {}

  @override
  Future<void> setPlantType(String userId, String plantType) async {}
}

class _ValueSource implements GardenStatsSource {
  final GardenStats stats;
  _ValueSource(this.stats);

  @override
  Stream<GardenStats> watchStats(String userId) => Stream.value(stats);

  @override
  Stream<GardenStats> watchPartnerStats(String partnerUid) =>
      const Stream.empty();

  @override
  Future<void> recordInteraction(String userId) async {}

  @override
  Future<void> setPlantType(String userId, String plantType) async {}
}

GardenStats _stats() => GardenStats(
  currentStage: 3,
  lastVisit: DateTime.utc(2026, 9, 5),
  streakCount: 10,
  totalInteractions: 650,
  plantType: 'lily',
);

Future<void> _pumpGarden(
  WidgetTester tester,
  GardenProvider provider,
  DashboardLoadTracker tracker,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChangeNotifierProvider.value(
            value: tracker,
            child: ChangeNotifierProvider.value(
              value: provider,
              child: const DailyBloom(),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // NOTE: no pumpAndSettle — the weather overlay breathes forever.
  group('DailyBloom garden load signal', () {
    testWidgets('marks the veil only when stats really arrive', (tester) async {
      final provider = GardenProvider(service: _ValueSource(_stats()));
      addTearDown(provider.dispose);
      final tracker = DashboardLoadTracker();
      addTearDown(tracker.dispose);
      provider.updateUserId('uid-1');

      await _pumpGarden(tester, provider, tracker);
      await tester.pump();
      // Stream value delivered; the post-frame mark ran.
      await tester.pump();

      expect(provider.stats, isNotNull);
      expect(tracker.done, 1);
      expect(tracker.progress, closeTo(1 / 6, 0.001));
    });

    testWidgets('does NOT mark on a transient error with retries pending', (
      tester,
    ) async {
      final provider = GardenProvider(service: _FailingSource());
      addTearDown(provider.dispose);
      final tracker = DashboardLoadTracker();
      addTearDown(tracker.dispose);
      provider.updateUserId('uid-1');

      await _pumpGarden(tester, provider, tracker);
      await tester.pump();
      await tester.pump();

      // The card shows its error state, but a retry is already scheduled —
      // nothing settled, so the veil percent must not move.
      expect(provider.hasError, isTrue);
      expect(provider.hasSettledError, isFalse);
      expect(find.text('Garden unavailable — retry'), findsOneWidget);
      expect(tracker.done, 0);

      // Walk the whole retry budget (2+3+4+5+6s): each elapse fires one
      // retry timer, each flush delivers that attempt's error.
      for (final seconds in [2, 3, 4, 5, 6]) {
        await tester.pump(Duration(seconds: seconds));
        await tester.pump();
      }
      // Exhausted notification rebuilds, then the post-frame mark runs.
      await tester.pump();
      await tester.pump();

      expect(provider.hasSettledError, isTrue);
      expect(tracker.done, 1);
    });
  });
}
