import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/shared/widgets/everglow/everglow_background.dart';

// Model types for extra parameter casting
import '../../features/manga/data/models/manga_item.dart';
import '../../features/academy/models/academy_question.dart';
import '../../features/academy/models/game_match.dart';

import '../../features/watch_party/data/models/watch_party_room.dart';
import '../../features/books/data/models/book_item.dart';
import '../../features/books/data/models/book_search_result.dart';
import '../../features/daily_bloom/presentation/widgets/shared_garden_view.dart';
import '../../features/bucket_list/presentation/screens/bucket_list_screen.dart';

import '../../features/entry/presentation/pages/gateway_page.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/cinema/presentation/screens/cinema_screen.dart';
import '../../features/cinema/presentation/screens/video_player_screen.dart';
import '../../features/cinema/presentation/screens/anime_screen.dart';
import '../../features/books/presentation/screens/books_screen.dart';
import '../../features/books/presentation/screens/book_detail_screen.dart';
import '../../features/books/presentation/screens/our_books_screen.dart';
import '../../features/books/presentation/screens/reader_screen.dart';
import '../../features/manga/presentation/screens/katana_home_screen.dart';
import '../../features/manga/presentation/screens/manga_reader_screen.dart';
import '../../features/academy/screens/academy_hub_screen.dart';
import '../../features/academy/screens/game_board_screen.dart';
import '../../features/academy/screens/solo_study_screen.dart';
import '../../features/academy/screens/podium_screen.dart';
import '../../features/play_zone/presentation/screens/play_zone_hub_screen.dart';
import '../../features/play_zone/table_tennis/presentation/screens/table_tennis_game_screen.dart';
import '../../features/play_zone/table_tennis/presentation/screens/tt_multiplayer_lobby_screen.dart';
import '../../features/canvas/presentation/screens/canvas_screen.dart';
import '../../features/dashboard/presentation/screens/letterbox_archive_screen.dart';
import '../../features/chat/presentation/screens/sanctuary_chat_screen.dart';
import '../../features/starlight_jar/presentation/screens/starlight_jar_widget.dart';
import '../../features/watch_party/presentation/screens/watch_party_screen.dart';
import '../../features/jellyfin/presentation/screens/party_downloads_screen.dart';
import '../../features/ai/presentation/widgets/mochi_screen.dart';
import '../../features/ai/presentation/screens/memory_book_screen.dart';
import '../../features/ai/presentation/screens/memory_trivia_screen.dart';
import '../../features/ai/presentation/screens/mochi_today_screen.dart';
import '../../features/gallery/presentation/screens/gallery_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';

/// App-wide router configuration.
///
/// Simple routes use URL parameters. Complex object routes use `extra`.
/// Navigation examples:
///   context.go('/dashboard')
///   context.push('/cinema/video/123?title=Foo&type=movie')
///   context.push('/books/reader', extra: bookItem)
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    // ── Gateway (passcode entry) ──────────────────────────
    GoRoute(path: '/', builder: (_, _) => const GatewayPage()),

    // ── Dashboard ─────────────────────────────────────────
    GoRoute(
      path: '/dashboard',
      builder: (_, state) => DashboardScreen(animate: state.extra == true),
    ),

    // ── Cinema ────────────────────────────────────────────
    GoRoute(
      path: '/cinema',
      builder: (_, state) => CinemaScreen(
        initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
      ),
      routes: [
        GoRoute(
          path: 'video/:id',
          builder: (_, state) => VideoPlayerScreen(
            tmdbId: int.tryParse(state.pathParameters['id'] ?? '0') ?? 0,
            mediaType: state.uri.queryParameters['type'] ?? 'movie',
            title: state.uri.queryParameters['title'] ?? '',
            season: int.tryParse(state.uri.queryParameters['season'] ?? ''),
            episode: int.tryParse(state.uri.queryParameters['episode'] ?? ''),
            isAnime: state.uri.queryParameters['anime'] == 'true',
            malId: int.tryParse(state.uri.queryParameters['malId'] ?? ''),
          ),
        ),
      ],
    ),

    // ── Anime ─────────────────────────────────────────────
    GoRoute(path: '/anime', builder: (_, _) => const AnimeScreen()),

    // ── Books ─────────────────────────────────────────────
    GoRoute(
      path: '/books',
      builder: (_, _) => const BooksScreen(),
      routes: [
        GoRoute(
          path: 'reader',
          builder: (_, state) => ReaderScreen(book: state.extra! as BookItem),
        ),
        GoRoute(
          path: 'detail',
          builder: (_, state) => BookDetailScreen(
            args: state.extra! as BookDetailArgs,
          ),
        ),
        GoRoute(
          path: 'listen',
          builder: (_, state) => ReaderScreen(
            book: state.extra! as BookItem,
            startListening: true,
          ),
        ),
      ],
    ),

    // ── Our Books (couple shared) ─────────────────────────
    GoRoute(path: '/our-books', builder: (_, _) => const OurBooksScreen()),

    // ── Manga ─────────────────────────────────────────────
    GoRoute(
      path: '/manga',
      builder: (_, _) => const KatanaHomeScreen(),
      routes: [
        GoRoute(
          path: 'reader',
          builder: (_, state) {
            final args = state.extra! as MangaReaderArgs;
            return MangaReaderScreen(
              manga: args.manga,
              chapter: args.chapter,
              allChapters: args.allChapters,
            );
          },
        ),
      ],
    ),

    // ── Academy ───────────────────────────────────────────
    GoRoute(
      path: '/academy',
      builder: (_, _) => const AcademyHubScreen(),
      routes: [
        GoRoute(
          path: 'solo',
          builder: (_, state) {
            final args = state.extra! as SoloStudyArgs;
            return SoloStudyScreen(
              questions: args.questions,
              category: args.category,
            );
          },
        ),
        GoRoute(
          path: 'match',
          builder: (_, state) {
            final args = state.extra! as GameBoardArgs;
            return GameBoardScreen(
              matchId: args.matchId,
              userId: args.userId,
              questions: args.questions,
            );
          },
        ),
        GoRoute(
          path: 'podium',
          builder: (_, state) => PodiumScreen(match: state.extra! as GameMatch),
        ),
      ],
    ),

    // ── Play Zone ─────────────────────────────────────────
    GoRoute(
      path: '/play-zone',
      builder: (_, _) => const PlayZoneHubScreen(),
      routes: [
        GoRoute(path: 'tt', builder: (_, _) => const TableTennisGameScreen()),
        GoRoute(
          path: 'tt/lobby',
          builder: (_, _) => const TTMultiplayerLobbyScreen(),
        ),
      ],
    ),

    // ── Canvas (collaborative drawing) ────────────────────
    GoRoute(path: '/canvas', builder: (_, _) => const CanvasScreen()),

    // ── Letterbox Archive ─────────────────────────────────
    GoRoute(
      path: '/letterbox',
      builder: (_, _) => const LetterboxArchiveScreen(),
    ),

    // ── Sanctuary (couple chat) ───────────────────────────
    GoRoute(path: '/sanctuary', builder: (_, _) => const SanctuaryChatScreen()),

    // ── Mochi AI assistant ────────────────────────────────
    GoRoute(path: '/mochi', builder: (_, _) => const MochiScreen()),

    // Mochi Memory Book, trivia, and daily recap
    GoRoute(path: '/mochi-memory', builder: (_, _) => const MemoryBookScreen()),
    GoRoute(path: '/mochi-trivia', builder: (_, _) => const MemoryTriviaScreen()),
    GoRoute(path: '/mochi-today', builder: (_, _) => const MochiTodayScreen()),

    // ── Starlight Jar ─────────────────────────────────────
    GoRoute(path: '/starlight', builder: (_, _) => const _StarlightPage()),

    // ── Shared Garden ─────────────────────────────────────
    GoRoute(path: '/garden', builder: (_, _) => const SharedGardenView()),

    // ── Bucket List ───────────────────────────────────────
    GoRoute(path: '/bucket-list', builder: (_, _) => const BucketListScreen()),

    // ── Memory Gallery ─────────────────────────────────────
    GoRoute(path: '/gallery', builder: (_, _) => const GalleryScreen()),

    // ── Shared Calendar ─────────────────────────────────────
    GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),

    // ── Watch Party ───────────────────────────────────────
    GoRoute(
      path: '/watch-party',
      builder: (_, state) {
        final args = state.extra! as WatchPartyArgs;
        return WatchPartyScreen(initialRoom: args.room, isHost: args.isHost);
      },
    ),

    // Jellyfin party library: search and download a movie to host.
    GoRoute(
      path: '/party-downloads',
      builder: (_, _) => const PartyDownloadsScreen(),
    ),
  ],

  // ── Error page ──────────────────────────────────────────
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: const Color(0xFF1A1A2E),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 64,
            color: Color(0xFFF4C2C2),
          ),
          const SizedBox(height: 24),
          Text(
            'Page not found',
            style: TextStyle(
              fontFamily: 'Cormorant Garamond',
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF4C2C2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.uri.toString(),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: const Color(0xFFFFF5F5).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => GoRouter.of(context).go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2185B),
              foregroundColor: const Color(0xFFFFF5F5),
            ),
            child: const Text('Go home'),
          ),
        ],
      ),
    ),
  ),
);

// ── Argument classes for complex object routes ────────────

/// Args for MangaReaderScreen (complex object, can't be URL params).
class MangaReaderArgs {
  final MangaItem manga;
  final MangaChapter chapter;
  final List<MangaChapter> allChapters;

  MangaReaderArgs({
    required this.manga,
    required this.chapter,
    required this.allChapters,
  });
}

/// Page shell for the standalone Starlight Jar route so it keeps the
/// shared atmospheric background (the widget itself is also embedded
/// directly inside the dashboard).
class _StarlightPage extends StatelessWidget {
  const _StarlightPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: const [
                RadialGlow(
                  color: AppColors.auroraLilac,
                  alignment: Alignment(-0.6, -0.9),
                  size: 0.9,
                  opacity: 0.14,
                ),
                RadialGlow(
                  color: AppColors.blushGold,
                  alignment: Alignment(0.9, 0.8),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
              showPetals: true,
            ),
          ),
          const StarlightJarWidget(),
        ],
      ),
    );
  }
}

/// Args for SoloStudyScreen.
class SoloStudyArgs {
  final List<AcademyQuestion> questions;
  final String category;

  SoloStudyArgs({required this.questions, required this.category});
}

/// Args for GameBoardScreen.
class GameBoardArgs {
  final String matchId;
  final String userId;
  final List<AcademyQuestion> questions;

  GameBoardArgs({
    required this.matchId,
    required this.userId,
    required this.questions,
  });
}

/// Args for WatchPartyScreen.
class WatchPartyArgs {
  final WatchPartyRoom room;
  final bool isHost;

  WatchPartyArgs({required this.room, required this.isHost});
}
