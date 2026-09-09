import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/daily_bloom/data/models/garden_stats.dart';
import 'package:everglow/features/daily_bloom/data/services/garden_service.dart';
import 'package:everglow/features/daily_bloom/presentation/providers/garden_provider.dart';
import 'package:everglow/features/daily_bloom/presentation/widgets/daily_bloom.dart';
import 'package:everglow/features/daily_bloom/presentation/widgets/garden_plant_view.dart';

class _FakeSource implements GardenStatsSource {
  final GardenStats stats;
  _FakeSource(this.stats);

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
  GardenProvider provider, {
  bool attachUser = true,
}) async {
  if (attachUser) provider.updateUserId('uid-1');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChangeNotifierProvider.value(
            value: provider,
            child: const DailyBloom(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // NOTE: no pumpAndSettle — the weather overlay breathes forever.
  group('DailyBloom sanctuary card', () {
    testWidgets('shows plant, growth, stats, and actions', (tester) async {
      final provider = GardenProvider(service: _FakeSource(_stats()));
      addTearDown(provider.dispose);

      await _pumpGarden(tester, provider);

      expect(find.text('Our Garden'), findsWidgets);
      expect(find.text('Lily · Opening bloom'), findsOneWidget);
      expect(
        find.text('Stage 3 of 5 · Opening bloom'),
        findsOneWidget,
      );
      expect(find.text('10'), findsOneWidget);
      expect(find.text('650'), findsOneWidget);
      expect(find.text('day streak'), findsOneWidget);
      expect(find.text('visits'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('loading state asks for a moment', (tester) async {
      final provider = GardenProvider(service: _FakeSource(_stats()));
      addTearDown(provider.dispose);

      await _pumpGarden(tester, provider, attachUser: false);

      expect(find.text('waking the garden…'), findsOneWidget);
    });

    testWidgets('tapping the plant shows its story', (tester) async {
      final provider = GardenProvider(service: _FakeSource(_stats()));
      addTearDown(provider.dispose);

      await _pumpGarden(tester, provider);

      expect(find.text('Opening bloom'), findsNothing);
      await tester.tap(find.byType(GardenPlantView));
      await tester.pump();
      // Tooltip appears near the top of the scene; the stage story reads out.
      expect(find.text('Opening bloom'), findsOneWidget);
      // Let the tooltip's 3s auto-dismiss timer expire before teardown.
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
