import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/utils/logger.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/anilist_detail.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/ani_zip_service.dart';
import 'package:everglow/features/cinema/data/services/anilist_service.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/services/auth_service.dart';
import 'package:everglow/features/watch_party/presentation/widgets/start_watch_party_button.dart';
import 'package:go_router/go_router.dart';
import 'episode_drawer_sections/drawer_helpers.dart';
import 'episode_drawer_sections/episode_list_section.dart';
import 'episode_drawer_sections/cast_section.dart';
import 'episode_drawer_sections/reviews_section.dart';
import 'episode_drawer_sections/similar_section.dart';
import 'episode_drawer_sections/trailer_section.dart';

class EpisodeDrawer extends StatefulWidget {
  final MediaItem item;

  const EpisodeDrawer({
    super.key,
    required this.item,
  });

  @override
  State<EpisodeDrawer> createState() => _EpisodeDrawerState();
}

class _EpisodeDrawerState extends State<EpisodeDrawer>
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

  /// Season navigation entries for anime (built from AniList SEQUEL/PREQUEL
  /// relations). Empty for TMDB-sourced items and for anime with no related
  /// seasons. Rendered as a horizontal pill strip below the meta section.
  List<SeasonNavItem> _animeSeasons = [];

  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _reviews = [];
  List<MediaItem> _similar = [];
  late String _currentStatus;
  List<String> _genreNames = [];

  /// AniList detail record, kept around for the synopsis / studio / format
  /// fields. We mirror a small subset into [_details] so the existing
  /// build logic (which reads `overview`, `genres`, etc. off the map) keeps
  /// working unchanged.
  AniListDetail? _aniListDetail;

  /// TMDB series ID found by the anime fallback (search or ani.zip). Used
  /// by [_fetchReviews] to try TMDB reviews when Jikan reviews are empty.
  int? _aniSearchedTmdbId;

  /// MAL ID resolved from the AniList detail response. Used for Jikan
  /// API calls and VideoPlayer navigation instead of [widget.item.tmdbId],
  /// which may be an AniList ID when navigating from season pills where
  /// the SEQUEL/PREQUEL relation has no `malId` cross-link.
  int? _resolvedMalId;

  /// Studio name when this is an anime item (e.g. "MAPPA"). Empty for
  /// non-anime items so the meta row just skips it.
  String get _studio => _isAnimeSourced
      ? (_aniListDetail?.studios.isNotEmpty == true
          ? _aniListDetail!.studios.first
          : widget.item.studio)
      : '';

  /// Format string (TV, TV Short, Movie, OVA, ONA, Special, Music) for
  /// anime items. Empty otherwise.
  String get _format => _isAnimeSourced
      ? (_aniListDetail?.format ?? widget.item.format)
      : '';

  /// Airing status (Airing / Finished Airing / Not yet aired) for anime
  /// items. Empty otherwise.
  String get _airingStatus => _isAnimeSourced
      ? (_aniListDetail?.airingStatus ?? widget.item.airingStatus)
      : '';

  /// True when the item was sourced from Jikan (i.e. an anime that came
  /// in via the Anime feature, not via TMDB discover). Drives which
  /// service we route the detail-page fetches to.
  bool get _isAnimeSourced => widget.item.source == 'jikan';
  
  // Trailer state
  String? _trailerKey;
  bool _isLoadingTrailer = false;
  bool _isPlayingTrailer = false;
  bool _isMobile = false;

  /// Controller for the horizontal status chip scroll area. On web,
  /// vertical mouse wheel deltas are converted to horizontal scroll
  /// so all status options are reachable without a horizontal scroll
  /// gesture or Shift+wheel.
  final _statusScrollCtrl = ScrollController();

  // For header parallax/fade
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.item.status;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchMediaDetails();
    _loadTrailer();
    _fetchCast();
    // Delay reviews by 4s so episode Jikan fetches can clear the queue,
    // reducing the chance of 429 rate-limit collisions.
    Future.delayed(const Duration(seconds: 4), _fetchReviews);
    _fetchSimilar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMobile = MediaQuery.of(context).size.width < 600;
  }

  @override
  void dispose() {
    _statusScrollCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrailer() async {
    setState(() => _isLoadingTrailer = true);
    try {
      String? key;
    if (_isAnimeSourced) {
      // AniList has a `trailer` field; we surface it for the hero
        // player when it's a YouTube id. We still call this after
        // [_fetchMediaDetails] has run, so we can read the resolved id
        // off [_aniListDetail] if it's available; otherwise we kick off
        // a fresh detail fetch and use it.
        final detail = _aniListDetail ??
            await _aniListService.fetchDetails(malId: _effectiveMalId);
        _aniListDetail ??= detail;
        key = detail?.trailerYoutubeId;
        // Last-resort fallback: ask Jikan for the trailer. Jikan's
        // /anime/{id} also embeds a YouTube trailer when licensed.
        key ??= await _jikanTrailerKey(_effectiveMalId);
      } else {
        key = await _tmdbService.fetchTrailerKey(
            widget.item.tmdbId, widget.item.mediaType);
      }
      if (mounted) {
        setState(() {
          _trailerKey = key;
          _isLoadingTrailer = false;
          // On mobile, auto-play the trailer as soon as the key is ready so
          // the user immediately sees it when they open the info sheet.
          // Desktop keeps the existing tap-to-play behavior.
          if (_isMobile && key != null) {
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

  /// Pulls a YouTube trailer id from Jikan's /anime/{id} payload. Jikan
  /// exposes a `trailer.youtube_id` field that's typically empty for
  /// non-Western-licensed shows but sometimes the only trailer source
  /// for older or niche anime.
  Future<String?> _jikanTrailerKey(int malId) async {
    try {
      final data = await _jikanService.fetchAnimeById(malId);
      final trailer = data?['trailer'] as Map<String, dynamic>?;
      final yt = trailer?['youtube_id'] as String?;
      if (yt != null && yt.isNotEmpty) return yt;
      // Jikan also embeds the trailer URL — fall back to parsing its v= param.
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

  /// Anime-sourced path. Pulls the AniList detail (the rich source for
  /// synopsis, genres, studio, characters, etc.) and projects it into
  /// the same shape [_details] / [_genreNames] / [_episodes] hold for
  /// TMDB-sourced items so the rest of the build method doesn't branch
  /// on source.
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
      'genres': detail.genres
          .map((g) => {'id': g, 'name': g})
          .toList(),
    };

    setState(() {
      _aniListDetail = detail;
      _resolvedMalId = detail.malId ?? widget.item.tmdbId;
      _details = mapped;
      _genreNames = detail.genres;
    });

    // Try using TMDB seasons like cinema. Resolve MAL→TMDB via ani.zip.
    final malId = _resolvedMalId ?? widget.item.tmdbId;
    int? tmdbSeriesId = await _aniZipService.fetchTmdbId(malId);
    if (tmdbSeriesId == null && widget.item.year.isNotEmpty) {
      tmdbSeriesId = await _tmdbService.searchTvShow(
        widget.item.title,
        firstAirDateYear: widget.item.year,
      );
    }

    if (tmdbSeriesId != null) {
      final tmdbDetails = await _tmdbService.fetchMediaDetails(tmdbSeriesId, 'tv');
      if (tmdbDetails != null && mounted) {
        final tmdbSeasons = (tmdbDetails['seasons'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .where((s) => (s['season_number'] is int) && (s['season_number'] as int) > 0)
            .toList() ?? [];
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

    // Fallback: synthetic Season 1 with Jikan episodes (legacy)
    final synthCount = detail.episodeCount != null && detail.episodeCount! > 0
        ? detail.episodeCount
        : 12;
    setState(() {
      _seasons = [
        {'season_number': 1, 'name': 'Episodes', 'episode_count': synthCount}
      ];
      _selectedSeasonNumber = 1;
      _fetchSeasonEpisodes(1);
    });
  }

  /// Builds the season navigation list from AniList SEQUEL/PREQUEL relations.
  /// Includes the current anime as the "Current" entry and all related seasons
  /// (SEQUEL = next, PREQUEL = previous). Sorted so PREQUELs appear first,
  /// then Current, then SEQUELs. Empty list when there's only 1 season.
  List<SeasonNavItem> _buildAnimeSeasons(AniListDetail detail) {
    final list = <SeasonNavItem>[];
    for (final r in detail.relations) {
    }
    list.add(SeasonNavItem(
      id: detail.id,
      malId: detail.malId ?? widget.item.tmdbId,
      title: detail.titleEnglish.isNotEmpty ? detail.titleEnglish : detail.titleRomaji,
      coverImageUrl: detail.coverImageUrl,
      isCurrent: true,
      relationType: 'CURRENT',
    ));

    for (final r in detail.relations) {
      if (r.relationType != 'SEQUEL' && r.relationType != 'PREQUEL') continue;
      list.add(SeasonNavItem(
        id: r.id,
        malId: r.malId ?? r.id,
        title: r.title,
        coverImageUrl: r.coverImageUrl,
        isCurrent: false,
        relationType: r.relationType,
      ));
    }

    // Only show navigation if there are other seasons to navigate to
    if (list.length <= 1) return const [];

    // Sort: PREQUELs first, CURRENT, SEQUELs last
    const order = {'PREQUEL': 0, 'CURRENT': 1, 'SEQUEL': 2};
    list.sort((a, b) =>
        (order[a.relationType] ?? 3).compareTo(order[b.relationType] ?? 3));

    return list;
  }

  /// TMDB path (unchanged). Kept as its own method so the source
  /// branching in [_fetchMediaDetails] reads cleanly.
  Future<void> _fetchTmdbDetails() async {
    final details = await _tmdbService.fetchMediaDetails(
        widget.item.tmdbId, widget.item.mediaType);
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
            _selectedSeasonNumber = firstSeason['season_number'];
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
    setState(() {
      _isLoadingEpisodes = true;
      _episodes = [];
      _tmdbMatchedSeason = null;
    });
    if (_isAnimeSourced && _aniSearchedTmdbId != null) {
      // Use TMDB season data like cinema for anime with a TMDB mapping.
      final episodes = await _tmdbService.fetchSeasonEpisodes(
          _aniSearchedTmdbId!, seasonNumber);
      if (mounted && _selectedSeasonNumber == seasonNumber) {
        setState(() {
          _episodes = episodes;
          _isLoadingEpisodes = false;
        });
      }
      return;
    }
    if (_isAnimeSourced) {
      // Fallback: Jikan-sourced episodes for anime without TMDB mapping.
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
        widget.item.tmdbId, seasonNumber);
    if (mounted && _selectedSeasonNumber == seasonNumber) {
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
      });
    }
  }

  /// Pulls the full MAL episode list for an anime and projects it into
  /// the TMDB-shaped map the existing [_buildEpisodeTile] reads. Keys:
  /// `episode_number`, `name`, `overview`, `still_path`, `aired`,
  /// `duration`.
  ///
  /// Four sources, merged in priority order:
  ///   1. Jikan's `/anime/{id}/episodes` — real titles, air dates,
  ///      durations for essentially every show.
  ///   2. AniList's `streamingEpisodes` overlay — fills in titles and
  ///      licensed stills (Western-licensed shows) for Jikan gaps.
  ///   3. ani.zip's TVDB-sourced `episodes[].image` — per-episode
  ///      stills. This is the primary thumbnail source for non-Western
  ///      shows; it's also what the AniList streaming stills fall back
  ///      to when AniList's payload is sparse.
  ///   4. Placeholder `Episode N` — last resort when no source has a
  ///      title for that slot.
  ///
  /// Thumbnails: when an AniList still exists for an episode we prefer
  /// it (better-looking, already CDN-cached). Otherwise we use the
  /// TVDB still from ani.zip. If both are missing, `still_path` stays
  /// null and the [EpisodeTile] falls back to a gradient + episode
  /// number — never a broken image box.
  Future<List<Map<String, dynamic>>> _fetchJikanEpisodes(int malId) async {
    // Fire Jikan + ani.zip in parallel — they're independent and the
    // network wait dominates the total time on slow links.
    final jikanFuture = _jikanService.fetchAnimeEpisodes(malId);
    final animeByIdFuture = _jikanService.fetchAnimeById(malId);
    final aniZipFuture = _aniZipService.fetchEpisodeImages(malId);
    final jikanEps = await jikanFuture;
    final anime = await animeByIdFuture;
    final aniZipImages = await aniZipFuture;

    // Pick the loop bound carefully. Three signals matter:
    //   1. Jikan `/anime/{id}` → `episodes` = total announced episode
    //      count for the whole series (e.g. 24 for an airing show).
    //   2. Jikan `/anime/{id}/episodes` → only aired episodes with
    //      titles (e.g. 10 for the same show mid-season).
    //   3. ani.zip → TVDB-sourced, may cover aired + scheduled.
    //
    // If we blindly used #1, an airing show would render 14 placeholder
    // "Episode N" rows for episodes that haven't aired yet. Instead we
    // cap at the highest episode number we actually have *any* signal
    // for — Jikan aired count or ani.zip count, whichever is bigger.
    final announcedCount = (anime?['episodes'] is num)
        ? (anime?['episodes'] as num).toInt()
        : 0;
    final jikanMaxNum = jikanEps
        .map((e) => (e['mal_id'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final aniZipMaxNum = aniZipImages.keys.fold<int>(0, (a, b) => a > b ? a : b);
    final maxKnown = jikanMaxNum > aniZipMaxNum ? jikanMaxNum : aniZipMaxNum;

    int episodeCount;
    if (maxKnown > 0) {
      // At least one source has aired/scheduled data. Cap to that so
      // we don't render empty placeholders for unaired episodes.
      episodeCount = maxKnown;
      // If Jikan's announced count is *lower* than what we've found
      // (e.g. an OVA that bumps the count up after the main series
      // finishes), respect the higher number.
      if (announcedCount > episodeCount) episodeCount = announcedCount;
    } else {
      // No aired data from any source — fall back to the announced
      // count or 12 as a last resort, so the UI still renders rows
      // with placeholder titles.
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

    // Always fetch TMDB episode data for overviews (descriptions).
    // TMDB stills are only preferred as a fallback when anime-source
    // thumbnails (AniList / ani.zip) are sparse.
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
        tmdbStills =
            await _fetchTmdbEpisodeStills(tmdbSeriesId, _aniListDetail);
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
      final duration =
          (je?['duration'] is num) ? (je?['duration'] as num).toInt() : null;

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

  /// TMDB fallback for anime episode stills + overviews. Matches the
  /// anime's broadcast year (from AniList) against TMDB seasons'
  /// air_date to find the right season number, then fetches per-episode
  /// data. Returns the episode-number -> {stillUrl, overview} map;
  /// empty on any miss.
  Future<Map<int, ({String? stillUrl, String? overview})>>
      _fetchTmdbEpisodeStills(
          int tmdbSeriesId, AniListDetail? detail) async {
    final details =
        await _tmdbService.fetchMediaDetails(tmdbSeriesId, 'tv');
    if (details == null) return {};
    final seasons = (details['seasons'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    if (seasons.isEmpty) return {};

    // Match by broadcast year. Different seasons of the same anime
    // almost always air in different years, so year alone disambiguates.
    final animeYear =
        detail?.seasonYear ?? int.tryParse(widget.item.year);
    int? bestSn;
    int bestScore = 9999;
    for (final s in seasons) {
      final sn = (s['season_number'] as num?)?.toInt();
      if (sn == null || sn <= 0) continue; // skip specials
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

    final eps =
        await _tmdbService.fetchSeasonEpisodes(tmdbSeriesId, bestSn);
    final out = <int, ({String? stillUrl, String? overview})>{};
    for (final ep in eps) {
      if (ep is! Map<String, dynamic>) continue;
      final n = (ep['episode_number'] as num?)?.toInt();
      if (n == null || n <= 0) continue;
      final p = ep['still_path'] as String?;
      final o = ep['overview'] as String?;
      out[n] = (
        stillUrl: (p != null && p.isNotEmpty)
            ? 'https://image.tmdb.org/t/p/w300$p'
            : null,
        overview: (o != null && o.isNotEmpty) ? o : null,
      );
    }
    return out;
  }

  Future<void> _fetchCast() async {
    List<Map<String, dynamic>> cast;
    if (_isAnimeSourced) {
      // `_aniListDetail` is populated by the parallel `_fetchMediaDetails`
      // call, but it almost always races ahead of us and reads as null
      // on first open. Pull directly here — AniListService caches
      // details in-memory for 30 min keyed on the MAL/AniList id, so
      // this is a cache hit whenever `_fetchAnimeDetails` already ran.
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
          widget.item.tmdbId, widget.item.mediaType);
    }
    if (mounted) {
      setState(() {
        _cast = cast;
        _isLoadingCast = false;
      });
    }
  }

  /// Convert AniList's character edges into the TMDB-shaped cast map
  /// the existing UI renders. For each character we emit one entry per
  /// Japanese voice actor (so a character with multiple VAs yields
  /// multiple rows). `character` holds the role name, `name` holds the
  /// VA, mirroring the TMDB convention.
  List<Map<String, dynamic>> _mapAniListCharacters(
      List<AniListCharacter> characters) {
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
        // If Jikan returned no reviews, try TMDB as a fallback.
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
            widget.item.tmdbId, widget.item.mediaType);
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

  /// Fetches MAL user reviews via Jikan's /anime/{id}/reviews endpoint
  /// and projects them into the TMDB-shaped review map.
  ///
  /// Now routed through [JikanService.fetchAnimeReviews] so the call
  /// respects the rate-limit queue and exponential backoff. The
  /// previous direct `http.get` path used here was prone to 429
  /// errors during the Editor's Picks fan-out — the queue serializes
  /// requests and the exponential backoff is already tuned for Jikan.
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
        'avatar': (user['images'] as Map<String, dynamic>?)?['jpg']?['image_url'] ?? '',
      };
    }).toList();
  }

  Future<void> _fetchSimilar() async {
    List<MediaItem> similar;
    if (_isAnimeSourced) {
      // Race condition: `_fetchMediaDetails()` populates `_aniListDetail`
      // asynchronously, but `_fetchSimilar()` is kicked off in the
      // same `initState` burst, so reading `_aniListDetail` here
      // almost always returns null and the AniList relations are
      // silently dropped. We await the detail directly — the
      // [AniListService] has its own 10-min cache so this is a
      // cache-hit whenever `_fetchMediaDetails()` ran first.
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
      // AniList's `recommendations` field is sparse for most titles
      // (often zero entries) and `relations` is sometimes empty for
      // one-shots. Fall back to Jikan's `/anime/{id}/recommendations`
      // so the rail is rarely empty.
      if (similar.isEmpty) {
        similar = await _mapJikanRecommendations(_effectiveMalId);
      }
    } else {
      similar = await _tmdbService.fetchSimilar(
          widget.item.tmdbId, widget.item.mediaType);
    }
    if (mounted) {
      setState(() {
        _similar = similar;
        _isLoadingSimilar = false;
      });
    }
  }

  /// Pulls Jikan's user-recommendation rail and projects the entries
  /// into [MediaItem]s the existing `_buildSimilarSection` can render
  /// without changes. Jikan returns `entry` blocks where `mal_id` is
  /// the recommended title and `images.jpg.large_image_url` is the
  /// cover art.
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
      final poster = (jpg?['large_image_url'] as String?) ??
          (jpg?['image_url'] as String?) ??
          '';
      out.add(MediaItem(
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
      ));
    }
    return out;
  }

  /// Combines AniList's relations (sequels, prequels, side stories) and
  /// user recommendations into a single "More Like This" rail. Relations
  /// come first because they share universe/characters and are usually
  /// what the user is hunting for.
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
    // The drawer treats `MediaItem.tmdbId` as the MAL id for
    // anime-sourced items, so we need the MAL cross-reference here.
    // AniList's native `id` was used previously — which silently
    // routed every relation to a non-existent MAL entry and left
    // the new drawer's detail page blank.
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

  Future<void> _updateStatus(String newStatus) async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      _showSnack('Please sign in to manage your watchlist');
      return;
    }
    // Save the previous status so we can revert locally if the Firestore
    // write fails. Without this, a network error in isAnimeByTmdbId or
    // saveToWatchList would leave the chip highlighted (from the early
    // setState) while the document in Firestore still has the old status —
    // making the change appear to "revert" the next time the stream fires.
    final previousStatus = _currentStatus;

    if (_currentStatus == newStatus) {
      // Tapping the already-selected chip → remove from watchlist.
      setState(() => _currentStatus = '');
      try {
        await _tmdbService.removeFromWatchList(widget.item.tmdbId, userName);
        if (mounted) _showSnack('Removed from watchlist');
      } catch (e) {
        Logger.e('Failed to remove from watchlist', error: e);
        if (mounted) {
          setState(() => _currentStatus = previousStatus);
          _showSnack('Failed to remove — please try again');
        }
      }
    } else {
      // Optimistically update the chip UI.
      setState(() => _currentStatus = newStatus);
      try {
        // Auto-detect anime so the dashboard's Anime rail picks it up
        // automatically. We do this against TMDB /details because that's the
        // only endpoint that reliably returns `original_language` + nested
        // `genres` for TV. If the network call fails we just fall back to
        // whatever the item already has.
        bool? detectedAnime;
        if (!widget.item.isAnime) {
          try {
            detectedAnime = await _tmdbService.isAnimeByTmdbId(
              widget.item.tmdbId,
              widget.item.mediaType,
            );
          } catch (_) {
            // Anime detection is best-effort; don't let a TMDB failure
            // block the status save.
          }
        }
        // Use the poster URL from the fetched details when the item from
        // Firestore didn't have one (e.g. older items saved before posterPath
        // was stored). This ensures the dashboard cards get their images.
        final resolvedItem = _resolvePosterFromDetails(widget.item);

        await _tmdbService.saveToWatchList(
          resolvedItem,
          newStatus,
          userName,
          isAnimeOverride: detectedAnime,
        );
        if (mounted) _showSnack('Watchlist updated');
      } catch (e) {
        Logger.e('Failed to update watchlist status', error: e);
        if (mounted) {
          setState(() => _currentStatus = previousStatus);
          _showSnack('Failed to update — please try again');
        }
      }
    }
  }

  /// When the item from Firestore has an empty posterPath, pull the
  /// poster from the TMDB or AniList details that were fetched when
  /// the drawer opened. This backfills missing posters on save.
  MediaItem _resolvePosterFromDetails(MediaItem item) {
    if (item.posterPath.isNotEmpty) return item;

    final String? resolvedPoster;
    final String? resolvedBackdrop;

    if (_isAnimeSourced) {
      // AniList stores the full URL in _posterUrl / _backdropUrl.
      resolvedPoster = _details?['_posterUrl'] as String?;
      resolvedBackdrop = _details?['_backdropUrl'] as String?;
    } else {
      // TMDB poster_path is a relative path — prepend the base URL.
      final rawPoster = _details?['poster_path'] as String?;
      resolvedPoster = rawPoster != null && rawPoster.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w500$rawPoster'
          : null;
      final rawBackdrop = _details?['backdrop_path'] as String?;
      resolvedBackdrop = rawBackdrop != null && rawBackdrop.isNotEmpty
          ? 'https://image.tmdb.org/t/p/w780$rawBackdrop'
          : null;
    }

    if (resolvedPoster == null && resolvedBackdrop == null) return item;

    return item.copyWith(
      posterPath: resolvedPoster ?? item.posterPath,
      backdropPath: resolvedBackdrop ?? item.backdropPath,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: AppColors.petalWhite)),
        backgroundColor: AppColors.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int get _effectiveMalId => _resolvedMalId ?? widget.item.tmdbId;

  void _playMovie() {
    final id = _isAnimeSourced ? _effectiveMalId : widget.item.tmdbId;
    final malIdParam = _isAnimeSourced ? '&malId=$_effectiveMalId' : '';
    context.push('/cinema/video/$id?type=movie&title=${Uri.encodeComponent(widget.item.title)}&anime=$_isAnimeSourced$malIdParam');
  }

  void _playEpisode(int season, int episode, String epTitle) {
    final id = _isAnimeSourced ? _effectiveMalId : widget.item.tmdbId;
    final malIdParam = _isAnimeSourced ? '&malId=$_effectiveMalId' : '';
    final title = '${cleanTitle(widget.item.title)}: $epTitle';
    context.push('/cinema/video/$id?type=tv&title=${Uri.encodeComponent(title)}&season=$season&episode=$episode&anime=$_isAnimeSourced$malIdParam');
  }

  void _showSimilarItem(MediaItem item) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpisodeDrawer(item: item),
    );
  }

  /// Navigates to a different season of the same anime series. Closes the
  /// current drawer and opens a new [EpisodeDrawer] for the target season
  /// entry. No-op when the target is the current season.
  void _switchAnimeSeason(SeasonNavItem season) {
    if (season.isCurrent) return;
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpisodeDrawer(
        item: MediaItem(
          id: '',
          tmdbId: season.malId ?? season.id,
          anilistId: season.id,
          title: season.title,
          mediaType: 'tv',
          posterPath: season.coverImageUrl ?? '',
          backdropPath: '',
          year: '',
          status: 'to-watch',
          isAnime: true,
          addedAt: DateTime.now(),
          source: 'jikan',
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final ratingNum = _details?['vote_average'] as num?;
    final rating = ratingNum != null ? ratingNum.toDouble().toStringAsFixed(1) : 'N/A';
    // For anime we don't have TMDB's `release_date` / `first_air_date`,
    // so we fall back to AniList's `seasonYear` and finally to whatever
    // the MediaItem already remembers from Jikan's discover payload.
    String releaseDate;
    if (_isAnimeSourced) {
      releaseDate = widget.item.year;
    } else if (widget.item.mediaType == 'movie') {
      releaseDate = (_details?['release_date'] ?? '') as String;
    } else {
      releaseDate = (_details?['first_air_date'] ?? '') as String;
    }
    final year = releaseDate.isNotEmpty
        ? releaseDate.split('-')[0]
        : widget.item.year;
    final episodeRunTimes = _details?['episode_run_time'] as List?;
    // Anime-sourced runtime comes from AniList's `duration` field
    // (in minutes per episode). We surface it in the same slot so the
    // hero header shows a single "Xm" badge next to the rating.
    final runtime = _isAnimeSourced
        ? (_details?['_duration'])
        : (_details?['runtime'] ??
            (episodeRunTimes != null && episodeRunTimes.isNotEmpty
                ? episodeRunTimes.first
                : null));
    final backdropPath = _details?['backdrop_path'];
    // For anime, backdrop is a fully-qualified AniList CDN URL stored on
    // `_details[_backdropUrl]`; for TMDB it's a path that we need to
    // prefix with the image CDN. The MediaItem itself also carries a
    // pre-built URL from discover/search which we use as a final
    // fallback so the hero never renders as a flat gray rectangle.
    String? backdropUrl;
    if (_isAnimeSourced) {
      final aniBackdrop = _details?['_backdropUrl'] as String?;
      backdropUrl = (aniBackdrop != null && aniBackdrop.isNotEmpty)
          ? aniBackdrop
          : widget.item.backdropPath.isNotEmpty
              ? widget.item.backdropPath
              : widget.item.posterPath;
    } else {
      backdropUrl = backdropPath != null
          ? 'https://image.tmdb.org/t/p/w780$backdropPath'
          : widget.item.backdropPath.isNotEmpty
              ? widget.item.backdropPath
              : widget.item.posterPath;
    }
    final ratingVal = double.tryParse(rating) ?? 0;
    final ratingFraction = (ratingVal / 10).clamp(0.0, 1.0);

    return FractionallySizedBox(
      heightFactor: 0.93,
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.deepBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
            // ── HERO BACKDROP ──
            SliverToBoxAdapter(
              child: TrailerSection(
                backdropUrl: backdropUrl ?? '',
                trailerKey: _trailerKey,
                isLoadingTrailer: _isLoadingTrailer,
                isPlayingTrailer: _isPlayingTrailer,
                isMobile: _isMobile,
                year: year,
                rating: rating,
                ratingFraction: ratingFraction,
                runtime: runtime,
                title: widget.item.title,
                isDetailsLoading: _details == null,
                onToggleTrailer: () => setState(() => _isPlayingTrailer = true),
                onCloseTrailer: () => setState(() => _isPlayingTrailer = false),
                onClose: () => Navigator.pop(context),
              ),
            ),

            // ── META + ACTIONS ──
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildMetaSection(year, rating, ratingFraction, runtime),
              ),
            ),

            if (widget.item.mediaType == 'movie')
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      _buildPlayButton(),
                      const SizedBox(height: 10),
                      if (context.watch<AuthService>().isCoupleUser)
                        StartWatchPartyButton(
                          media: MediaRef(
                            tmdbId: _isAnimeSourced
                                ? _effectiveMalId
                                : widget.item.tmdbId,
                            malId: _isAnimeSourced ? _effectiveMalId : null,
                            mediaType: 'movie',
                            isAnime: _isAnimeSourced,
                            title: widget.item.title,
                            posterPath: widget.item.posterPath,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: EpisodeListSection(
                  episodes: _episodes,
                  seasons: _seasons,
                  selectedSeasonNumber: _selectedSeasonNumber,
                  isLoadingEpisodes: _isLoadingEpisodes,
                  tmdbMatchedSeason: _tmdbMatchedSeason,
                  isAnimeSourced: _isAnimeSourced,
                  effectiveMalId: _effectiveMalId,
                  item: widget.item,
                  isCouple: context.watch<AuthService>().isCoupleUser,
                  onPlayEpisode: _playEpisode,
                  onSeasonChanged: (sn) {
                    setState(() => _selectedSeasonNumber = sn);
                    _fetchSeasonEpisodes(sn);
                  },
                ),
              ),

            // ── CAST ──
            SliverToBoxAdapter(
                child: buildDrawerSectionHeader(
                    _isAnimeSourced ? 'Voice Cast' : 'Cast')),
            SliverToBoxAdapter(
              child: CastSection(
                cast: _cast,
                isLoading: _isLoadingCast,
                isAnimeSourced: _isAnimeSourced,
              ),
            ),

            // ── REVIEWS ──
            SliverToBoxAdapter(
                child: buildDrawerSectionHeader('Reviews')),
            SliverToBoxAdapter(
              child: ReviewsSection(
                reviews: _reviews,
                isLoading: _isLoadingReviews,
              ),
            ),

            // ── MORE LIKE THIS ──
            SliverToBoxAdapter(
                child: buildDrawerSectionHeader("Mochi says… 🐱")),
            SliverToBoxAdapter(
              child: SimilarSection(
                similar: _similar,
                isLoading: _isLoadingSimilar,
                onItemTap: _showSimilarItem,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // META SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMetaSection(
      String year, String rating, double ratingFraction, dynamic runtime) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Genre chips
          if (_genreNames.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _genreNames.map((g) => _buildGenreChip(g)).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Anime-specific meta row: studio + format + airing status + next episode countdown.
          // This is hidden for non-anime items because those fields
          // don't have meaningful TMDB equivalents.
          if (_isAnimeSourced &&
              (_studio.isNotEmpty ||
                  _format.isNotEmpty ||
                  _airingStatus.isNotEmpty)) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_studio.isNotEmpty) _buildAnimeFactChip(_studio, Icons.movie_creation_outlined),
                if (_format.isNotEmpty) _buildAnimeFactChip(_format, Icons.tv_rounded),
                if (_airingStatus.isNotEmpty) _buildAnimeFactChip(_airingStatus, Icons.fiber_manual_record_rounded),
                if (_aniListDetail?.nextAiringAt != null) _buildAiringCountdownChip(_aniListDetail!.nextAiringAt!, _aniListDetail!.nextAiringEpisode),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // Watchlist label + status chips
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.deepRose,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'WATCHLIST STATUS',
                style: GoogleFonts.outfit(
                  color: AppColors.mutedPurple,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Cinema-only profiles (Breyan, Octagram) only get generic
          // "Want to Watch" / "Watched" — never the partner-specific chips,
          // which would leak Khent/Clair semantics.
          Builder(builder: (context) {
            final isCinemaOnly =
                context.watch<AuthService>().isCinemaOnlyUser;
            final chips = isCinemaOnly
                ? Row(
                    children: [
                      _buildStatusChip('Want to Watch', 'to-watch',
                          icon: Icons.bookmark_rounded),
                      const SizedBox(width: 8),
                      _buildStatusChip('Currently Watching', 'watching-self',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: const Color(0xFFFF6D00)),
                      const SizedBox(width: 8),
                      _buildStatusChip('Watched', 'watched-self',
                          icon: Icons.check_circle_rounded,
                          activeColor: const Color(0xFF2E7D32)),
                    ],
                  )
                : Row(
                    children: [
                      _buildStatusChip('Want to Watch', 'to-watch',
                          icon: Icons.bookmark_rounded),
                      const SizedBox(width: 8),
                      _buildStatusChip('Khent Watching', 'watching-khent',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: const Color(0xFFFF6D00)),
                      const SizedBox(width: 8),
                      _buildStatusChip('Clair Watching', 'watching-clair',
                          icon: Icons.play_circle_filled_rounded,
                          activeColor: const Color(0xFFE91E8C)),
                      const SizedBox(width: 8),
                      _buildStatusChip('Khent Watched', 'watched-khent',
                          icon: Icons.person_rounded,
                          activeColor: const Color(0xFF1976D2)),
                      const SizedBox(width: 8),
                      _buildStatusChip('Clair Watched', 'watched-clair',
                          icon: Icons.favorite_rounded,
                          activeColor: const Color(0xFFE91E8C)),
                      const SizedBox(width: 8),
                      _buildStatusChip('Both Watched', 'watched-both',
                          icon: Icons.people_rounded,
                          activeColor: const Color(0xFF2E7D32)),
                    ],
                  );
            return Scrollbar(
              thumbVisibility: true,
              controller: _statusScrollCtrl,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                controller: _statusScrollCtrl,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent &&
                        event.scrollDelta.dy != 0) {
                      final ctrl = _statusScrollCtrl;
                      final clamped = (ctrl.offset + event.scrollDelta.dy)
                          .clamp(ctrl.position.minScrollExtent,
                              ctrl.position.maxScrollExtent);
                      ctrl.jumpTo(clamped);
                    }
                  },
                  child: chips,
                ),
              ),
            );
          }),
          const SizedBox(height: 20),

          // Overview
          if (_details?['overview'] != null &&
              (_details!['overview'] as String).isNotEmpty) ...[
            Text(
              _details!['overview'],
              style: GoogleFonts.outfit(
                color: AppColors.petalWhite.withValues(alpha: 0.75),
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PLAY BUTTON
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _playMovie,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.deepRose, Color(0xFF8E1444)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'PLAY MOVIE',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ANIME SEASON NAV
  // ═══════════════════════════════════════════════════════════════

  /// Horizontal pill strip showing all available seasons for this anime.
  /// The current season is highlighted in rose; tapping another season
  /// navigates to its episode drawer. Only rendered when there are 2+
  /// seasons (current + at least one related).
  Widget _buildAnimeSeasonNav() {
    if (!_isAnimeSourced || _animeSeasons.length <= 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.deepRose,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SEASONS',
                style: GoogleFonts.outfit(
                  color: AppColors.mutedPurple,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _animeSeasons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final s = _animeSeasons[index];
                final isCurrent = s.isCurrent;
                return GestureDetector(
                  onTap: () => _switchAnimeSeason(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.deepRose.withValues(alpha: 0.2)
                          : AppColors.shimmerBase,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.deepRose
                            : AppColors.roseQuartz.withValues(alpha: 0.15),
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.coverImageUrl != null &&
                            s.coverImageUrl!.isNotEmpty &&
                            !isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                s.coverImageUrl!,
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        if (isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.play_arrow_rounded,
                                color: AppColors.deepRose, size: 14),
                          ),
                        Flexible(
                          child: Text(
                            // Shorten long titles to fit the pill
                            s.title.length > 28
                                ? '${s.title.substring(0, 26)}…'
                                : s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: isCurrent ? AppColors.deepRose : AppColors.petalWhite.withValues(alpha: 0.8),
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (!isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.mutedPurple,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGenreChip(String name) {
    // Assign a color per genre for distinction
    final colors = [
      AppColors.deepRose,
      AppColors.warmAmber,
      AppTheme.softLavender,
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
      const Color(0xFF9C27B0),
    ];
    final color = name.isEmpty
        ? AppColors.deepRose
        : colors[name.codeUnitAt(0) % colors.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        name,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Smaller chip used for anime-specific facts (studio, format, airing
  /// status). Renders a leading icon and a tighter padding than the
  /// genre chip so the three facts fit on one row at mobile width.
  Widget _buildAnimeFactChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blushGold, size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: AppColors.blushGold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Live countdown chip showing time until the next episode airs. Uses a
  /// one-minute timer to keep the countdown accurate without excessive
  /// rebuilds. The chip is pulsing-animated to draw attention and only
  /// rendered when AniList provides a `nextAiringAt` timestamp.
  Widget _buildAiringCountdownChip(int nextAiringAtSeconds, int? nextEpisode) {
    return _AiringCountdownChip(
      nextAiringAt: nextAiringAtSeconds,
      nextEpisode: nextEpisode,
    );
  }

  Widget _buildStatusChip(
    String label,
    String status, {
    IconData icon = Icons.check_circle_rounded,
    Color activeColor = AppColors.deepRose,
  }) {
    final isSelected = _currentStatus == status;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.7)
                : AppColors.roseQuartz.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color:
                  isSelected ? activeColor : AppColors.mutedPurple,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? activeColor : AppColors.mutedPurple,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live countdown chip that ticks every minute showing time until the next
/// episode airs. Self-contained StatefulWidget so it can manage its own
/// timer lifecycle without cluttering the drawer state.
class _AiringCountdownChip extends StatefulWidget {
  final int nextAiringAt;
  final int? nextEpisode;
  const _AiringCountdownChip({required this.nextAiringAt, this.nextEpisode});

  @override
  State<_AiringCountdownChip> createState() => _AiringCountdownChipState();
}

class _AiringCountdownChipState extends State<_AiringCountdownChip> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatCountdown() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = widget.nextAiringAt - now;
    if (diff <= 0) return 'Airing now';
    final d = diff ~/ 86400;
    final h = (diff % 86400) ~/ 3600;
    final m = (diff % 3600) ~/ 60;
    if (d > 0) return '${d}d ${h}h';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.nextEpisode != null
        ? 'Ep ${widget.nextEpisode} in ${_formatCountdown()}'
        : 'Next in ${_formatCountdown()}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.deepRose.withValues(alpha: 0.25),
            AppColors.deepRose.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.deepRose.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: AppColors.deepRose, size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: AppColors.deepRose,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
