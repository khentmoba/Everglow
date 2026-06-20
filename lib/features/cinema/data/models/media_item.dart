import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Season the user is currently on (TV series / anime only).
  final int? currentSeason;

  /// Episode the user is currently on (TV series / anime only).
  final int? currentEpisode;

  /// Timestamp in seconds into the movie / current episode.
  final int? currentTimestamp;

  /// When the progress was last updated.
  final DateTime? progressUpdatedAt;

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
    this.currentSeason,
    this.currentEpisode,
    this.currentTimestamp,
    this.progressUpdatedAt,
  });

  bool get isWatched =>
      status == 'watched' ||
      status == 'watched-khent' ||
      status == 'watched-clair' ||
      status == 'watched-both' ||
      status == 'watched-self';

  /// Always returns a full image URL. If [posterPath] is already absolute
  /// (starts with `http`), it is returned as-is.  When it is a relative
  /// TMDB path like `/abc.jpg`, the w500 base URL is prepended.
  static const _tmdbImageBase = 'https://image.tmdb.org/t/p/w500';

  String get posterUrl {
    if (posterPath.isEmpty) return '';
    if (posterPath.startsWith('http')) return posterPath;
    return '$_tmdbImageBase$posterPath';
  }

  bool get isToWatch => status == 'to-watch';

  bool get isCurrentlyWatching =>
      status == 'watching' ||
      status == 'watching-khent' ||
      status == 'watching-clair' ||
      status == 'watching-both' ||
      status == 'watching-self';

  String get watchedDisplay {
    if (status == 'watched-khent') return 'Watched by Khent';
    if (status == 'watched-clair') return 'Watched by Clair';
    if (status == 'watched-both' || status == 'watched') return 'Watched by Both';
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

  factory MediaItem.fromFirestore(Map<String, dynamic> data, String documentId) {
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
      episodeCount: data['episodeCount'] is int ? data['episodeCount'] as int : null,
      airingStatus: data['airingStatus'] ?? '',
      format: data['format'] ?? '',
      studio: data['studio'] ?? '',
      currentSeason: data['currentSeason'] is int ? data['currentSeason'] as int : null,
      currentEpisode: data['currentEpisode'] is int ? data['currentEpisode'] as int : null,
      currentTimestamp: data['currentTimestamp'] is int ? data['currentTimestamp'] as int : null,
      progressUpdatedAt: _parseDateTime(data['progressUpdatedAt']),
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
      'source': source,
      if (anilistId != null) 'anilistId': anilistId,
      'synopsis': synopsis,
      if (episodeCount != null) 'episodeCount': episodeCount,
      'airingStatus': airingStatus,
      'format': format,
      'studio': studio,
      if (currentSeason != null) 'currentSeason': currentSeason,
      if (currentEpisode != null) 'currentEpisode': currentEpisode,
      if (currentTimestamp != null) 'currentTimestamp': currentTimestamp,
      if (progressUpdatedAt != null) 'progressUpdatedAt': Timestamp.fromDate(progressUpdatedAt!),
    };
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
    int? currentSeason,
    int? currentEpisode,
    int? currentTimestamp,
    DateTime? progressUpdatedAt,
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
      currentSeason: currentSeason ?? this.currentSeason,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      currentTimestamp: currentTimestamp ?? this.currentTimestamp,
      progressUpdatedAt: progressUpdatedAt ?? this.progressUpdatedAt,
    );
  }
}
