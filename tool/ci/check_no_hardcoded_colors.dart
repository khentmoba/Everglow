// Hardcoded-colour ratchet: no new `Color(0x...)` literals in lib/ outside the
// palette. A literal in a widget bypasses lib/core/theme/app_colors.dart, so
// the next theme change misses it. Existing literals are pinned per file in
// _pinned and may only go down. Removing one means lowering that file's number
// in the same commit; adding one fails the check.
//
// Palette files (lib/core/theme/, *_tokens.dart, *_colors.dart, *_theme.dart)
// define the colours themselves and are not counted.
//
// Usage: dart tool/ci/check_no_hardcoded_colors.dart
import 'dart:io';

import '_io.dart';

final _literal = RegExp(r'Color\(0x');

bool _isPaletteFile(String path) =>
    path.startsWith('lib/core/theme/') ||
    path.endsWith('_tokens.dart') ||
    path.endsWith('_colors.dart') ||
    path.endsWith('_theme.dart');

/// file -> pinned count of `Color(0x` literals. Must match the scan exactly.
const Map<String, int> _pinned = {
  'lib/features/academy/presentation/screens/podium_screen.dart': 1,
  'lib/features/academy/presentation/widgets/trivia_loading_overlay.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_badges.dart': 4,
  'lib/features/anime/presentation/widgets/animex/animex_buttons.dart': 2,
  'lib/features/anime/presentation/widgets/animex/animex_home_page.dart': 2,
  'lib/features/anime/presentation/widgets/animex/animex_motchi_sidebar.dart': 2,
  'lib/features/anime/presentation/widgets/animex/animex_mylist_page.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_nav.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_player_native.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_player_web.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_playlist_detail_page.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_playlists_page.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_poster_card.dart': 3,
  'lib/features/anime/presentation/widgets/animex/animex_poster_row.dart': 2,
  'lib/features/anime/presentation/widgets/animex/animex_skeleton.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_spotlight.dart': 4,
  'lib/features/anime/presentation/widgets/animex/animex_watch_page.dart': 1,
  'lib/features/anime/presentation/widgets/animex/animex_watch_page_episodes.dart': 3,
  'lib/features/books/presentation/routes/books_routes.dart': 1,
  'lib/features/books/presentation/screens/our_books_screen.dart': 3,
  'lib/features/books/presentation/screens/reader_widgets.dart': 1,
  'lib/features/books/presentation/widgets/book_categories.dart': 5,
  'lib/features/calendar/presentation/widgets/day_detail_sheet.dart': 1,
  'lib/features/cinema/data/cinema_browse_config.dart': 38,
  'lib/features/cinema/presentation/widgets/episode_drawer_sections/cinema/cinema_hero.dart': 2,
  'lib/features/cinema/presentation/widgets/netflix/netflix_billboard.dart': 5,
  'lib/features/cinema/presentation/widgets/netflix/netflix_hover_preview.dart': 1,
  'lib/features/dashboard/presentation/widgets/currently_watching_preview.dart': 1,
  'lib/features/dashboard/presentation/widgets/dashboard_load_veil.dart': 1,
  'lib/features/dashboard/presentation/widgets/note_dialog.dart': 1,
  'lib/features/dashboard/presentation/widgets/shelf_widgets.dart': 11,
  'lib/features/jukebox/presentation/widgets/jukebox_widget.dart': 1,
  'lib/features/jukebox/presentation/widgets/spotify_connect_card.dart': 3,
  'lib/features/jukebox/presentation/widgets/stats_leaderboard_header.dart': 6,
  'lib/features/jukebox/presentation/widgets/stats_track_rows.dart': 23,
  'lib/features/manga/presentation/katana/katana_header.dart': 1,
  'lib/features/manga/presentation/katana/reader_settings_sheet.dart': 4,
  'lib/features/manga/presentation/screens/katana_reader_screen.dart': 1,
  'lib/features/manga/presentation/screens/manga_reader_screen.dart': 2,
  'lib/features/play_zone/presentation/screens/chess_game_widgets.dart': 16,
  'lib/features/play_zone/presentation/widgets/web_overlay_button.dart': 2,
  'lib/features/play_zone/table_tennis/presentation/screens/tt_multiplayer_lobby_screen.dart': 1,
  'lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart': 2,
  'lib/features/starlight_jar/presentation/widgets/note_display_dialog.dart': 1,
  'lib/features/watch_party/presentation/widgets/watch_party_card.dart': 4,
  'lib/shared/widgets/app_network_image.dart': 2,
};

Future<void> main() async {
  final counts = <String, int>{};
  final files = await Directory('lib')
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .cast<File>()
      .toList();

  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (_isPaletteFile(path)) continue;
    final hits = _literal.allMatches(await readTolerant(file)).length;
    if (hits > 0) counts[path] = hits;
  }

  final failures = <String>[];
  final paths = {...counts.keys, ..._pinned.keys}.toList()..sort();
  for (final path in paths) {
    final now = counts[path] ?? 0;
    final pinned = _pinned[path] ?? 0;
    if (now == pinned) continue;
    if (now > pinned) {
      failures.add(
        '  $path: $now literal(s), pinned at $pinned. Use a colour from '
        'lib/core/theme/app_colors.dart or a feature token file instead.',
      );
    } else if (now == 0) {
      failures.add('  $path: no literals left. Remove its _pinned entry.');
    } else {
      failures.add(
        '  $path: $now literal(s), pinned at $pinned. Lower its _pinned '
        'entry to $now.',
      );
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln(
      '[hardcoded-colors] FAIL: colour literals must come from the palette. '
      'Fix each file below, or update its _pinned entry only when the count '
      'went down.\n${failures.join('\n')}',
    );
    exit(1);
  }
  final pinnedTotal = counts.values.fold(0, (sum, n) => sum + n);
  stdout.writeln(
    '[hardcoded-colors] OK: $pinnedTotal pinned literal(s) outside the '
    'palette, 0 new.',
  );
}
