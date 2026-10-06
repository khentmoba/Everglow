import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:everglow/core/agent/agent_mode.dart';
import 'package:everglow/core/agent/agent_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentMode', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      AgentMode.disable();
    });

    test('parses profile query parameter correctly', () {
      expect(AgentMode.parseProfile('1'), 'khentsgdz');
      expect(AgentMode.parseProfile('true'), 'khentsgdz');
      expect(AgentMode.parseProfile('khent'), 'khentsgdz');
      expect(AgentMode.parseProfile('clair'), 'clairjassen');
      expect(AgentMode.parseProfile('clairjassen'), 'clairjassen');
      expect(AgentMode.parseProfile('cinema'), 'breyan');
      expect(AgentMode.parseProfile('breyan'), 'breyan');
    });

    test('enable and switchProfile update active state and profile', () {
      expect(AgentMode.isActive.value, isFalse);

      AgentMode.enable(profile: 'khentsgdz');
      expect(AgentMode.isActive.value, isTrue);
      expect(AgentMode.activeProfile.value, 'khentsgdz');

      AgentMode.switchProfile('clairjassen');
      expect(AgentMode.activeProfile.value, 'clairjassen');
      expect(AgentMode.isActive.value, isTrue);

      AgentMode.disable();
      expect(AgentMode.isActive.value, isFalse);
    });

    test('init parses query parameters and enables agent mode', () async {
      await AgentMode.init(queryParameters: {'agent': 'clair'});
      expect(AgentMode.isActive.value, isTrue);
      expect(AgentMode.activeProfile.value, 'clairjassen');
    });
  });

  group('AgentFixtures', () {
    test('provides non-empty demo fixtures for all surfaces', () {
      expect(AgentFixtures.demoMilestones, isNotEmpty);
      expect(AgentFixtures.demoNotes, isNotEmpty);
      expect(AgentFixtures.demoGardenStats.totalInteractions, greaterThan(0));
      expect(AgentFixtures.demoStars, isNotEmpty);
      expect(AgentFixtures.demoBucketList, isNotEmpty);
      expect(AgentFixtures.demoEvents, isNotEmpty);
      expect(AgentFixtures.demoDecision.options, isNotEmpty);
      expect(AgentFixtures.demoJournalEntries, isNotEmpty);
      expect(AgentFixtures.demoChatMessages, isNotEmpty);
      expect(AgentFixtures.demoPhotos, isNotEmpty);
      expect(AgentFixtures.demoDateIdeas, isNotEmpty);
      expect(AgentFixtures.demoGuardianMessages, isNotEmpty);
    });
  });
}
