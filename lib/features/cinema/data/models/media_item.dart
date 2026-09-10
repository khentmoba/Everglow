import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/utils/tmdb_images.dart';

double? _userRatingFromJson(Map<String, dynamic> json) =>
    json['userRating'] is num ? (json['userRating'] as num).toDouble() : null;

class MediaItem {
  final String id;
  final int tmdbId;
  final String title;
  final String mediaType;
  final String posterPath;
  final String backdropPath;
  final String year;
  final String status;

  /// True for Japanese animation (anime). Auto-detected from TMDB details
  /// (original_language == 'ja' + Animation genre) when the title is saved
  /// to the watchlist. Powers the dedicated "Anime" rail and screen.
  final bool isAnime;

  /// Owning user. Items in `watch_list` are scoped per user so Khent, Clair,
  /// and Breyan each see only their own queue / watched history.
  final String userName;
  final DateTime addedAt;

  /// Where this item was sourced from. `'tmdb'` for general cinema (movies /
  /// non-anime TV) and `'jikan'` for anime (MAL-sourced). Defaults to `'tmdb'`
  /// so existing watchlist entries don't need to be migrated.
  final String source;

  /// AniList numeric ID, when known. Lets the [EpisodeDrawer] skip the
  /// `idMal -> id` lookup when opening an anime detail. Optional — when
  /// null we resolve via AniList's `idMal` filter at detail-open time.
  final int? anilistId;

  /// Long-form synopsis / description. Populated for Jikan-sourced items
  /// (AniList's `description` field) so the [EpisodeDrawer] can show a
  /// real anime plot summary instead of TMDB's truncated `overview`.
  final String synopsis;

  /// Total episode count for the series (anime only). `null` for movies
  /// or TMDB-sourced items where we don't have authoritative counts.
  final int? episodeCount;

  /// MAL/Jikan status string (e.g. `'Airing'`, `'Finished Airing'`,
  /// `'Not yet aired'`). Anime-only; null for TMDB-sourced items.
  final String airingStatus;

  /// MAL/Jikan format string (e.g. `'TV'`, `'TV Short'`, `'Movie'`, `'OVA'`,
  /// `'ONA'`, `'Special'`, `'Music'`). Anime-only; null for TMDB-sourced
  /// items.
  final String format;

  /// Studio / production company that made this anime. Anime-only.
  final String studio;

  /// Genre names for this anime (e.g. `['Action', 'Fantasy']`).
  /// Populated from Jikan/AniList; empty for TMDB-sourced items.
  final List<String> genres;

  /// MAL/Jikan score on a 0-10 scale when known, used by the anime
  /// section's rating chips. `null` for TMDB-sourced items.
  final double? score;

  /// Current viewer's rating. `-1` is thumbs down and `1` is thumbs up.
  final double? userRating;

  /// When the current viewer last changed their rating.
  final DateTime? ratedAt;

  /// Season the user is currently on (TV series / anime only).
  final int? currentSeason;

  /// Episode the user is currently on (TV series / anime only).
  final int? currentEpisode;

  /// Timestamp in seconds into the movie / current episode.
  final int? currentTimestamp;

  /// Duration in seconds for the movie / current episode, when reported
  /// by an embed. Required to render a truthful playback-progress bar.
  final int? durationSeconds;

  /// When the progress was last updated.
  final DateTime? progressUpdatedAt;

  /// "Remind me" flag for unreleased titles. Optional in Firestore —
  /// missing reads as false so old documents need no migration.
  final bool remindMe;

  /// YouTube trailer key (e.g. `dQw4w9WgXcQ`), when known. Used by the
  /// anime spotlight hero to stream the official trailer in place of
  /// the backdrop still.
  final String? trailerYoutubeId;

  MediaItem({
    required this.id,
    required this.tmdbId,
    required this.title,
    required this.mediaType,
    required this.posterPath,
    this.backdropPath = '',
    this.year = '',
    required this.status,
    this.isAnime = false,
    this.userName = '',
    required this.addedAt,
    this.source = 'tmdb',
    this.anilistId,
    this.synopsis = '',
    this.episodeCount,
    this.airingStatus = '',
    this.format = '',
    this.studio = '',
    this.genres = const [],
    this.score,
    this.userRating,
    this.ratedAt,
    this.currentSeason,
    this.currentEpisode,
    this.currentTimestamp,
    this.durationSeconds,
    this.progressUpdatedAt,
    this.remindMe = false,
    this.trailerYoutubeId,
  });

  /// Normalized status for comparisons — guards against stray whitespace
  /// or casing in Firestore so shelves never silently empty out.
  String get _normalizedStatus => status.trim().toLowerCase();

  bool get isWatched =>
      _normalizedStatus == 'watched' ||
      _normalizedStatus == 'watched-khent' ||
      _normalizedStatus == 'watched-clair' ||
      _normalizedStatus == 'watched-both' ||
      _normalizedStatus == 'watched-self';

  /// True when this title is a film rather than an episodic series.
  /// Anything that is not a TV series (`mediaType != 'tv'`, e.g. movies
  /// and anime films) is treated as a movie so episode progress labels
  /// are never rendered for it. Anime films sometimes persist with
  /// `mediaType == 'tv'` (legacy docs, relations), so `format`
  /// (`'Movie'` from Jikan / `'MOVIE'` from AniList) is honored too.
  bool get isMovie {
    if (mediaType.trim().toLowerCase() != 'tv') return true;
    return format.trim().toLowerCase() == 'movie';
  }

  /// True when season/episode labels are meaningful for this title.
  /// Films never show them. Single-episode anime neither: ONA/OVA-listed
  /// films (e.g. Drifting Home: tv + episodeCount 1) save with stale S1E1
  /// progress, and S1E1 is noise for a single sitting.
  bool get hasEpisodeProgress {
    if (isMovie) return false;
    if (isAnime && episodeCount == 1) return false;
    return true;
  }

  /// True for anime series (TV) — the only anime that lives exclusively
  /// in the Anime rail. Anime *movies* belong in the cinema shelves too
  /// (see [isCinemaItem]) so film lovers never lose them from
  /// Currently Watching / Watched.
  bool get isAnimeSeries => isAnime && !isMovie;

  /// True when this title belongs in the cinema rails: every movie
  /// (live-action or anime) plus non-anime TV. Anime TV series return
  /// false here — the Anime rail owns those.
  bool get isCinemaItem => !isAnime || isMovie;

  /// Always returns a full image URL. If [posterPath] is already absolute
  /// (starts with `http`), it is returned as-is.  When it is a relative
  /// TMDB path like `/abc.jpg`, the w500 base URL is prepended.
  static const _tmdbImageBase = TmdbImages.poster;
  static const _tmdbBackdropBase = TmdbImages.backdropLarge;

  String get posterUrl {
    if (posterPath.isEmpty) return '';
    if (posterPath.startsWith('http')) return posterPath;
    return '$_tmdbImageBase$posterPath';
  }

  /// Always returns a full backdrop URL, or `''` when none is available.
  /// Mirrors [posterUrl] so relative TMDB paths stored in Firestore (e.g.
  /// `/abc.jpg`) resolve against the image CDN instead of failing to load.
  String get backdropUrl {
    if (backdropPath.isEmpty) return '';
    if (backdropPath.startsWith('http')) return backdropPath;
    return '$_tmdbBackdropBase$backdropPath';
  }

  bool get isToWatch => _normalizedStatus == 'to-watch';

  bool get isCurrentlyWatching =>
      _normalizedStatus == 'watching' ||
      _normalizedStatus == 'watching-khent' ||
      _normalizedStatus == 'watching-clair' ||
      _normalizedStatus == 'watching-both' ||
      _normalizedStatus == 'watching-self';

  /// Maps stored statuses to the partner-specific variant based on the
  /// item's [userName], which is the ground truth for single-owner docs.
  /// Per-user Firestore docs store "self" variants, but the couple drawer
  /// chips expect `watched-khent`, `watched-clair`, `watched-both`, etc.
  /// This resolves the mismatch so the correct chip is highlighted when
  /// the drawer opens.
  ///
  /// Single-owner couple docs (e.g. `userName == 'clairjassen'`) always
  /// resolve to that owner's chip — even for legacy docs that still carry
  /// a generic (`watching` / `watched`) or mismatched partner status
  /// (`watching-khent` on Clair's doc from before statuses were routed
  /// to the owner's doc). Without this, opening Clair's Currently Watching
  /// item (e.g. Odyssey) highlights "Khent Watching" instead of
  /// "Clair Watching".
  ///
  /// Merged couple items (`userName` contains both partners) already carry
  /// the merged status — returned unchanged so a Khent-only title is never
  /// upgraded to Both. The one exception is legacy `*-self` on a merged doc
  /// (pre-merge code mapped those to Both), preserved here so the Both chip
  /// still highlights. Non-couple usernames (Breyan, Octagram) and empty
  /// owners (search results) keep the original status so generic chips
  /// (`watching-self`) keep working.
  String resolveCoupleStatus() {
    switch (status) {
      case 'watched-both':
      case 'watching-both':
      case 'to-watch':
        return status;
      case 'watched-self':
        if (partnerUsernames.length > 1) return 'watched-both';
        break;
      case 'watching-self':
        if (partnerUsernames.length > 1) return 'watching-both';
        break;
      default:
        break;
    }
    final partners = partnerUsernames;
    // Merged item with both owners: status is already merged, keep it.
    if (partners.length > 1) return status;
    if (partners.length == 1) {
      final owner = partners.first;
      if (owner == 'khentsgdz') {
        if (isWatched) return 'watched-khent';
        if (isCurrentlyWatching) return 'watching-khent';
        return status;
      }
      if (owner == 'clairjassen') {
        if (isWatched) return 'watched-clair';
        if (isCurrentlyWatching) return 'watching-clair';
        return status;
      }
      // Non-couple single owner (Breyan, Octagram, guests): keep as-is
      // so generic `watching-self` / `watched-self` chips still match.
      return status;
    }
    // No owner (e.g. search/discover results): keep as-is. Old code mapped
    // self-variants via _resolveByUserName which returned self again, so
    // this is behavior-preserving.
    return status;
  }

  String get watchedDisplay {
    if (status == 'watched-khent') return 'Watched by Khent';
    if (status == 'watched-clair') return 'Watched by Clair';
    if (status == 'watched-both' || status == 'watched') {
      return 'Watched by Both';
    }
    if (status == 'watched-self') return 'Watched';
    if (status == 'watching-khent') return 'Khent Watching';
    if (status == 'watching-clair') return 'Clair Watching';
    if (status == 'watching-both' || status == 'watching') return 'Watching';
    if (status == 'watching-self') return 'Watching';
    return 'To Watch';
  }

  /// Returns the list of partner usernames (e.g. `['khentsgdz']`,
  /// `['clairjassen']`, or `['khentsgdz', 'clairjassen']`) by splitting the
  /// `userName` field on commas. Used to render the khent/clair/both
  /// attribution in the combined couple watchlist view.
  List<String> get partnerUsernames {
    return userName
        .split(',')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
  }

  /// Short label for which partner(s) have the title in their queue.
  /// For a couple's combined wishlist this is rendered as the
  /// khent/clair/both chip in the grid.
  String get wanterDisplay {
    final partners = partnerUsernames;
    final hasKhent = partners.contains('khentsgdz');
    final hasClair = partners.contains('clairjassen');
    if (hasKhent && hasClair) return 'Both';
    if (hasKhent) return 'Khent';
    if (hasClair) return 'Clair';
    return 'Mine';
  }

  factory MediaItem.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return MediaItem(
      id: documentId,
      tmdbId: data['tmdbId'] ?? 0,
      title: data['title'] ?? '',
      mediaType: data['mediaType'] ?? 'movie',
      posterPath: data['posterPath'] ?? '',
      backdropPath: data['backdropPath'] ?? '',
      year: data['year'] ?? '',
      status: data['status'] ?? 'to-watch',
      isAnime: data['isAnime'] == true,
      userName: data['userName'] ?? '',
      addedAt: _parseDateTime(data['addedAt']),
      source: data['source'] ?? 'tmdb',
      anilistId: data['anilistId'] is int ? data['anilistId'] as int : null,
      synopsis: data['synopsis'] ?? '',
      episodeCount: data['episodeCount'] is int
          ? data['episodeCount'] as int
          : null,
      airingStatus: data['airingStatus'] ?? '',
      format: data['format'] ?? '',
      studio: data['studio'] ?? '',
      genres: data['genres'] is List
          ? List<String>.from(data['genres'].whereType<String>())
          : const [],
      score: data['score'] is num ? (data['score'] as num).toDouble() : null,
      userRating: data['userRating'] is num
          ? (data['userRating'] as num).toDouble()
          : null,
      ratedAt: _parseDateTime(data['ratedAt']),
      currentSeason: data['currentSeason'] is int
          ? data['currentSeason'] as int
          : null,
      currentEpisode: data['currentEpisode'] is int
          ? data['currentEpisode'] as int
          : null,
      currentTimestamp: data['currentTimestamp'] is int
          ? data['currentTimestamp'] as int
          : null,
      durationSeconds: data['durationSeconds'] is int
          ? data['durationSeconds'] as int
          : null,
      progressUpdatedAt: _parseDateTime(data['progressUpdatedAt']),
      remindMe: data['remindMe'] == true,
      trailerYoutubeId: data['trailerYoutubeId'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    final m = addedAt.month.toString().padLeft(2, '0');
    final d = addedAt.day.toString().padLeft(2, '0');
    return {
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'year': year,
      'status': status,
      'isAnime': isAnime,
      'userName': userName,
      'addedAt': Timestamp.fromDate(addedAt),
      'monthDay': '$m-$d',
      'source': source,
      if (anilistId != null) 'anilistId': anilistId,
      'synopsis': synopsis,
      if (episodeCount != null) 'episodeCount': episodeCount,
      'airingStatus': airingStatus,
      'format': format,
      'studio': studio,
      if (genres.isNotEmpty) 'genres': genres,
      if (score != null) 'score': score,
      if (userRating != null) 'userRating': userRating,
      if (ratedAt != null) 'ratedAt': Timestamp.fromDate(ratedAt!),
      if (currentSeason != null) 'currentSeason': currentSeason,
      if (currentEpisode != null) 'currentEpisode': currentEpisode,
      if (currentTimestamp != null) 'currentTimestamp': currentTimestamp,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (progressUpdatedAt != null)
        'progressUpdatedAt': Timestamp.fromDate(progressUpdatedAt!),
      if (remindMe) 'remindMe': true,
      if (trailerYoutubeId != null && trailerYoutubeId!.isNotEmpty)
        'trailerYoutubeId': trailerYoutubeId,
    };
  }

  /// Compact JSON form used by the local anime home-row cache. Keeps the
  /// fields the home cards and watch page need without watchlist state.
  Map<String, dynamic> toJson() {
    return {
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'year': year,
      'isAnime': isAnime,
      'source': source,
      if (anilistId != null) 'anilistId': anilistId,
      'synopsis': synopsis,
      if (episodeCount != null) 'episodeCount': episodeCount,
      'airingStatus': airingStatus,
      'format': format,
      'studio': studio,
      if (genres.isNotEmpty) 'genres': genres,
      if (score != null) 'score': score,
      if (userRating != null) 'userRating': userRating,
      if (ratedAt != null) 'ratedAt': ratedAt!.millisecondsSinceEpoch,
      if (trailerYoutubeId != null && trailerYoutubeId!.isNotEmpty)
        'trailerYoutubeId': trailerYoutubeId,
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: '',
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'tv',
      posterPath: json['posterPath'] as String? ?? '',
      backdropPath: json['backdropPath'] as String? ?? '',
      year: json['year'] as String? ?? '',
      status: '',
      isAnime: json['isAnime'] == true,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['addedAt'] as num?)?.toInt() ?? 0,
      ),
      source: json['source'] as String? ?? 'jikan',
      anilistId: (json['anilistId'] as num?)?.toInt(),
      synopsis: json['synopsis'] as String? ?? '',
      episodeCount: (json['episodeCount'] as num?)?.toInt(),
      airingStatus: json['airingStatus'] as String? ?? '',
      format: json['format'] as String? ?? '',
      studio: json['studio'] as String? ?? '',
      genres: json['genres'] is List
          ? List<String>.from(json['genres']!.whereType<String>())
          : const [],
      score: (json['score'] as num?)?.toDouble(),
      userRating: _userRatingFromJson(json),
      ratedAt: json['ratedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['ratedAt'] as int)
          : null,
      trailerYoutubeId: json['trailerYoutubeId'] as String?,
    );
  }

  MediaItem copyWith({
    String? id,
    int? tmdbId,
    String? title,
    String? mediaType,
    String? posterPath,
    String? backdropPath,
    String? year,
    String? status,
    bool? isAnime,
    String? userName,
    DateTime? addedAt,
    String? source,
    int? anilistId,
    String? synopsis,
    int? episodeCount,
    String? airingStatus,
    String? format,
    String? studio,
    List<String>? genres,
    double? score,
    double? userRating,
    DateTime? ratedAt,
    int? currentSeason,
    int? currentEpisode,
    int? currentTimestamp,
    int? durationSeconds,
    DateTime? progressUpdatedAt,
    bool? remindMe,
    String? trailerYoutubeId,
  }) {
    return MediaItem(
      id: id ?? this.id,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      year: year ?? this.year,
      status: status ?? this.status,
      isAnime: isAnime ?? this.isAnime,
      userName: userName ?? this.userName,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
      anilistId: anilistId ?? this.anilistId,
      synopsis: synopsis ?? this.synopsis,
      episodeCount: episodeCount ?? this.episodeCount,
      airingStatus: airingStatus ?? this.airingStatus,
      format: format ?? this.format,
      studio: studio ?? this.studio,
      genres: genres ?? this.genres,
      score: score ?? this.score,
      userRating: userRating ?? this.userRating,
      ratedAt: ratedAt ?? this.ratedAt,
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      currentTimestamp: currentTimestamp ?? this.currentTimestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      progressUpdatedAt: progressUpdatedAt ?? this.progressUpdatedAt,
      remindMe: remindMe ?? this.remindMe,
      trailerYoutubeId: trailerYoutubeId ?? this.trailerYoutubeId,
    );
  }
}

/// Shared status filters for cinema/anime shelves.
///
/// Every tab and preview splits the same watchlist the same way
/// (`watching` / `to-watch` / `watched`, cinema vs anime). Use these
/// instead of repeating `.where((i) => ...)` one-liners.
extension MediaItemLists on List<MediaItem> {
  /// Cinema rails: every movie plus non-anime TV (see [MediaItem.isCinemaItem]).
  List<MediaItem> get cinemaItems => where((i) => i.isCinemaItem).toList();

  /// Currently watching, any shelf.
  List<MediaItem> get currentlyWatching =>
      where((i) => i.isCurrentlyWatching).toList();

  /// Queued to watch, any shelf.
  List<MediaItem> get toWatch => where((i) => i.isToWatch).toList();

  /// Watched, any shelf.
  List<MediaItem> get watched => where((i) => i.isWatched).toList();

  /// Watched cinema titles (dashboard shelves, library counts).
  List<MediaItem> get watchedCinema =>
      where((i) => i.isWatched && i.isCinemaItem).toList();

  /// Currently-watching cinema titles.
  List<MediaItem> get watchingCinema =>
      where((i) => i.isCurrentlyWatching && i.isCinemaItem).toList();

  /// Titles with the "Remind me" bell set, any shelf.
  List<MediaItem> get reminded => where((i) => i.remindMe).toList();
}
