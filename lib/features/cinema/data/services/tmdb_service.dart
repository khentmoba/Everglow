import '../../../../core/utils/connectivity_aware.dart';
import '../../../../core/utils/error_aware.dart';
import '../models/media_item.dart';
import './tmdb/tmdb_cache_service.dart';
import './tmdb/tmdb_details_service.dart';
import './tmdb/tmdb_discovery_service.dart';
import './tmdb/tmdb_poster_service.dart';
import './tmdb/tmdb_search_service.dart';
import './tmdb/tmdb_trailer_service.dart';
import './tmdb/tmdb_watchlist_service.dart';

/// Public facade over the focused TMDB sub-services.
///
/// All existing call-sites that use `TMDBService()` continue to work
/// unchanged — every method is forwarded to the appropriate sub-service.
/// Sub-services are also exposed as getters for callers that need direct
/// access (e.g. stream subscriptions).
class TMDBService with ConnectivityAware, ErrorAware {
  // ─── Sub-services ──────────────────────────────────────────────────────

  late final TMDBDiscoveryService _discovery;
  late final TMDBSearchService _search;
  late final TMDBDetailsService _details;
  late final TMDBPosterService _poster;
  late final TMDBWatchlistService _watchlist;
  late final TMDBCacheService _cache;
  late final TMDBTrailerService _trailer;

  // ─── Sub-service getters ───────────────────────────────────────────────

  TMDBDiscoveryService get discovery => _discovery;
  TMDBSearchService get search => _search;
  TMDBDetailsService get details => _details;
  TMDBPosterService get poster => _poster;
  TMDBWatchlistService get watchlist => _watchlist;
  TMDBCacheService get cache => _cache;
  TMDBTrailerService get trailer => _trailer;

  // ─── Singleton ─────────────────────────────────────────────────────────

  static final TMDBService _instance = TMDBService._internal();
  factory TMDBService() => _instance;
  TMDBService._internal() {
    _details = TMDBDetailsService();
    _cache = TMDBCacheService();
    _discovery = TMDBDiscoveryService();
    _search = TMDBSearchService();
    _poster = TMDBPosterService(_details);
    _watchlist = TMDBWatchlistService(_cache);
    _trailer = TMDBTrailerService();
  }

  // ─── Discovery ─────────────────────────────────────────────────────────

  Future<List<MediaItem>> fetchTrendingAnime() =>
      _discovery.fetchTrendingAnime();

  Future<List<MediaItem>> discoverAnime({
    String? sortBy,
    List<int>? withGenres,
    List<int>? withKeywords,
    int? withStatus,
    String? airDateGte,
    String? airDateLte,
    String? firstAirDateGte,
    String? firstAirDateLte,
    int? voteCountGte,
    int? voteCountLte,
    double? voteAverageGte,
    int page = 1,
  }) => _discovery.discoverAnime(
    sortBy: sortBy,
    withGenres: withGenres,
    withKeywords: withKeywords,
    withStatus: withStatus,
    airDateGte: airDateGte,
    airDateLte: airDateLte,
    firstAirDateGte: firstAirDateGte,
    firstAirDateLte: firstAirDateLte,
    voteCountGte: voteCountGte,
    voteCountLte: voteCountLte,
    voteAverageGte: voteAverageGte,
    page: page,
  );

  Future<List<MediaItem>> discoverAnimeMovies({
    String? sortBy,
    String? primaryReleaseDateGte,
    String? primaryReleaseDateLte,
    int? voteCountGte,
    int page = 1,
  }) => _discovery.discoverAnimeMovies(
    sortBy: sortBy,
    primaryReleaseDateGte: primaryReleaseDateGte,
    primaryReleaseDateLte: primaryReleaseDateLte,
    voteCountGte: voteCountGte,
    page: page,
  );

  Future<List<MediaItem>> fetchTrending({
    String region = 'all',
    String timeWindow = 'week',
  }) => _discovery.fetchTrending(region: region, timeWindow: timeWindow);

  Future<List<MediaItem>> fetchTrendingByCountry({
    required String countryCode,
  }) => _discovery.fetchTrendingByCountry(countryCode: countryCode);

  Future<List<MediaItem>> fetchTrendingToday() =>
      _discovery.fetchTrendingToday();

  Future<List<MediaItem>> fetchTopRatedMovies() =>
      _discovery.fetchTopRatedMovies();

  Future<List<MediaItem>> fetchPopularTVShows() =>
      _discovery.fetchPopularTVShows();

  Future<List<MediaItem>> fetchPopularMovies() =>
      _discovery.fetchPopularMovies();

  Future<List<MediaItem>> fetchTopRatedTV() => _discovery.fetchTopRatedTV();

  Future<List<MediaItem>> fetchAiringToday() => _discovery.fetchAiringToday();

  Future<List<MediaItem>> fetchOnTheAir() => _discovery.fetchOnTheAir();

  Future<List<MediaItem>> fetchNowPlaying({String region = 'PH'}) =>
      _discovery.fetchNowPlaying(region: region);

  Future<List<MediaItem>> fetchUpcoming({String region = 'PH'}) =>
      _discovery.fetchUpcoming(region: region);

  Future<Map<int, String>> fetchGenreList(String mediaType) =>
      _discovery.fetchGenreList(mediaType);

  Future<List<MediaItem>> discoverByGenre({
    required int genreId,
    required String mediaType,
    String sortBy = 'popularity.desc',
  }) => _discovery.discoverByGenre(
    genreId: genreId,
    mediaType: mediaType,
    sortBy: sortBy,
  );

  Future<List<MediaItem>> discoverMedia({
    required String mediaType,
    String? sortBy,
    List<int>? withGenres,
    int? yearGte,
    int? yearLte,
    double? voteAverageGte,
    int? voteCountGte,
    String? withOriginalLanguage,
    int page = 1,
  }) => _discovery.discoverMedia(
    mediaType: mediaType,
    sortBy: sortBy,
    withGenres: withGenres,
    yearGte: yearGte,
    yearLte: yearLte,
    voteAverageGte: voteAverageGte,
    voteCountGte: voteCountGte,
    withOriginalLanguage: withOriginalLanguage,
    page: page,
  );

  // ─── Search ────────────────────────────────────────────────────────────

  Future<List<MediaItem>> searchMedia(String query) =>
      _search.searchMedia(query);

  Future<int?> searchTvShow(String title, {String? firstAirDateYear}) =>
      _search.searchTvShow(title, firstAirDateYear: firstAirDateYear);

  // ─── Details ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchCredits(int id, String mediaType) =>
      _details.fetchCredits(id, mediaType);

  Future<List<Map<String, dynamic>>> fetchReviews(int id, String mediaType) =>
      _details.fetchReviews(id, mediaType);

  Future<List<MediaItem>> fetchSimilar(int id, String mediaType) =>
      _details.fetchSimilar(id, mediaType);

  Future<Map<String, dynamic>?> fetchTVShowDetails(int tvId) =>
      _details.fetchTVShowDetails(tvId);

  Future<List<dynamic>> fetchSeasonEpisodes(int tvId, int seasonNumber) =>
      _details.fetchSeasonEpisodes(tvId, seasonNumber);

  Future<Map<String, dynamic>?> fetchMediaDetails(int id, String mediaType) =>
      _details.fetchMediaDetails(id, mediaType);

  Future<bool> isAnimeByTmdbId(int tmdbId, String mediaType) =>
      _details.isAnimeByTmdbId(tmdbId, mediaType);

  // ─── Poster ────────────────────────────────────────────────────────────

  Future<String> fetchPosterUrl(int tmdbId, String mediaType) =>
      _poster.fetchPosterUrl(tmdbId, mediaType);

  Future<List<MediaItem>> backfillMissingPosters(List<MediaItem> items) =>
      _poster.backfillMissingPosters(items);

  Future<List<MediaItem>> refreshAnimePosters(List<MediaItem> items) =>
      _poster.refreshAnimePosters(items);

  // ─── Watchlist CRUD ────────────────────────────────────────────────────

  Future<void> saveToWatchList(
    MediaItem item,
    String status,
    String userName, {
    bool? isAnimeOverride,
    String? statusOwner,
    bool skipPartnerFallback = false,
  }) => _watchlist.saveToWatchList(
    item,
    status,
    userName,
    isAnimeOverride: isAnimeOverride,
    statusOwner: statusOwner,
    skipPartnerFallback: skipPartnerFallback,
  );

  /// Returns the Firestore userName of the partner that a partner-specific
  /// status refers to (e.g. "watched-clair" → "clairjassen"), or null.
  static String? resolveStatusOwner(String status, String currentUser) =>
      TMDBWatchlistService.resolveStatusOwner(status, currentUser);

  /// Clean stale partner-specific status from the current user's doc.
  Future<void> cleanStalePartnerStatus(
    int tmdbId,
    String userName,
    String newStatus,
  ) => _watchlist.cleanStalePartnerStatus(tmdbId, userName, newStatus);

  /// One-time cleanup of duplicate partner entries.
  Future<int> cleanupDuplicatePartnerEntries() =>
      _watchlist.cleanupDuplicatePartnerEntries();

  Future<void> updateProgress(
    MediaItem item,
    String userName, {
    int? season,
    int? episode,
    int? timestamp,
    int? durationSeconds,
    String? status,
  }) => _watchlist.updateProgress(
    item,
    userName,
    season: season,
    episode: episode,
    timestamp: timestamp,
    durationSeconds: durationSeconds,
    status: status,
  );

  Future<void> removeFromWatchList(int tmdbId, String userName) =>
      _watchlist.removeFromWatchList(tmdbId, userName);

  Future<bool> setListMembership(
    MediaItem item,
    String userName, {
    required bool add,
  }) => _watchlist.setListMembership(item, userName, add: add);

  Future<void> setUserRating(
    MediaItem item,
    String userName, {
    double? rating,
  }) => _watchlist.setUserRating(item, userName, rating: rating);

  // ─── Watchlist Streams ─────────────────────────────────────────────────

  Stream<List<MediaItem>> getWatchListStream(String userName) =>
      _watchlist.getWatchListStream(userName);

  Stream<List<MediaItem>> getCoupleWatchListStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) => _watchlist.getCoupleWatchListStream(userA: userA, userB: userB);

  Stream<List<MediaItem>> getAnimeWatchListStream(String userName) =>
      _watchlist.getAnimeWatchListStream(userName);

  Stream<List<MediaItem>> getCoupleAnimeStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) => _watchlist.getCoupleAnimeStream(userA: userA, userB: userB);

  Stream<List<MediaItem>> getCurrentlyWatchingStream(String userName) =>
      _watchlist.getCurrentlyWatchingStream(userName);

  Stream<List<MediaItem>> getCoupleCurrentlyWatchingStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) => _watchlist.getCoupleCurrentlyWatchingStream(userA: userA, userB: userB);

  Stream<List<MediaItem>> getCurrentlyWatchingAnimeStream(String userName) =>
      _watchlist.getCurrentlyWatchingAnimeStream(userName);

  Stream<List<MediaItem>> getCoupleCurrentlyWatchingAnimeStream({
    String userA = 'khentsgdz',
    String userB = 'clairjassen',
  }) => _watchlist.getCoupleCurrentlyWatchingAnimeStream(
    userA: userA,
    userB: userB,
  );

  // ─── Progress / Heartbeat ──────────────────────────────────────────────

  Future<void> heartbeatProgress(
    int tmdbId,
    String userName, {
    int? season,
    int? episode,
    int? timestamp,
    int? durationSeconds,
  }) => _watchlist.heartbeatProgress(
    tmdbId,
    userName,
    season: season,
    episode: episode,
    timestamp: timestamp,
    durationSeconds: durationSeconds,
  );

  // ─── Cache ─────────────────────────────────────────────────────────────

  Future<void> cacheWatchList(List<MediaItem> items, String userName) =>
      _cache.cacheWatchList(items, userName);

  Future<List<MediaItem>> getCachedWatchList(String userName) =>
      _cache.getCachedWatchList(userName);

  // ─── Migration ─────────────────────────────────────────────────────────

  Future<int> migrateWatchListOwnership() =>
      _watchlist.migrateWatchListOwnership();

  // ─── Trailer ───────────────────────────────────────────────────────────

  Future<String?> fetchTrailerKey(int id, String mediaType) =>
      _trailer.fetchTrailerKey(id, mediaType);
}
