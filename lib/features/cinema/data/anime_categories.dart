import 'package:flutter/material.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';

/// Group of related anime filter chips shown on the Browse tab.
enum AnimeCategoryGroup { format, genre, status, discovery }

/// A single filterable option inside a [AnimeCategoryGroup].
///
/// Each option knows how to fetch its own results from [TMDBService] so
/// the Browse tab can render the rows lazily without bespoke per-tab
/// plumbing. Keep the fetcher side-effect free and cheap to call — the
/// UI calls it once when the option is first expanded.
class AnimeCategoryOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final AnimeCategoryGroup group;

  /// Fetcher for this option's row. Receives the [TMDBService] so callers
  /// don't have to thread it through state.
  final Future<List<MediaItem>> Function(TMDBService tmdb) fetch;

  const AnimeCategoryOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.group,
    required this.fetch,
  });
}

/// Curated Editor's Picks. Hardcoded TMDB IDs for well-known anime that
/// define the medium. Loaded via [TMDBService.fetchMediaDetails] so we
/// only pay one network call per title. If any of these go missing on
/// TMDB the fetcher just skips them — it never throws.
const _editorPicksIds = <int>[
  21, // Cowboy Bebop
  269, // Berserk
  1535, // Death Note
  1100, // Howl's Moving Castle
  49387, // Attack on Titan
  129, // Spirited Away
  20958, // Hunter x Hunter (2011)
  31910, // Fullmetal Alchemist: Brotherhood
  31911, // Neon Genesis Evangelion
  38073, // Re:Zero − Starting Life in Another World
  1425, // Naruto
  31109, // Gintama
  154587, // Jujutsu Kaisen
  120089, // Spy x Family
  95403, // Demon Slayer
  127369, // Chainsaw Man
  20994, // Steins;Gate
  129713, // My Dress-Up Darling
  215907, // Oshi no Ko
  21966, // Sword Art Online
  114472, // Frieren: Beyond Journey's End
];

Future<List<MediaItem>> _fetchEditorPicks(TMDBService tmdb) async {
  final responses = await Future.wait(
    _editorPicksIds.map((id) async {
      try {
        return await tmdb.fetchMediaDetails(id, 'tv');
      } catch (_) {
        return null;
      }
    }),
  );
  return responses.whereType<Map<String, dynamic>>().map((d) {
    final posterPath = d['poster_path'];
    final releaseDate = d['first_air_date'] ?? d['release_date'] ?? '';
    final year = releaseDate.toString().length >= 4
        ? releaseDate.toString().substring(0, 4)
        : '';
    return MediaItem(
      id: '',
      tmdbId: d['id'] ?? 0,
      title: d['name'] ?? d['original_name'] ?? 'Unknown Title',
      mediaType: 'tv',
      posterPath:
          posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '',
      backdropPath: d['backdrop_path'] != null
          ? 'https://image.tmdb.org/t/p/original${d['backdrop_path']}'
          : '',
      year: year,
      status: 'to-watch',
      isAnime: true,
      userName: '',
      addedAt: DateTime.now(),
    );
  }).toList();
}

/// The four groups of categories rendered on the Browse tab. The UI
/// reads this list to draw section headers + filter chips; tapping a
/// chip triggers [AnimeCategoryOption.fetch] to render its results
/// inline below the chip row.
final List<AnimeCategoryOption> animeCategoryOptions = [
  // ── BY FORMAT ──────────────────────────────────────────────────
  AnimeCategoryOption(
    id: 'series',
    label: 'Series',
    icon: Icons.tv_rounded,
    color: const Color(0xFFE8C97A),
    group: AnimeCategoryGroup.format,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      voteCountGte: 20,
    ),
  ),
  AnimeCategoryOption(
    id: 'movies',
    label: 'Movies',
    icon: Icons.movie_rounded,
    color: const Color(0xFFF4C2C2),
    group: AnimeCategoryGroup.format,
    fetch: (tmdb) => tmdb.discoverAnimeMovies(
      sortBy: 'popularity.desc',
      voteCountGte: 30,
    ),
  ),
  AnimeCategoryOption(
    id: 'ovas',
    label: 'OVAs & Specials',
    icon: Icons.movie_filter_rounded,
    color: const Color(0xFFD4B5D6),
    group: AnimeCategoryGroup.format,
    // Keyword 12279 = "ova" on TMDB; pipe to keyword 2851 ("special").
    // Limited vote count because OVA catalog is small.
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withKeywords: const [12279, 2851],
      voteCountGte: 5,
    ),
  ),

  // ── BY GENRE ───────────────────────────────────────────────────
  // TMDB's TV Animation sub-genres we can map to the user's labels.
  // Some of these (Romance, Slice of Life, Sports) get re-tagged as
  // "Drama" on TMDB's side; we keep the user's labels but add a small
  // hint in the UI so the result still feels accurate.
  AnimeCategoryOption(
    id: 'genre-action',
    label: 'Action & Adventure',
    icon: Icons.bolt_rounded,
    color: const Color(0xFFE57373),
    group: AnimeCategoryGroup.genre,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [10759],
      voteCountGte: 30,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-romance',
    label: 'Romance',
    icon: Icons.favorite_rounded,
    color: const Color(0xFFF06292),
    group: AnimeCategoryGroup.genre,
    // TMDB doesn't have a "Romance" TV genre (10749 is movie-only), so
    // we use Drama (18) as the closest match for romance anime. We
    // also OR in keyword 9673 ("love") for tighter signal.
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [18],
      withKeywords: const [9673],
      voteCountGte: 20,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-comedy',
    label: 'Comedy',
    icon: Icons.theater_comedy_rounded,
    color: const Color(0xFFFFD54F),
    group: AnimeCategoryGroup.genre,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [35],
      voteCountGte: 20,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-slice-of-life',
    label: 'Slice of Life',
    icon: Icons.local_cafe_rounded,
    color: const Color(0xFFAED581),
    group: AnimeCategoryGroup.genre,
    // Drama is the closest TMDB genre for SOL anime.
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [18],
      voteCountGte: 10,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-fantasy-isekai',
    label: 'Fantasy & Isekai',
    icon: Icons.auto_awesome_rounded,
    color: const Color(0xFFBA68C8),
    group: AnimeCategoryGroup.genre,
    // Sci-Fi & Fantasy (10765) on TMDB covers both isekai and
    // traditional fantasy anime. The keyword 13311 ("isekai") tightens
    // the top results.
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [10765],
      withKeywords: const [13311],
      voteCountGte: 20,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-scifi-mecha',
    label: 'Sci-Fi & Mecha',
    icon: Icons.rocket_launch_rounded,
    color: const Color(0xFF64B5F6),
    group: AnimeCategoryGroup.genre,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [10765],
      voteCountGte: 30,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-horror-thriller',
    label: 'Horror & Thriller',
    icon: Icons.nights_stay_rounded,
    color: const Color(0xFF455A64),
    group: AnimeCategoryGroup.genre,
    // TMDB folds horror/thriller anime into Mystery (9648) and Crime
    // (80). We OR both to widen the net.
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [9648, 80],
      voteCountGte: 10,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-sports',
    label: 'Sports',
    icon: Icons.sports_basketball_rounded,
    color: const Color(0xFFFF8A65),
    group: AnimeCategoryGroup.genre,
    // TMDB TV has no dedicated sports genre, but most sports anime get
    // tagged Drama + a Sports keyword. Keyword 6075 ("sport") on TMDB.
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [18],
      withKeywords: const [6075],
      voteCountGte: 5,
    ),
  ),
  AnimeCategoryOption(
    id: 'genre-mystery',
    label: 'Mystery',
    icon: Icons.search_rounded,
    color: const Color(0xFF7986CB),
    group: AnimeCategoryGroup.genre,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      withGenres: const [9648],
      voteCountGte: 20,
    ),
  ),

  // ── BY STATUS / RECENCY ────────────────────────────────────────
  AnimeCategoryOption(
    id: 'status-airing',
    label: 'Currently Airing',
    icon: Icons.live_tv_rounded,
    color: const Color(0xFFE53935),
    group: AnimeCategoryGroup.status,
    // TMDB status 0 == "Returning Series". Bounded by the last 12
    // months so we don't surface ancient shows that are technically
    // still "returning".
    fetch: (tmdb) {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 365))
          .toIso8601String()
          .substring(0, 10);
      return tmdb.discoverAnime(
        sortBy: 'popularity.desc',
        withStatus: 0,
        firstAirDateGte: cutoff,
        voteCountGte: 5,
      );
    },
  ),
  AnimeCategoryOption(
    id: 'status-completed',
    label: 'Completed',
    icon: Icons.check_circle_rounded,
    color: const Color(0xFF66BB6A),
    group: AnimeCategoryGroup.status,
    // TMDB status 3 == "Ended".
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'vote_average.desc',
      withStatus: 3,
      voteCountGte: 200,
    ),
  ),
  AnimeCategoryOption(
    id: 'status-new',
    label: 'New Releases',
    icon: Icons.fiber_new_rounded,
    color: const Color(0xFF42A5F5),
    group: AnimeCategoryGroup.status,
    fetch: (tmdb) {
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 180))
          .toIso8601String()
          .substring(0, 10);
      return tmdb.discoverAnime(
        sortBy: 'first_air_date.desc',
        firstAirDateGte: cutoff,
        voteCountGte: 5,
      );
    },
  ),
  AnimeCategoryOption(
    id: 'status-trending',
    label: 'Trending Now',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFFF7043),
    group: AnimeCategoryGroup.status,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      voteCountGte: 20,
    ),
  ),

  // ── DISCOVERY / CURATED ────────────────────────────────────────
  AnimeCategoryOption(
    id: 'curated-popular-all',
    label: 'Popular All Time',
    icon: Icons.public_rounded,
    color: const Color(0xFFAB47BC),
    group: AnimeCategoryGroup.discovery,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'popularity.desc',
      voteCountGte: 500,
    ),
  ),
  AnimeCategoryOption(
    id: 'curated-top-rated',
    label: 'Top Rated',
    icon: Icons.star_rounded,
    color: const Color(0xFFFFCA28),
    group: AnimeCategoryGroup.discovery,
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'vote_average.desc',
      voteCountGte: 200,
    ),
  ),
  AnimeCategoryOption(
    id: 'curated-hidden-gems',
    label: 'Hidden Gems',
    icon: Icons.diamond_rounded,
    color: const Color(0xFF26C6DA),
    group: AnimeCategoryGroup.discovery,
    // High rating but few votes = crowd hasn't found it yet.
    fetch: (tmdb) => tmdb.discoverAnime(
      sortBy: 'vote_average.desc',
      voteCountGte: 10,
      voteCountLte: 250,
      voteAverageGte: 7.5,
    ),
  ),
  AnimeCategoryOption(
    id: 'curated-editors-picks',
    label: "Editor's Picks",
    icon: Icons.workspace_premium_rounded,
    color: const Color(0xFFEC407A),
    group: AnimeCategoryGroup.discovery,
    fetch: _fetchEditorPicks,
  ),
];
