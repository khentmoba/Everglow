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

  final bool isAnime;

  final String userName;
  final DateTime addedAt;

  final String source;

  final int? anilistId;

  final String synopsis;

  final int? episodeCount;

  final String airingStatus;

  final String format;

  final String studio;

  final List<String> genres;

  final double? score;

  final double? userRating;

  final DateTime? ratedAt;

  final int? currentSeason;

  final int? currentEpisode;

  final int? currentTimestamp;

  final int? durationSeconds;

  final DateTime? progressUpdatedAt;

  final bool remindMe;

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

  String get _normalizedStatus => status.trim().toLowerCase();

  int? get resumeSeconds {
    final at = currentTimestamp ?? 0;
    if (at <= 0 || isWatched) return null;
    final total = durationSeconds ?? 0;
    if (total > 0 && at >= total * 0.95) return null;
    return at;
  }

  String get catalogKey =>
      '$source\u0000${mediaType.trim().toLowerCase() == 'tv' ? 'tv' : 'movie'}'
      '\u0000${tmdbId > 0 ? tmdbId : (anilistId ?? 0)}';

  bool get isSeriesCompleted => isCompletedProgress(
    episode: currentEpisode,
    totalEpisodes: episodeCount,
    isMovie: isMovie,
  );

  static bool isCompletedProgress({
    required int? episode,
    required int? totalEpisodes,
    required bool isMovie,
  }) {
    if (isMovie) return false;
    if (totalEpisodes == null || totalEpisodes <= 1) return false;
    if (episode == null) return false;
    return episode >= totalEpisodes;
  }

  bool get isWatched =>
      _normalizedStatus == 'watched' ||
      _normalizedStatus == 'watched-khent' ||
      _normalizedStatus == 'watched-clair' ||
      _normalizedStatus == 'watched-both' ||
      _normalizedStatus == 'watched-self' ||
      isSeriesCompleted;

  bool get isMovie {
    if (mediaType.trim().toLowerCase() != 'tv') return true;
    return format.trim().toLowerCase() == 'movie';
  }

  bool get hasEpisodeProgress {
    if (isMovie) return false;
    if (isAnime && episodeCount == 1) return false;
    return true;
  }

  static final _seasonInTitleRegex = RegExp(
    r'season\s+(\d+)',
    caseSensitive: false,
  );

  int get displaySeason {
    final match = _seasonInTitleRegex.firstMatch(title);
    if (match != null) {
      final parsed = int.tryParse(match.group(1) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    return currentSeason ?? 1;
  }

  bool get isAnimeSeries => isAnime && !isMovie;

  static bool isSingleEpisodeFilm({
    required String format,
    int? episodeCount,
    int? durationMinutes,
  }) {
    if (format.trim().toLowerCase() == 'movie') return true;
    return episodeCount == 1 && (durationMinutes ?? 0) >= 60;
  }

  bool get isCinemaItem => !isAnime || isMovie;

  String get posterUrl => TmdbImages.posterFor(posterPath);

  String get backdropUrl => TmdbImages.backdropFor(backdropPath, large: true);

  bool get isToWatch => _normalizedStatus == 'to-watch';

  bool get isCurrentlyWatching =>
      !isSeriesCompleted &&
      (_normalizedStatus == 'watching' ||
          _normalizedStatus == 'watching-khent' ||
          _normalizedStatus == 'watching-clair' ||
          _normalizedStatus == 'watching-both' ||
          _normalizedStatus == 'watching-self');

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
      return status;
    }
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

  List<String> get partnerUsernames {
    return userName
        .split(',')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
  }

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
    bool clearProgress = false,
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
      currentSeason: clearProgress
          ? null
          : (currentSeason ?? this.currentSeason),
      currentEpisode: clearProgress
          ? null
          : (currentEpisode ?? this.currentEpisode),
      currentTimestamp: clearProgress
          ? null
          : (currentTimestamp ?? this.currentTimestamp),
      durationSeconds: clearProgress
          ? null
          : (durationSeconds ?? this.durationSeconds),
      progressUpdatedAt: progressUpdatedAt ?? this.progressUpdatedAt,
      remindMe: remindMe ?? this.remindMe,
      trailerYoutubeId: trailerYoutubeId ?? this.trailerYoutubeId,
    );
  }
}

extension MediaItemLists on List<MediaItem> {
  List<MediaItem> get cinemaItems => where((i) => i.isCinemaItem).toList();

  List<MediaItem> get currentlyWatching =>
      where((i) => i.isCurrentlyWatching).toList();

  List<MediaItem> get toWatch => where((i) => i.isToWatch).toList();

  List<MediaItem> get watched => where((i) => i.isWatched).toList();

  List<MediaItem> get watchedCinema =>
      where((i) => i.isWatched && i.isCinemaItem).toList();

  List<MediaItem> get watchingCinema =>
      where((i) => i.isCurrentlyWatching && i.isCinemaItem).toList();

  List<MediaItem> get reminded => where((i) => i.remindMe).toList();
}
