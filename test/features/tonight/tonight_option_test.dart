import 'package:flutter_test/flutter_test.dart';
import 'package:everglow/features/tonight/data/models/tonight_option.dart';

void main() {
  group('TonightOption Model', () {
    test('parses full map correctly', () {
      final map = {
        'id': 'opt_movie_123',
        'type': 'movie',
        'title': 'Spirited Away',
        'subtitle': 'From Cinema Watchlist',
        'description': 'A magical anime adventure.',
        'imageUrl': 'https://image.tmdb.org/t/p/w342/poster.jpg',
        'targetRoute': '/cinema',
      };

      final option = TonightOption.fromMap(map, 'opt_movie_123');

      expect(option.id, 'opt_movie_123');
      expect(option.type, TonightOptionType.movie);
      expect(option.title, 'Spirited Away');
      expect(option.subtitle, 'From Cinema Watchlist');
      expect(option.description, 'A magical anime adventure.');
      expect(option.imageUrl, 'https://image.tmdb.org/t/p/w342/poster.jpg');
      expect(option.targetRoute, '/cinema');
    });

    test('handles null and corrupted map gracefully', () {
      final optionFromNull = TonightOption.fromMap(null);
      expect(optionFromNull.id, 'opt_fallback');
      expect(optionFromNull.title, 'Cozy Evening Together');
      expect(optionFromNull.type, TonightOptionType.date);

      final optionFromGarbage = TonightOption.fromMap({
        'type': 12345,
        'title': null,
        'description': false,
      }, 'fallback_id');

      expect(optionFromGarbage.id, 'fallback_id');
      expect(optionFromGarbage.type, TonightOptionType.date);
      expect(optionFromGarbage.title, 'Untitled Activity');
    });

    test('toMap serializes properly', () {
      const option = TonightOption(
        id: 'opt_game_1',
        type: TonightOptionType.game,
        title: 'Scribble Together',
        subtitle: 'Arcade',
        description: 'Draw and guess together',
        targetRoute: '/play-zone/scribble',
      );

      final map = option.toMap();
      expect(map['id'], 'opt_game_1');
      expect(map['type'], 'game');
      expect(map['title'], 'Scribble Together');
      expect(map['targetRoute'], '/play-zone/scribble');
      expect(map.containsKey('imageUrl'), isFalse);
    });
  });
}
