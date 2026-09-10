import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/dashboard/data/services/creator_service.dart';
import 'package:everglow/features/dashboard/presentation/widgets/creator_modal.dart';
import 'package:everglow/features/dashboard/domain/models/hidden_note.dart';
import 'package:everglow/features/dashboard/domain/models/milestone.dart';
import 'package:everglow/features/guardian/data/models/guardian_message.dart';

/// Offline fake: no Firebase, no network. Each stream returns empty so the
/// modal can be pumped in isolation per the regression-guard policy.
class _FakeCreatorService extends CreatorService {
  _FakeCreatorService() : super();

  @override
  Stream<List<HiddenNote>> watchHiddenNotes({int limit = 50}) =>
      Stream.value(const []);

  @override
  Stream<List<Milestone>> watchMilestones({int limit = 30}) =>
      Stream.value(const []);

  @override
  Stream<List<GuardianMessage>> watchGuardianWhispers({int limit = 10}) =>
      Stream.value(const []);

  @override
  Stream<Map<String, dynamic>?> watchTonightFeature() =>
      Stream.value(null);

  @override
  Future<Map<String, dynamic>> fetchHealthStatus() async => {
        'status': 'offline',
        'message': 'test fake',
      };
}

void main() {
  testWidgets('every creator tab has a matching panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: CreatorModal(creatorService: _FakeCreatorService()),
          ),
        ),
      ),
    );

    // Four Dusk Petal tabs.
    expect(find.text('Letters'), findsOneWidget);
    expect(find.text('Memories'), findsOneWidget);
    expect(find.text('Surprises'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // System panel keeps the legacy 'System Tools' header.
    expect(find.text('System Tools'), findsNothing);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(find.text('System Tools'), findsOneWidget);

    // Surprises panel: Guardian Whisperer + Date Night Spotlight.
    await tester.tap(find.text('Surprises'));
    await tester.pumpAndSettle();
    expect(find.text('Guardian Whisperer'), findsOneWidget);
    expect(find.text('Date Night Spotlight'), findsOneWidget);

    // Memories panel: composer with live preview + multi-photo support.
    await tester.tap(find.text('Memories'));
    await tester.pumpAndSettle();
    expect(find.text('Live Card Preview'), findsOneWidget);

    // Letters panel: composer + vault.
    await tester.tap(find.text('Letters'));
    await tester.pumpAndSettle();
    expect(find.text('Compose'), findsOneWidget);
    expect(find.text('Vault & Scheduled'), findsOneWidget);
  });
}
