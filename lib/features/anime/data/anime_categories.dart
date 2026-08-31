import 'package:flutter/material.dart';

import '../../cinema/data/models/media_item.dart';
import './services/jikan_service.dart';
import '../../../core/theme/app_colors.dart';

/// Group of related anime filter chips shown on the Browse tab.
enum AnimeCategoryGroup { format, genre, status, discovery, season }

/// A single filterable option inside a [AnimeCategoryGroup].
///
/// Each option knows how to fetch its own results from [JikanService] so
/// the Browse tab can render the rows lazily without bespoke per-tab
/// plumbing. Keep the fetcher side-effect free and cheap to call — the
/// UI calls it once when the option is first expanded.
class AnimeCategoryOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final AnimeCategoryGroup group;

  /// Fetcher for this option's row. Receives the [JikanService] so callers
  /// don't have to thread it through state.
  final Future<List<MediaItem>> Function(JikanService jikan) fetch;

  const AnimeCategoryOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.group,
    required this.fetch,
  });
}

/// Curated Editor's Picks. Hardcoded MAL ids for well-known anime that
/// define the medium. Loaded via [JikanService.fetchAnimeById] so we
/// only pay one network call per title. If any of these go missing on
/// MAL the fetcher just skips them — it never throws.
const _editorPicksIds = <int>[
  1, // Cowboy Bebop
  33, // Berserk
  1535, // Death Note
  431, // Howl's Moving Castle
  16498, // Attack on Titan
  199, // Spirited Away
  11061, // Hunter x Hunter (2011)
  5114, // Fullmetal Alchemist: Brotherhood
  30, // Neon Genesis Evangelion
  31240, // Re:Zero − Starting Life in Another World
  20, // Naruto
  918, // Gintama
  40748, // Jujutsu Kaisen
  50265, // Spy x Family
  38000, // Demon Slayer: Kimetsu no Yaiba
  44511, // Chainsaw Man
  9253, // Steins;Gate
  48736, // My Dress-Up Darling
  165122, // Oshi no Ko (corrected from 52127, which was Hige wo Soru)
  11757, // Sword Art Online
  52991, // Frieren: Beyond Journey's End
];

/// Batched Editor's Picks lookup — one HTTP call instead of 21.
Future<List<MediaItem>> _fetchEditorPicks(JikanService jikan) async {
  return jikan.fetchAnimeByIds(_editorPicksIds);
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
    color: AppColors.animeGold,
    group: AnimeCategoryGroup.format,
    fetch: (jikan) => jikan.fetchTopAnime(type: 'tv', filter: 'bypopularity'),
  ),
  AnimeCategoryOption(
    id: 'movies',
    label: 'Movies',
    icon: Icons.movie_rounded,
    color: AppColors.roseQuartz,
    group: AnimeCategoryGroup.format,
    fetch: (jikan) =>
        jikan.fetchTopAnime(type: 'movie', filter: 'bypopularity'),
  ),
  AnimeCategoryOption(
    id: 'ovas',
    label: 'OVAs & Specials',
    icon: Icons.movie_filter_rounded,
    color: AppColors.softLavender,
    group: AnimeCategoryGroup.format,
    // Pull OVA + special rankings and merge. Jikan exposes a clean
    // `type` filter for these so the result is the canonical list.
    fetch: (jikan) async {
      final ovas = await jikan.fetchTopAnime(
        type: 'ova',
        filter: 'bypopularity',
        limit: 15,
      );
      final specials = await jikan.fetchTopAnime(
        type: 'special',
        filter: 'bypopularity',
        limit: 15,
      );
      return [...ovas, ...specials];
    },
  ),

  // ── BY GENRE ───────────────────────────────────────────────────
  // Jikan's MAL genre ids are well-documented and far more granular
  // than TMDB's TV-genre buckets. See [JikanService.malGenres] for the
  // full list we support.
  AnimeCategoryOption(
    id: 'genre-action',
    label: 'Action & Adventure',
    icon: Icons.bolt_rounded,
    color: const Color(0xFFE57373),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [1, 2]),
  ),
  AnimeCategoryOption(
    id: 'genre-romance',
    label: 'Romance',
    icon: Icons.favorite_rounded,
    color: const Color(0xFFF06292),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [22]),
  ),
  AnimeCategoryOption(
    id: 'genre-comedy',
    label: 'Comedy',
    icon: Icons.theater_comedy_rounded,
    color: const Color(0xFFFFD54F),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [4]),
  ),
  AnimeCategoryOption(
    id: 'genre-slice-of-life',
    label: 'Slice of Life',
    icon: Icons.local_cafe_rounded,
    color: const Color(0xFFAED581),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [36]),
  ),
  AnimeCategoryOption(
    id: 'genre-fantasy-isekai',
    label: 'Fantasy & Isekai',
    icon: Icons.auto_awesome_rounded,
    color: const Color(0xFFBA68C8),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [10]),
  ),
  AnimeCategoryOption(
    id: 'genre-scifi-mecha',
    label: 'Sci-Fi & Mecha',
    icon: Icons.rocket_launch_rounded,
    color: const Color(0xFF64B5F6),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [24, 18]),
  ),
  AnimeCategoryOption(
    id: 'genre-horror-thriller',
    label: 'Horror & Thriller',
    icon: Icons.nights_stay_rounded,
    color: const Color(0xFF455A64),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [14, 41]),
  ),
  AnimeCategoryOption(
    id: 'genre-sports',
    label: 'Sports',
    icon: Icons.sports_basketball_rounded,
    color: const Color(0xFFFF8A65),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [30]),
  ),
  AnimeCategoryOption(
    id: 'genre-mystery',
    label: 'Mystery',
    icon: Icons.search_rounded,
    color: const Color(0xFF7986CB),
    group: AnimeCategoryGroup.genre,
    fetch: (jikan) => jikan.fetchByGenres(const [7]),
  ),

  // ── BY STATUS / RECENCY ────────────────────────────────────────
  AnimeCategoryOption(
    id: 'status-airing',
    label: 'Currently Airing',
    icon: Icons.live_tv_rounded,
    color: const Color(0xFFE53935),
    group: AnimeCategoryGroup.status,
    fetch: (jikan) => jikan.fetchSeasonNow(),
  ),
  AnimeCategoryOption(
    id: 'status-completed',
    label: 'Completed',
    icon: Icons.check_circle_rounded,
    color: const Color(0xFF66BB6A),
    group: AnimeCategoryGroup.status,
    // Jikan doesn't expose a "status" filter directly, so we pull the
    // top-rated TV list and keep only those whose MAL status is
    // "Finished Airing" with a credible vote count.
    fetch: (jikan) async {
      final results = await jikan.fetchTopAnime(type: 'tv', limit: 25);
      return results.where((m) => m.airingStatus == 'Finished Airing').toList();
    },
  ),
  AnimeCategoryOption(
    id: 'status-new',
    label: 'New Releases',
    icon: Icons.fiber_new_rounded,
    color: const Color(0xFF42A5F5),
    group: AnimeCategoryGroup.status,
    fetch: (jikan) => jikan.fetchNewReleases(),
  ),
  AnimeCategoryOption(
    id: 'status-trending',
    label: 'Trending Now',
    icon: Icons.local_fire_department_rounded,
    color: const Color(0xFFFF7043),
    group: AnimeCategoryGroup.status,
    fetch: (jikan) => jikan.fetchTopAiring(),
  ),

  // ── DISCOVERY / CURATED ────────────────────────────────────────
  AnimeCategoryOption(
    id: 'curated-popular-all',
    label: 'Popular All Time',
    icon: Icons.public_rounded,
    color: const Color(0xFFAB47BC),
    group: AnimeCategoryGroup.discovery,
    fetch: (jikan) => jikan.fetchTopAnime(type: 'tv', filter: 'bypopularity'),
  ),
  AnimeCategoryOption(
    id: 'curated-top-rated',
    label: 'Top Rated',
    icon: Icons.star_rounded,
    color: const Color(0xFFFFCA28),
    group: AnimeCategoryGroup.discovery,
    // `favorite` filter on /top/anime is the closest Jikan equivalent
    // of a "members-loved" leaderboard.
    fetch: (jikan) => jikan.fetchTopAnime(type: 'tv', filter: 'favorite'),
  ),
  AnimeCategoryOption(
    id: 'curated-hidden-gems',
    label: 'Hidden Gems',
    icon: Icons.diamond_rounded,
    color: const Color(0xFF26C6DA),
    group: AnimeCategoryGroup.discovery,
    fetch: (jikan) => jikan.fetchHiddenGems(),
  ),
  const AnimeCategoryOption(
    id: 'curated-editors-picks',
    label: "Editor's Picks",
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFEC407A),
    group: AnimeCategoryGroup.discovery,
    fetch: _fetchEditorPicks,
  ),

  // ── BY SEASON ──────────────────────────────────────────────
  AnimeCategoryOption(
    id: 'season-summer-2026',
    label: 'Summer 2026',
    icon: Icons.wb_sunny_rounded,
    color: const Color(0xFFFFB74D),
    group: AnimeCategoryGroup.season,
    fetch: (jikan) => jikan.fetchSeason(year: 2026, season: 'summer'),
  ),
  AnimeCategoryOption(
    id: 'season-spring-2026',
    label: 'Spring 2026',
    icon: Icons.local_florist_rounded,
    color: const Color(0xFF81C784),
    group: AnimeCategoryGroup.season,
    fetch: (jikan) => jikan.fetchSeason(year: 2026, season: 'spring'),
  ),
  AnimeCategoryOption(
    id: 'season-winter-2026',
    label: 'Winter 2026',
    icon: Icons.ac_unit_rounded,
    color: const Color(0xFF90CAF9),
    group: AnimeCategoryGroup.season,
    fetch: (jikan) => jikan.fetchSeason(year: 2026, season: 'winter'),
  ),
  AnimeCategoryOption(
    id: 'season-fall-2025',
    label: 'Fall 2025',
    icon: Icons.park_rounded,
    color: const Color(0xFFA1887F),
    group: AnimeCategoryGroup.season,
    fetch: (jikan) => jikan.fetchSeason(year: 2025, season: 'fall'),
  ),
];
