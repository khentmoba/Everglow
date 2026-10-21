import 'package:everglow/features/tonight/data/models/tonight_decision.dart';
import 'package:everglow/features/tonight/data/models/tonight_option.dart';
import 'package:everglow/features/tonight/data/models/tonight_preferences.dart';
import 'package:everglow/features/tonight/data/services/tonight_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/firestore_test_fakes.dart';

void main() {
  test('short quiet evenings avoid movies and competitive games', () async {
    final service = TonightService(db: TestFirestore(TestCollection()));
    final picks = await service.generateSuggestions(
      preferences: const TonightPreferences(minutes: 30),
    );
    expect(picks, hasLength(3));
    expect(picks.map((p) => p.id).toSet(), hasLength(3));
    expect(picks.every((p) => p.type != TonightOptionType.movie), isTrue);
    expect(
      picks.map((p) => p.targetRoute),
      containsAll(['/sanctuary', '/canvas', '/jukebox']),
    );
  });

  test('going out never offers indoor media or games', () {
    for (final energy in EveningEnergy.values) {
      final picks = TonightService.localSuggestions(
        TonightPreferences(goingOut: true, energy: energy),
      );
      expect(picks, hasLength(3));
      expect(
        picks.every(
          (p) =>
              p.type == TonightOptionType.date && p.subtitle.contains('Go out'),
        ),
        isTrue,
      );
    }
  });

  test(
    'timed movie choices exclude unknown and excessive running times',
    () async {
      final service = TonightService(
        db: TestFirestore(
          TestCollection(
            entries: [
              {'title': 'Unknown duration', 'tmdbId': 1, 'mediaType': 'movie'},
              {
                'title': 'Too long',
                'tmdbId': 2,
                'mediaType': 'movie',
                'durationSeconds': 7200,
              },
              {
                'title': 'Fits tonight',
                'tmdbId': 3,
                'mediaType': 'movie',
                'durationSeconds': 5100,
              },
            ],
          ),
        ),
      );
      final pick = await service.fetchMovieSuggestion(maxMinutes: 90);
      expect(pick.title, 'Fits tonight');
      expect(Uri.parse(pick.targetRoute!).path, '/cinema/video/3');
    },
  );

  test(
    'a timed evening with no suitable film uses an activity instead',
    () async {
      final service = TonightService(
        db: TestFirestore(
          TestCollection(
            entries: [
              {'title': 'Unknown', 'tmdbId': 1, 'mediaType': 'movie'},
            ],
          ),
        ),
      );
      expect(
        (await service.fetchMovieSuggestion(maxMinutes: 90)).type,
        isNot(TonightOptionType.movie),
      );
    },
  );

  test('movie deep links preserve title punctuation safely', () {
    final uri = Uri.parse(
      TonightService.movieRoute({'tmdbId': 42, 'title': 'A & B? #1'}),
    );
    expect(uri.path, '/cinema/video/42');
    expect(uri.queryParameters['title'], 'A & B? #1');
    expect(uri.queryParameters['type'], 'movie');
  });

  test('shared preferences round trip while old decisions keep defaults', () {
    final now = DateTime.now();
    final decision = TonightDecision(
      id: 'today',
      createdAt: now,
      updatedAt: now,
      preferences: const TonightPreferences(
        minutes: 45,
        goingOut: true,
        energy: EveningEnergy.adventurous,
      ),
    );
    final restored = TonightDecision.fromMap(decision.toMap());
    expect(restored.preferences.minutes, 45);
    expect(restored.preferences.goingOut, isTrue);
    expect(restored.preferences.energy, EveningEnergy.adventurous);
    expect(TonightDecision.fromMap({}).preferences.minutes, isNull);
  });
}
