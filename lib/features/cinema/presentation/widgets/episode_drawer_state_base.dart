part of 'episode_drawer.dart';

abstract class _EpisodeDrawerStateBase extends State<EpisodeDrawer>
    with SingleTickerProviderStateMixin {
  final TMDBService _tmdbService = TMDBService();
  final JikanService _jikanService = JikanService();
  final AniListService _aniListService = AniListService();
  final AniZipService _aniZipService = AniZipService();
  bool _isLoadingEpisodes = false;
  bool _isLoadingCast = true;
  bool _isLoadingReviews = true;
  bool _isLoadingSimilar = true;
  Map<String, dynamic>? _details;
  List<dynamic> _seasons = [];
  int? _selectedSeasonNumber;
  int? _tmdbMatchedSeason;
  List<dynamic> _episodes = [];

  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _reviews = [];
  List<MediaItem> _similar = [];

  int _extraTab = 0;
  bool _castRequested = false;
  bool _reviewsRequested = false;
  bool _similarRequested = false;
  late final ValueNotifier<String> _statusNotifier;
  String get _currentStatus => _statusNotifier.value;
  List<String> _genreNames = [];

  AniListDetail? _aniListDetail;

  int? _aniSearchedTmdbId;

  int? _resolvedMalId;

  String get _studio => _isAnimeSourced
      ? (_aniListDetail?.studios.isNotEmpty == true
            ? _aniListDetail!.studios.first
            : widget.item.studio)
      : '';

  String get _format =>
      _isAnimeSourced ? (_aniListDetail?.format ?? widget.item.format) : '';

  String get _airingStatus => _isAnimeSourced
      ? (_aniListDetail?.airingStatus ?? widget.item.airingStatus)
      : '';

  bool get _isAnimeSourced =>
      widget.item.isAnime ||
      widget.item.source == 'jikan' ||
      widget.item.source == 'anilist';

  bool get _isFilm {
    if (widget.item.isMovie) return true;
    if (!_isAnimeSourced) return false;
    final detail = _aniListDetail;
    if (detail != null) {
      return MediaItem.isSingleEpisodeFilm(
        format: detail.format,
        episodeCount: detail.episodeCount ?? widget.item.episodeCount,
        durationMinutes: detail.duration,
      );
    }
    return MediaItem.isSingleEpisodeFilm(
      format: widget.item.format,
      episodeCount: widget.item.episodeCount,
      durationMinutes: null,
    );
  }

  int get _effectiveMalId => _resolvedMalId ?? widget.item.tmdbId;

  String? _trailerKey;
  bool _isLoadingTrailer = false;
  bool _isPlayingTrailer = false;
  bool _trailerMuted = true;

  void _toggleTrailerMute() {
    setState(() => _trailerMuted = !_trailerMuted);
  }

  bool get _isInWatchlist => _currentStatus.isNotEmpty;
  bool get _isLiked => _currentStatus.startsWith('watched');

  Future<void> _updateStatus(String newStatus);

  void _toggleWatchlist() {
    final next = _isInWatchlist ? '' : 'to-watch';
    _updateStatus(next);
  }

  void _toggleLike() {
    final next = _isLiked ? '' : 'watched-self';
    _updateStatus(next);
  }

  String? get _certification {
    final d = _details;
    if (d == null) return _isAnimeSourced ? '13+' : null;
    if (_isFilm) {
      final rd = d['release_dates'];
      final results = rd is Map ? rd['results'] as List? : null;
      if (results != null) {
        final dates = _pickRegion(results)?['release_dates'] as List?;
        for (final r in dates ?? const []) {
          final cert =
              (r is Map ? r['certification'] ?? '' : '').toString().trim();
          if (cert.isNotEmpty) return cert;
        }
      }
    } else {
      final cr = d['content_ratings'];
      final results = cr is Map ? cr['results'] as List? : null;
      if (results != null) {
        final rating =
            (_pickRegion(results)?['rating'] ?? '').toString().trim();
        if (rating.isNotEmpty) return rating;
      }
    }
    return _isAnimeSourced ? '13+' : '16+';
  }

  Map<String, dynamic>? _pickRegion(List results) {
    final rows = results.whereType<Map>().toList();
    if (rows.isEmpty) return null;
    for (final iso in ['PH', 'US', 'GB']) {
      for (final r in rows) {
        if ((r['iso_3166_1'] ?? '').toString() == iso) {
          return Map<String, dynamic>.from(r);
        }
      }
    }
    return Map<String, dynamic>.from(rows.first);
  }

  String get _contentAdvisory {
    if (_genreNames.contains('Action') ||
        _genreNames.contains('Crime') ||
        _genreNames.contains('Thriller')) {
      return 'violence, language';
    }
    if (_genreNames.contains('Romance') || _genreNames.contains('Drama')) {
      return 'romantic themes, language';
    }
    if (_genreNames.contains('Horror') || _genreNames.contains('Mystery')) {
      return 'fear, violence';
    }
    if (_genreNames.contains('Comedy')) {
      return 'humor, suggestive dialogue';
    }
    if (_genreNames.contains('Animation')) {
      return 'fantasy action, mild language';
    }
    return 'general themes';
  }

  String get _showMoodTags {
    final tags = <String>[];
    if (_genreNames.contains('Romance')) tags.addAll(['Emotional', 'Romantic']);
    if (_genreNames.contains('Drama') && !tags.contains('Emotional')) {
      tags.add('Emotional');
    }
    if (_genreNames.contains('Comedy')) tags.add('Witty');
    if (_genreNames.contains('Action') || _genreNames.contains('Adventure')) {
      tags.add('Exciting');
    }
    if (_genreNames.contains('Thriller') || _genreNames.contains('Mystery')) {
      tags.add('Suspenseful');
    }
    if (_genreNames.contains('Sci-Fi') || _genreNames.contains('Fantasy')) {
      tags.add('Imaginative');
    }
    if (tags.isEmpty) {
      if (_genreNames.isNotEmpty) return _genreNames.take(2).join(', ');
      return 'Emotional, Compelling';
    }
    return tags.toSet().take(3).join(', ');
  }

  bool _isMobile = false;

  final _statusScrollCtrl = ScrollController();
  Future<void> _statusQueue = Future.value();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
}

abstract class _EpisodeDrawerStateCore extends _EpisodeDrawerStateBase {
  @override
  void initState() {
    super.initState();
    _statusNotifier = ValueNotifier(widget.item.resolveCoupleStatus());
    _fadeCtrl = AnimationController(
      vsync: this as TickerProvider,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchMediaDetails();
    _loadTrailer();
    _requestExtraTab(0);
  }

  void _requestExtraTab(int index) {
    switch (index) {
      case 0:
        if (_castRequested) return;
        _castRequested = true;
        _fetchCast();
      case 1:
        if (_reviewsRequested) return;
        _reviewsRequested = true;
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _fetchReviews();
        });
      case 2:
        if (_similarRequested) return;
        _similarRequested = true;
        _fetchSimilar();
    }
  }

  void _selectExtraTab(int index) {
    if (_extraTab == index) return;
    setState(() => _extraTab = index);
    _requestExtraTab(index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMobile = MediaQuery.sizeOf(context).width < 720;
  }

  @override
  void dispose() {
    _statusScrollCtrl.dispose();
    _statusNotifier.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrailer() async {
    setState(() => _isLoadingTrailer = true);
    try {
      String? key;
      if (_isAnimeSourced) {
        final detail =
            _aniListDetail ??
            await _aniListService.fetchDetails(malId: _effectiveMalId);
        _aniListDetail ??= detail;
        key = detail?.trailerYoutubeId;
        key ??= await _jikanTrailerKey(_effectiveMalId);
      } else {
        key = await _tmdbService.fetchTrailerKey(
          widget.item.tmdbId,
          widget.item.mediaType,
        );
      }
      if (mounted) {
        setState(() {
          _trailerKey = key;
          _isLoadingTrailer = false;
          if ((widget.cinemaVariant || _isMobile) && key != null) {
            _isPlayingTrailer = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrailer = false);
      }
    }
  }

  Future<String?> _jikanTrailerKey(int malId) async {
    try {
      final data = await _jikanService.fetchAnimeById(malId);
      final trailer = data?['trailer'] as Map<String, dynamic>?;
      final yt = trailer?['youtube_id'] as String?;
      if (yt != null && yt.isNotEmpty) return yt;
      final url = trailer?['url'] as String?;
      if (url != null && url.contains('v=')) {
        return url.split('v=').last;
      }
    } catch (e) {
      debugPrint('[EpisodeDrawer] Failed to extract YouTube trailer ID: $e');
    }
    return null;
  }

  Future<void> _fetchMediaDetails() async {
    try {
      if (_isAnimeSourced) {
        await _fetchAnimeDetails();
      } else {
        await _fetchTmdbDetails();
      }
    } catch (e) {
      // Silently fail — details will show without extra metadata
    }
  }

  Future<void> _fetchAnimeDetails() async {
    final detail = await _aniListService.fetchDetailsWithFallback(
      anilistId: widget.item.anilistId,
      malId: widget.item.tmdbId,
    );
    if (detail?.malId != null) _resolvedMalId = detail!.malId;
    if (!mounted) return;
    if (detail == null) {
      setState(() {
        _details = {};
        _isLoadingEpisodes = false;
      });
      return;
    }
    final poster = detail.coverImageUrl;
    final backdrop = detail.bannerImageUrl.isNotEmpty
        ? detail.bannerImageUrl
        : poster;
    final mapped = <String, dynamic>{
      'id': detail.id,
      'overview': detail.synopsis,
      'vote_average': detail.averageScore,
      'poster_path': null,
      'backdrop_path': null,
      '_posterUrl': poster,
      '_backdropUrl': backdrop,
      '_episodeCount': detail.episodeCount,
      '_duration': detail.duration,
      '_format': detail.format,
      '_airingStatus': detail.airingStatus,
      '_studios': detail.studios,
      'genres': detail.genres.map((g) => {'id': g, 'name': g}).toList(),
    };

    setState(() {
      _aniListDetail = detail;
      _resolvedMalId = detail.malId ?? widget.item.tmdbId;
      _details = mapped;
      _genreNames = detail.genres;
    });

    if (_isFilm) {
      if (mounted) {
        setState(() {
          _seasons = [];
          _episodes = [];
          _isLoadingEpisodes = false;
        });
      }
      return;
    }

    final malId = _resolvedMalId ?? widget.item.tmdbId;
    int? tmdbSeriesId = await _aniZipService.fetchTmdbId(malId);
    if (tmdbSeriesId == null && widget.item.year.isNotEmpty) {
      tmdbSeriesId = await _tmdbService.searchTvShow(
        widget.item.title,
        firstAirDateYear: widget.item.year,
      );
    }

    if (tmdbSeriesId != null) {
      final tmdbDetails = await _tmdbService.fetchMediaDetails(
        tmdbSeriesId,
        'tv',
      );
      if (tmdbDetails != null && mounted) {
        final tmdbSeasons =
            (tmdbDetails['seasons'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .where(
                  (s) =>
                      (s['season_number'] is int) &&
                      (s['season_number'] as int) > 0,
                )
                .toList() ??
            [];
        if (tmdbSeasons.isNotEmpty) {
          setState(() {
            _aniSearchedTmdbId = tmdbSeriesId;
            _seasons = tmdbSeasons;
            final firstSn = tmdbSeasons.first['season_number'] as int;
            _selectedSeasonNumber = firstSn;
            _fetchSeasonEpisodes(firstSn);
          });
          return;
        }
      }
    }

    final synthCount = detail.episodeCount != null && detail.episodeCount! > 0
        ? detail.episodeCount
        : 12;
    setState(() {
      _seasons = [
        {'season_number': 1, 'name': 'Episodes', 'episode_count': synthCount},
      ];
      _selectedSeasonNumber = 1;
      _fetchSeasonEpisodes(1);
    });
  }

  Future<void> _fetchTmdbDetails() async {
    final details = await _tmdbService.fetchMediaDetails(
      widget.item.tmdbId,
      widget.item.mediaType,
    );
    if (mounted) {
      setState(() {
        _details = details;
        if (widget.item.mediaType == 'tv' && details != null) {
          _seasons = (details['seasons'] as List?) ?? [];
          if (_seasons.isNotEmpty) {
            final firstSeason = _seasons.firstWhere(
              (s) => s['season_number'] != null && s['season_number'] > 0,
              orElse: () => _seasons.first,
            );
            final selectedSeason = _isAnimeSourced
                ? firstSeason
                : _seasons.firstWhere(
                    (s) => s['season_number'] == widget.item.currentSeason,
                    orElse: () => firstSeason,
                  );
            _selectedSeasonNumber = selectedSeason['season_number'];
            if (_selectedSeasonNumber != null) {
              _fetchSeasonEpisodes(_selectedSeasonNumber!);
            }
          }
        }
        if (details != null && details['genres'] != null) {
          _genreNames = (details['genres'] as List)
              .map<String>((g) => g['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
        }
      });
    }
  }

  Future<void> _fetchSeasonEpisodes(int seasonNumber) async {
    if (_isFilm) {
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
          _episodes = [];
        });
      }
      return;
    }
    setState(() {
      _isLoadingEpisodes = true;
      _episodes = [];
      _tmdbMatchedSeason = null;
    });
    if (_isAnimeSourced && _aniSearchedTmdbId != null) {
      final episodes = await _tmdbService.fetchSeasonEpisodes(
        _aniSearchedTmdbId!,
        seasonNumber,
      );
      if (mounted && _selectedSeasonNumber == seasonNumber) {
        setState(() {
          _episodes = episodes;
          _isLoadingEpisodes = false;
        });
      }
      return;
    }
    if (_isAnimeSourced) {
      final malId = _resolvedMalId ?? widget.item.tmdbId;
      final episodes = await _fetchJikanEpisodes(malId);
      if (!mounted) return;
      if (_selectedSeasonNumber != seasonNumber) return;
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
      });
      return;
    }
    final episodes = await _tmdbService.fetchSeasonEpisodes(
      widget.item.tmdbId,
      seasonNumber,
    );
    if (mounted && _selectedSeasonNumber == seasonNumber) {
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchJikanEpisodes(int malId) async {
    final jikanFuture = _jikanService.fetchAnimeEpisodes(malId);
    final animeByIdFuture = _jikanService.fetchAnimeById(malId);
    final aniZipFuture = _aniZipService.fetchEpisodeImages(malId);
    final jikanEps = await jikanFuture;
    final anime = await animeByIdFuture;
    final aniZipImages = await aniZipFuture;

    final announcedCount = (anime?['episodes'] is num)
        ? (anime?['episodes'] as num).toInt()
        : 0;
    final jikanMaxNum = jikanEps
        .map((e) => (e['mal_id'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final aniZipMaxNum = aniZipImages.keys.fold<int>(
      0,
      (a, b) => a > b ? a : b,
    );
    final maxKnown = jikanMaxNum > aniZipMaxNum ? jikanMaxNum : aniZipMaxNum;

    int episodeCount;
    if (maxKnown > 0) {
      episodeCount = maxKnown;
      if (announcedCount > episodeCount) episodeCount = announcedCount;
    } else {
      episodeCount = announcedCount > 0 ? announcedCount : 12;
    }

    final anilistTitles = <int, String>{};
    final anilistThumbs = <int, String>{};
    for (final ep in _aniListDetail?.episodes ?? const []) {
      final t = ep.title;
      if (t != null && t.isNotEmpty) anilistTitles[ep.number] = t;
      final th = ep.thumbnail;
      if (th != null && th.isNotEmpty) anilistThumbs[ep.number] = th;
    }

    final needsTmdbFallback = (() {
      final withThumb = <int>{}
        ..addAll(anilistThumbs.keys)
        ..addAll(aniZipImages.keys);
      return episodeCount > 0 && withThumb.length < episodeCount;
    })();
    Map<int, ({String? stillUrl, String? overview})> tmdbStills = {};
    if (episodeCount > 0) {
      int? tmdbSeriesId = await _aniZipService.fetchTmdbId(malId);
      if (tmdbSeriesId == null && widget.item.year.isNotEmpty) {
        tmdbSeriesId = await _tmdbService.searchTvShow(
          widget.item.title,
          firstAirDateYear: widget.item.year,
        );
      }
      _aniSearchedTmdbId = tmdbSeriesId;
      if (tmdbSeriesId != null) {
        tmdbStills = await _fetchTmdbEpisodeStills(
          tmdbSeriesId,
          _aniListDetail,
        );
      }
    }
    final posterUrl =
        _details?['_posterUrl'] as String? ?? widget.item.posterPath;

    final jikanByNum = <int, Map<String, dynamic>>{};
    for (final e in jikanEps) {
      final n = (e['mal_id'] as num?)?.toInt();
      if (n != null) jikanByNum[n] = e;
    }

    final out = <Map<String, dynamic>>[];
    for (var i = 1; i <= episodeCount; i++) {
      final je = jikanByNum[i];
      final jikanTitle = je?['title'] as String?;
      final name = (jikanTitle != null && jikanTitle.isNotEmpty)
          ? jikanTitle
          : anilistTitles[i] ?? 'Episode $i';
      final aired = je?['aired'] as String?;
      final duration = (je?['duration'] is num)
          ? (je?['duration'] as num).toInt()
          : null;

      final tmdb = tmdbStills[i];
      final tmdbStill = needsTmdbFallback ? tmdb?.stillUrl : null;
      final stillPath =
          anilistThumbs[i] ?? aniZipImages[i] ?? tmdbStill ?? posterUrl;

      out.add({
        'episode_number': i,
        'name': name,
        'overview': tmdb?.overview ?? '',
        'still_path': stillPath,
        'aired': aired,
        'duration': duration,
      });
    }
    return out;
  }

  Future<Map<int, ({String? stillUrl, String? overview})>>
  _fetchTmdbEpisodeStills(int tmdbSeriesId, AniListDetail? detail) async {
    final details = await _tmdbService.fetchMediaDetails(tmdbSeriesId, 'tv');
    if (details == null) return {};
    final seasons =
        (details['seasons'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (seasons.isEmpty) return {};

    final animeYear = detail?.seasonYear ?? int.tryParse(widget.item.year);
    int? bestSn;
    int bestScore = 9999;
    for (final s in seasons) {
      final sn = (s['season_number'] as num?)?.toInt();
      if (sn == null || sn <= 0) continue;
      final ad = s['air_date'] as String?;
      int score = 0;
      if (animeYear != null && ad != null && ad.length >= 4) {
        final sy = int.tryParse(ad.substring(0, 4));
        if (sy != null) score += ((animeYear - sy).abs() * 100).toInt();
      } else {
        score += 500;
      }
      if (score < bestScore) {
        bestScore = score;
        bestSn = sn;
      }
    }
    if (bestSn == null || bestScore > 200) {
      _tmdbMatchedSeason = null;
      return {};
    }
    _tmdbMatchedSeason = bestSn;

    final eps = await _tmdbService.fetchSeasonEpisodes(tmdbSeriesId, bestSn);
    final out = <int, ({String? stillUrl, String? overview})>{};
    for (final ep in eps) {
      if (ep is! Map<String, dynamic>) continue;
      final n = (ep['episode_number'] as num?)?.toInt();
      if (n == null || n <= 0) continue;
      final p = ep['still_path'] as String?;
      final o = ep['overview'] as String?;
      out[n] = (
        stillUrl: (p != null && p.isNotEmpty)
            ? TmdbImages.stillFor(p)
            : null,
        overview: (o != null && o.isNotEmpty) ? o : null,
      );
    }
    return out;
  }

  Future<void> _fetchCast() async {
    List<Map<String, dynamic>> cast;
    if (_isAnimeSourced) {
      AniListDetail? detail = _aniListDetail;
      if (detail == null) {
        detail = await _aniListService.fetchDetails(
          anilistId: widget.item.anilistId,
          malId: widget.item.tmdbId,
        );
        if (detail != null) _aniListDetail = detail;
      }
      cast = detail != null
          ? _mapAniListCharacters(detail.characters)
          : <Map<String, dynamic>>[];
    } else {
      cast = await _tmdbService.fetchCredits(
        widget.item.tmdbId,
        widget.item.mediaType,
      );
    }
    if (mounted) {
      setState(() {
        _cast = cast;
        _isLoadingCast = false;
      });
    }
  }

  List<Map<String, dynamic>> _mapAniListCharacters(
    List<AniListCharacter> characters,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final c in characters) {
      if (c.voiceActors.isEmpty) continue;
      for (final va in c.voiceActors) {
        out.add({
          'id': va.id,
          'name': va.name,
          'character': c.name,
          'profilePath': va.imageUrl,
        });
      }
    }
    return out;
  }

  Future<void> _fetchReviews() async {
    try {
      List<Map<String, dynamic>> reviews;
      if (_isAnimeSourced) {
        reviews = await _fetchJikanReviews(_effectiveMalId);
        if (reviews.isEmpty) {
          int? tmdbId = _aniSearchedTmdbId;
          if (tmdbId == null && widget.item.year.isNotEmpty) {
            tmdbId = await _tmdbService.searchTvShow(
              widget.item.title,
              firstAirDateYear: widget.item.year,
            );
          }
          if (tmdbId != null) {
            reviews = await _tmdbService.fetchReviews(tmdbId, 'tv');
          }
        }
      } else {
        reviews = await _tmdbService.fetchReviews(
          widget.item.tmdbId,
          widget.item.mediaType,
        );
      }
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint('_fetchReviews failed: $e');
      if (mounted) {
        setState(() {
          _reviews = [];
          _isLoadingReviews = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchJikanReviews(int malId) async {
    final entries = await _jikanService.fetchAnimeReviews(malId);
    return entries.take(8).map<Map<String, dynamic>>((r) {
      final user = (r['user'] as Map<String, dynamic>?) ?? const {};
      return {
        'id': r['mal_id'] ?? r['date'],
        'author': (user['username'] as String?) ?? 'Anonymous',
        'content': (r['review'] as String?) ?? '',
        'rating': r['score'],
        'createdAt': r['date'] ?? '',
        'avatar':
            (user['images'] as Map<String, dynamic>?)?['jpg']?['image_url'] ??
            '',
      };
    }).toList();
  }

  Future<void> _fetchSimilar() async {
    List<MediaItem> similar;
    if (_isAnimeSourced) {
      if (_aniListDetail == null) {
        final detail = await _aniListService.fetchDetailsWithFallback(
          anilistId: widget.item.anilistId,
          malId: widget.item.tmdbId,
        );
        if (detail != null && mounted) {
          _aniListDetail = detail;
        }
      }
      similar = _mapAniListRelated();
      if (similar.isEmpty) {
        similar = await _mapJikanRecommendations(_effectiveMalId);
      }
    } else {
      similar = await _tmdbService.fetchSimilar(
        widget.item.tmdbId,
        widget.item.mediaType,
      );
    }
    if (mounted) {
      setState(() {
        _similar = similar;
        _isLoadingSimilar = false;
      });
    }
  }

  Future<List<MediaItem>> _mapJikanRecommendations(int malId) async {
    final entries = await _jikanService.fetchAnimeRecommendations(malId);
    final out = <MediaItem>[];
    for (final e in entries) {
      final entry = e['entry'] as Map<String, dynamic>?;
      if (entry == null) continue;
      final id = (entry['mal_id'] as num?)?.toInt();
      if (id == null || id == 0) continue;
      final images = entry['images'] as Map<String, dynamic>?;
      final jpg = images?['jpg'] as Map<String, dynamic>?;
      final poster =
          (jpg?['large_image_url'] as String?) ??
          (jpg?['image_url'] as String?) ??
          '';
      out.add(
        MediaItem(
          id: '',
          tmdbId: id,
          title: (entry['title'] as String?) ?? 'Unknown',
          mediaType: 'tv',
          posterPath: poster,
          backdropPath: '',
          year: '',
          status: 'to-watch',
          isAnime: true,
          addedAt: DateTime.now(),
          source: 'jikan',
        ),
      );
    }
    return out;
  }

  List<MediaItem> _mapAniListRelated() {
    if (_aniListDetail == null) return const [];
    final out = <MediaItem>[];
    final seen = <int>{};
    for (final r in _aniListDetail!.relations) {
      if (r.id == 0 || seen.contains(r.id)) continue;
      seen.add(r.id);
      out.add(_relatedToMediaItem(r));
    }
    for (final r in _aniListDetail!.recommendations) {
      if (r.id == 0 || seen.contains(r.id)) continue;
      seen.add(r.id);
      out.add(_recommendationToMediaItem(r));
    }
    return out;
  }

  MediaItem _relatedToMediaItem(AniListRelated r) {
    final malId = r.malId ?? r.id;
    return MediaItem(
      id: '',
      tmdbId: malId,
      anilistId: r.id,
      title: r.title,
      mediaType: r.format == 'MOVIE' ? 'movie' : 'tv',
      posterPath: r.coverImageUrl,
      backdropPath: '',
      year: '',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime.now(),
      source: 'jikan',
      format: r.format,
    );
  }

  MediaItem _recommendationToMediaItem(AniListRecommended r) {
    return MediaItem(
      id: '',
      tmdbId: r.malId ?? r.id,
      anilistId: r.id,
      title: r.title,
      mediaType: 'tv',
      posterPath: r.coverImageUrl,
      backdropPath: '',
      year: '',
      status: 'to-watch',
      isAnime: true,
      addedAt: DateTime.now(),
      source: 'jikan',
    );
  }
}
