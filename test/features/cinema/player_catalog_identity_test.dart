import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cinema membership and optimistic state never compare bare numeric IDs',
    () {
      final screen = File(
        'lib/features/cinema/presentation/screens/cinema_screen.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'\.tmdbId\s*[!=]=\s*item\.tmdbId').hasMatch(screen),
        isFalse,
      );
      expect(screen, contains('OptimisticSet<String>'));
      expect(screen, contains('reconcile(items.map((e) => e.catalogKey))'));
    },
  );

  test('both players use the saved title source for resume and heartbeat', () {
    for (final path in [
      'lib/features/cinema/presentation/screens/video_player_state_base.dart',
      'lib/features/cinema/presentation/screens/video_player_screen_native.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final calls = RegExp(
        r'(?:getSavedProgress|heartbeatProgress)\([\s\S]*?\);',
      ).allMatches(source);
      expect(calls, isNotEmpty, reason: path);
      for (final call in calls) {
        expect(
          call.group(0),
          contains("source: widget.isAnime ? 'jikan' : 'tmdb'"),
          reason:
              'MAL anime must never resume or update a colliding TMDB title',
        );
        expect(call.group(0), contains('mediaType: widget.mediaType'));
      }
    }
  });
}
