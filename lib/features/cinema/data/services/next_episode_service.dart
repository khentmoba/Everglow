import '../models/next_episode.dart';
import 'tmdb_service.dart';

/// Resolves the episode after the one Clair is watching.
///
/// The player calls [resolve] on load and on every episode change so the
/// Up Next card and the persistent Next button always know where "next"
/// goes — including the jump from a season finale to the next season's
/// premiere. Returns null for the very last episode of a show.
class NextEpisodeService {
  final TMDBService _tmdb;

  NextEpisodeService({TMDBService? tmdb}) : _tmdb = tmdb ?? TMDBService();

  Future<NextEpisode?> resolve({
    required int tmdbId,
    required int season,
    required int episode,
  }) async {
    // Same season first — one cheap call covers the common case.
    final current = await _tmdb.fetchSeasonEpisodes(tmdbId, season);
    final sameSeason = nextInSeason(
      season: season,
      currentEpisode: episode,
      episodes: current,
    );
    if (sameSeason != null) return sameSeason;

    // Season finale — find the next season, then its first episode.
    final details = await _tmdb.fetchTVShowDetails(tmdbId);
    if (details == null) return null;
    final rawSeasons = (details['seasons'] as List?) ?? [];
    final numbers = <int>[];
    for (final raw in rawSeasons) {
      if (raw is! Map) continue;
      final num = raw['season_number'];
      if (num is int) numbers.add(num);
    }
    final nextSeason = nextSeasonNumber(
      currentSeason: season,
      seasonNumbers: numbers,
    );
    if (nextSeason == null) return null;
    final nextEps = await _tmdb.fetchSeasonEpisodes(tmdbId, nextSeason);
    return firstInSeason(season: nextSeason, episodes: nextEps);
  }

  /// Estimated episode length in minutes, used to schedule the Up Next
  /// fallback timer on providers that never report playback position
  /// (Everglow / CineSrc). Returns null when TMDB has no runtime — the
  /// caller falls back to a sensible default.
  Future<int?> fetchEpisodeRuntime({required int tmdbId}) async {
    final details = await _tmdb.fetchTVShowDetails(tmdbId);
    if (details == null) return null;
    final runTimes = details['episode_run_time'] as List?;
    if (runTimes == null || runTimes.isEmpty) return null;
    final first = runTimes.first;
    if (first is int && first > 0) return first;
    if (first is num && first.toInt() > 0) return first.toInt();
    return null;
  }
}
