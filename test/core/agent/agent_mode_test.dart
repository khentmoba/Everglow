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

    test('routeAliases covers core destinations including anime and manga', () {
      expect(AgentMode.routeAliases['cinema'], '/cinema');
      expect(AgentMode.routeAliases['anime'], '/anime');
      expect(AgentMode.routeAliases['manga'], '/manga');
      expect(AgentMode.routeAliases['mangacelestia'], '/manga');
      expect(AgentMode.routeAliases['books'], '/books');
      expect(AgentMode.routeAliases['bibliotheca'], '/books');
      expect(AgentMode.routeAliases['dashboard'], '/dashboard');
      expect(AgentMode.routeAliases['sanctuary'], '/sanctuary');
      expect(AgentMode.routeAliases['gallery'], '/gallery');
      expect(AgentMode.routeAliases['journal'], '/journal');
      expect(AgentMode.routeAliases['play-zone'], '/play-zone');
    });

    test(
      'canonical production domains reject activation and clear restored state',
      () async {
        expect(AgentMode.isProductionHost('everglow-1c6db.web.app'), isTrue);
        expect(
          AgentMode.isProductionHost('everglow-1c6db.firebaseapp.com'),
          isTrue,
        );
        expect(
          AgentMode.isProductionHost('everglow-1c6db--pr-123.web.app'),
          isFalse,
        );
        expect(AgentMode.isLocalHost('localhost'), isTrue);

        expect(AgentMode.enable(host: 'everglow-1c6db.web.app'), isFalse);
        expect(AgentMode.isActive.value, isFalse);
        SharedPreferences.setMockInitialValues({
          'everglow_agent_mode_active': true,
          'everglow_agent_mode_profile': 'clairjassen',
        });
        await AgentMode.init(
          queryParameters: {'agent': 'clair'},
          host: 'everglow-1c6db.firebaseapp.com',
        );
        final prefs = await SharedPreferences.getInstance();
        expect(AgentMode.isActive.value, isFalse);
        expect(prefs.containsKey('everglow_agent_mode_active'), isFalse);
        expect(prefs.containsKey('everglow_agent_mode_profile'), isFalse);
      },
    );

    test('logout cleanup removes persisted agent state', () async {
      SharedPreferences.setMockInitialValues({
        'everglow_agent_mode_active': true,
        'everglow_agent_mode_profile': 'clairjassen',
      });
      AgentMode.enable(profile: 'clairjassen', host: 'localhost');
      await AgentMode.clearPersistedState();
      final prefs = await SharedPreferences.getInstance();
      expect(AgentMode.isActive.value, isFalse);
      expect(prefs.containsKey('everglow_agent_mode_active'), isFalse);
      expect(prefs.containsKey('everglow_agent_mode_profile'), isFalse);
    });

    test(
      'query activation remains available on localhost and PR previews',
      () async {
        expect(AgentMode.enable(host: 'localhost'), isTrue);
        AgentMode.disable();
        await AgentMode.init(
          queryParameters: {'agent': 'cinema'},
          host: 'everglow-1c6db--pr-123.web.app',
        );
        expect(AgentMode.isActive.value, isTrue);
        expect(AgentMode.activeProfile.value, 'breyan');
      },
    );

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
    test('chat senders match the simulated profiles for both bubble sides', () {
      expect(
        AgentFixtures.demoChatMessages.map((message) => message.sender).toSet(),
        {'khentsgdz', 'clairjassen'},
      );
      for (final message in AgentFixtures.demoChatMessages) {
        expect(message.senderUid, 'agent_${message.sender}_uid');
      }
    });

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
