import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/daily_bloom/data/models/garden_stats.dart';
import 'package:everglow/features/daily_bloom/data/services/garden_service.dart';
import 'package:everglow/features/daily_bloom/presentation/providers/garden_provider.dart';

class FakeGardenSource implements GardenStatsSource {
  final List<Stream<GardenStats>> scripted;
  final List<Stream<GardenStats>> partnerScripted;
  int watchCalls = 0;
  int partnerWatchCalls = 0;
  int interactions = 0;
  Object? interactionError;
  Object? plantTypeError;

  FakeGardenSource(this.scripted, {this.partnerScripted = const []});

  @override
  Stream<GardenStats> watchStats(String userId) {
    final index = watchCalls < scripted.length ? watchCalls : scripted.length - 1;
    watchCalls++;
    return scripted[index];
  }

  @override
  Stream<GardenStats> watchPartnerStats(String partnerUid) {
    if (partnerScripted.isEmpty) return const Stream.empty();
    final index = partnerWatchCalls < partnerScripted.length
        ? partnerWatchCalls
        : partnerScripted.length - 1;
    partnerWatchCalls++;
    return partnerScripted[index];
  }

  @override
  Future<void> recordInteraction(String userId) async {
    interactions++;
    if (interactionError != null) throw interactionError!;
  }

  @override
  Future<void> setPlantType(String userId, String plantType) async {
    if (plantTypeError != null) throw plantTypeError!;
  }
}

GardenStats _stats() => GardenStats(
  currentStage: 3,
  lastVisit: DateTime.utc(2026, 9, 5),
  streakCount: 2,
  totalInteractions: 10,
  plantType: 'rose',
);

Future<void> _settle() => Future<void>.delayed(
  const Duration(milliseconds: 50),
);

void main() {
  group('GardenProvider', () {
    test('exposes stats from the garden stream', () async {
      final provider = GardenProvider(
        service: FakeGardenSource([Stream.value(_stats())]),
      );

      provider.updateUserId('uid-1');
      await _settle();

      expect(provider.stats?.currentStage, 3);
      expect(provider.stats?.plantType, 'rose');
      expect(provider.hasError, isFalse);
      provider.dispose();
    });

    test('stream error surfaces hasError and manual retry recovers', () async {
      final provider = GardenProvider(
        service: FakeGardenSource([
          Stream.error(StateError('permission-denied')),
          Stream.value(_stats()),
        ]),
      );

      provider.updateUserId('uid-1');
      await _settle();

      expect(provider.stats, isNull);
      expect(provider.hasError, isTrue);

      provider.retry();
      await _settle();

      expect(provider.stats?.currentStage, 3);
      expect(provider.hasError, isFalse);
      expect(provider.stats?.plantType, 'rose');
      provider.dispose();
    });

    test('stream closing without data surfaces hasError', () async {
      final provider = GardenProvider(
        service: FakeGardenSource([const Stream<GardenStats>.empty()]),
      );

      provider.updateUserId('uid-1');
      await _settle();

      expect(provider.stats, isNull);
      expect(provider.hasError, isTrue);
      provider.dispose();
    });

    test('updateUserId(null) clears stats without subscribing', () async {
      final source = FakeGardenSource([Stream.value(_stats())]);
      final provider = GardenProvider(service: source);

      provider.updateUserId('uid-1');
      await _settle();
      expect(provider.stats, isNotNull);

      provider.updateUserId(null);
      expect(provider.stats, isNull);
      expect(provider.hasError, isFalse);
      expect(source.watchCalls, 1);
      provider.dispose();
    });

    test('recordInteraction and setPlantType never throw', () async {
      final provider = GardenProvider(
        service: FakeGardenSource([Stream.value(_stats())])
          ..interactionError = StateError('offline')
          ..plantTypeError = StateError('offline'),
      );

      provider.updateUserId('uid-1');
      await _settle();

      await expectLater(provider.recordInteraction(), completes);
      await expectLater(provider.setPlantType('rose'), completes);
      provider.dispose();
    });

    test('watchPartner updates partner stats and stopWatchingPartner clears', () async {
      final partnerStats = GardenStats(
        currentStage: 4,
        lastVisit: DateTime.utc(2026, 9, 8),
        streakCount: 5,
        totalInteractions: 50,
        plantType: 'tulip',
      );
      final provider = GardenProvider(
        service: FakeGardenSource(
          [Stream.value(_stats())],
          partnerScripted: [Stream.value(partnerStats)],
        ),
      );

      provider.watchPartner('partner-uid-1');
      await _settle();

      expect(provider.partnerUid, 'partner-uid-1');
      expect(provider.partnerStats?.currentStage, 4);
      expect(provider.partnerStats?.plantType, 'tulip');

      provider.stopWatchingPartner();
      expect(provider.partnerUid, isNull);
      expect(provider.partnerStats, isNull);
      provider.dispose();
    });

    test('watchPartner retries on stream error and preserves last known stats', () async {
      final partnerStats = GardenStats(
        currentStage: 2,
        lastVisit: DateTime.utc(2026, 9, 8),
        streakCount: 3,
        totalInteractions: 20,
        plantType: 'sunflower',
      );
      final partnerStats2 = GardenStats(
        currentStage: 3,
        lastVisit: DateTime.utc(2026, 9, 9),
        streakCount: 4,
        totalInteractions: 25,
        plantType: 'sunflower',
      );
      final controller = StreamController<GardenStats>.broadcast();
      final source = FakeGardenSource(
        [Stream.value(_stats())],
        partnerScripted: [
          controller.stream,
          Stream.value(partnerStats2),
        ],
      );
      final provider = GardenProvider(service: source);

      provider.watchPartner('partner-uid-1');
      controller.add(partnerStats);
      await _settle();

      expect(provider.partnerStats?.currentStage, 2);
      expect(provider.partnerStats?.plantType, 'sunflower');
      expect(provider.hasPartnerError, isFalse);

      // Inject error into active partner stream
      controller.addError(StateError('transient-error'));
      await _settle();

      // Last known stats are preserved across errors
      expect(provider.partnerStats?.currentStage, 2);

      // Manual retry reconnects and gets new stream
      provider.retryPartner();
      await _settle();
      expect(source.partnerWatchCalls, 2);
      expect(provider.partnerStats?.currentStage, 3);
      expect(provider.hasPartnerError, isFalse);

      await controller.close();
      provider.dispose();
    });
  });
}
