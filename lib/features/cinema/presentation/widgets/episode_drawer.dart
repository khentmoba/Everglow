import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/anilist_detail.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/anilist_service.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/services/auth_service.dart';
import '../screens/video_player_screen.dart';
import 'trailer_player.dart';

// Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬
// Cinema token aliases (mirror cinema_screen.dart)
// Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬Ã¢â€ â‚¬
const _cBlack = Color(0xFF080810);
const _cVelvet = Color(0xFF12091A);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

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
  bool _isLoadingEpisodes = false;
  bool _isLoadingCast = true;
  bool _isLoadingReviews = true;
  bool _isLoadingSimilar = true;
  Map<String, dynamic>? _details;
  List<dynamic> _seasons = [];
  int? _selectedSeasonNumber;
  List<dynamic> _episodes = [];
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
    _fetchReviews();
    _fetchSimilar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMobile = MediaQuery.of(context).size.width < 600;
  }

  @override
  void dispose() {
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
            await _aniListService.fetchDetails(malId: widget.item.tmdbId);
        _aniListDetail ??= detail;
        key = detail?.trailerYoutubeId;
        // Last-resort fallback: ask Jikan for the trailer. Jikan's
        // /anime/{id} also embeds a YouTube trailer when licensed.
        key ??= await _jikanTrailerKey(widget.item.tmdbId);
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
      print('Error loading trailer: $e');
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
    } catch (_) {}
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
      print('Error fetching media details: $e');
    }
  }

  /// Anime-sourced path. Pulls the AniList detail (the rich source for
  /// synopsis, genres, studio, characters, etc.) and projects it into
  /// the same shape [_details] / [_genreNames] / [_episodes] hold for
  /// TMDB-sourced items so the rest of the build method doesn't branch
  /// on source.
  Future<void> _fetchAnimeDetails() async {
    final detail = await _aniListService.fetchDetails(
      anilistId: widget.item.anilistId,
      malId: widget.item.tmdbId,
    );
    if (!mounted) return;
    if (detail == null) {
      setState(() {
        _details = {};
        _isLoadingEpisodes = false;
      });
      return;
    }
    // Build a TMDB-shaped map for the build method to read. We carry
    // the cover/banner URLs as `backdrop_path` / `poster_path` so the
    // hero header still renders.
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
      _details = mapped;
      _genreNames = detail.genres;
      // Anime has no seasons — render the flat episode list as a
      // synthetic "Season 1" so the existing UI keeps working.
      _seasons = detail.episodeCount != null && detail.episodeCount! > 0
          ? [
              {'season_number': 1, 'name': 'Episodes', 'episode_count': detail.episodeCount}
            ]
          : const [];
      _selectedSeasonNumber = _seasons.isNotEmpty ? 1 : null;
      if (_selectedSeasonNumber != null) {
        _fetchSeasonEpisodes(_selectedSeasonNumber!);
      }
    });
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
    setState(() => _isLoadingEpisodes = true);
    if (_isAnimeSourced) {
      final episodes = await _fetchJikanEpisodes(widget.item.tmdbId);
      if (!mounted) return;
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
      });
      return;
    }
    final episodes = await _tmdbService.fetchSeasonEpisodes(
        widget.item.tmdbId, seasonNumber);
    if (mounted) {
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
      });
    }
  }

  /// Pulls the full MAL episode list for an anime and projects it into
  /// the TMDB-shaped map the existing [_buildEpisodeTile] reads. Keys:
  /// `episode_number`, `name`, `overview`, `still_path`.
  Future<List<Map<String, dynamic>>> _fetchJikanEpisodes(int malId) async {
    final data = await _jikanService.fetchAnimeById(malId);
    if (data == null) return [];
    // We hit /anime/{id} which returns the show's full record including
    // an `episodes` count, not the per-episode list. The episode list
    // lives on /anime/{id}/episodes — but Jikan doesn't expose a single
    // helper for it on the service yet. For brevity, we synthesize
    // numbered slots using the recorded episode count when no
    // per-episode data is available. AniList's `streamingEpisodes` gives
    // us real titles when licensed, and we merge those in.
    final episodeCount = (data['episodes'] is num)
        ? (data['episodes'] as num).toInt()
        : 0;
    final titles = <int, String>{};
    final anilistEpisodes = _aniListDetail?.episodes ?? const [];
    for (final ep in anilistEpisodes) {
      final t = ep.title;
      if (t != null && t.isNotEmpty) {
        titles[ep.number] = t;
      }
    }
    final out = <Map<String, dynamic>>[];
    for (var i = 1; i <= episodeCount; i++) {
      out.add({
        'episode_number': i,
        'name': titles[i] ?? 'Episode $i',
        'overview': '',
        'still_path': null,
      });
    }
    return out;
  }

  Future<void> _fetchCast() async {
    List<Map<String, dynamic>> cast;
    if (_isAnimeSourced) {
      cast = _aniListDetail != null
          ? _mapAniListCharacters(_aniListDetail!.characters)
          : [];
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
    List<Map<String, dynamic>> reviews;
    if (_isAnimeSourced) {
      reviews = await _fetchJikanReviews(widget.item.tmdbId);
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
  }

  /// Fetches MAL user reviews via Jikan's /anime/{id}/reviews endpoint
  /// and projects them into the TMDB-shaped review map.
  Future<List<Map<String, dynamic>>> _fetchJikanReviews(int malId) async {
    final uri = Uri.parse('https://api.jikan.moe/v4/anime/$malId/reviews');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];
      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? const [];
      return data.take(8).map<Map<String, dynamic>>((r) {
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
    } catch (e) {
      print('Jikan reviews error: $e');
      return [];
    }
  }

  Future<void> _fetchSimilar() async {
    List<MediaItem> similar;
    if (_isAnimeSourced) {
      similar = _mapAniListRelated();
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
    return MediaItem(
      id: '',
      tmdbId: r.id, // AniList id stored in tmdbId slot for routing
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
    if (_currentStatus == newStatus) {
      setState(() => _currentStatus = '');
      await _tmdbService.removeFromWatchList(widget.item.tmdbId, userName);
      if (mounted) _showSnack('Removed from watchlist');
    } else {
      setState(() => _currentStatus = newStatus);
      // Auto-detect anime so the dashboard's Anime rail picks it up
      // automatically. We do this against TMDB /details because that's the
      // only endpoint that reliably returns `original_language` + nested
      // `genres` for TV. If the network call fails we just fall back to
      // whatever the item already has.
      bool? detectedAnime;
      if (!widget.item.isAnime) {
        detectedAnime = await _tmdbService.isAnimeByTmdbId(
          widget.item.tmdbId,
          widget.item.mediaType,
        );
      }
      await _tmdbService.saveToWatchList(
        widget.item,
        newStatus,
        userName,
        isAnimeOverride: detectedAnime,
      );
      if (mounted) _showSnack('Watchlist updated');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: _cWhite)),
        backgroundColor: _cDeepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _playMovie() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          tmdbId: widget.item.tmdbId,
          mediaType: 'movie',
          title: widget.item.title,
        ),
      ),
    );
  }

  void _playEpisode(int season, int episode, String epTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          tmdbId: widget.item.tmdbId,
          mediaType: 'tv',
          season: season,
          episode: episode,
          title: '${widget.item.title} Ã‚Â· S${season}E$episode: $epTitle',
        ),
      ),
    );
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

  String _getInitial(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : '?';

  Color _avatarColor(String name) {
    final palette = [_cDeepRose, _cAmber, AppTheme.softLavender, _cGold, _cRose];
    if (name.isEmpty) return _cDeepRose;
    return palette[name.codeUnitAt(0) % palette.length];
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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
          color: _cVelvet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
            // Ã¢â€â‚¬Ã¢â€â‚¬ HERO BACKDROP Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            SliverToBoxAdapter(
              child: _buildHeroBackdrop(backdropUrl, year, rating,
                  ratingFraction, runtime),
            ),

            // Ã¢â€â‚¬Ã¢â€â‚¬ META + ACTIONS Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildMetaSection(year, rating, ratingFraction, runtime),
              ),
            ),

            // Ã¢â€â‚¬Ã¢â€â‚¬ PLAY BUTTON (Movie) or EPISODES Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            if (widget.item.mediaType == 'movie')
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _buildPlayButton(),
                ),
              )
            else ...[
              if (_seasons.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _buildEpisodeHeader(),
                  ),
                ),
              if (_isLoadingEpisodes)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: _cDeepRose, strokeWidth: 2),
                    ),
                  ),
                )
              else if (_episodes.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptySection('No episodes for this season'),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildEpisodeTile(_episodes[index], index),
                    childCount: _episodes.length,
                  ),
                ),
            ],

            // Ã¢â€â‚¬Ã¢â€â‚¬ CAST Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            SliverToBoxAdapter(child: _buildDrawerSection('Cast')),
            SliverToBoxAdapter(child: _buildCastSection()),

            // Ã¢â€â‚¬Ã¢â€â‚¬ REVIEWS Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            SliverToBoxAdapter(child: _buildDrawerSection('Reviews')),
            SliverToBoxAdapter(child: _buildReviewsSection()),

            // Ã¢â€â‚¬Ã¢â€â‚¬ MORE LIKE THIS Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            SliverToBoxAdapter(child: _buildDrawerSection('More Like This')),
            SliverToBoxAdapter(child: _buildSimilarSection()),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // HERO BACKDROP
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildHeroBackdrop(String backdropUrl, String year, String rating,
      double ratingFraction, dynamic runtime) {
    return Stack(
      children: [
        // Backdrop image or Trailer Player
        SizedBox(
          height: 280,
          width: double.infinity,
          child: _isPlayingTrailer && _trailerKey != null
              ? Stack(
                  children: [
                    TrailerPlayer(
                      videoKey: _trailerKey!,
                      // Mute on mobile so browser autoplay policies don't
                      // silently block playback. Desktop still plays with
                      // sound because the click on Watch Trailer counts as a
                      // user gesture.
                      muted: _isMobile,
                      autoplay: true,
                      loop: true,
                    ),
                    Positioned(
                      top: 14,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => setState(() => _isPlayingTrailer = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Close Trailer',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    backdropUrl.isNotEmpty
                        ? Image.network(
                            backdropUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return _buildBackdropPlaceholder(
                                isLoading: true,
                              );
                            },
                            errorBuilder: (_, _, _) =>
                                _buildBackdropPlaceholder(isLoading: false),
                          )
                        : _buildBackdropPlaceholder(
                            isLoading: _details == null,
                          ),
                    if (_trailerKey != null && !_isLoadingTrailer)
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(() => _isPlayingTrailer = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _cDeepRose.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _cDeepRose.withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Watch Trailer',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),

        // Cinematic gradients (wrapped in IgnorePointer so the Watch Trailer
        // and Close Trailer buttons underneath stay tappable on mobile).
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    _cVelvet.withValues(alpha: 0.6),
                    _cVelvet,
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    _cVelvet.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Top: drag handle + close button
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Close button
        Positioned(
          top: 14,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),

        // Bottom overlay: title
        Positioned(
          bottom: 16,
          left: 20,
          right: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  shadows: [
                    Shadow(
                        color: Colors.black.withValues(alpha: 0.7), blurRadius: 16),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (year.isNotEmpty) ...[
                    Text(
                      year,
                      style: GoogleFonts.outfit(
                        color: _cGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _dot(),
                  ],
                  // Rating stars
                  ...List.generate(5, (i) {
                    final filled = i < (ratingFraction * 5).round();
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: _cAmber,
                      size: 14,
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: GoogleFonts.outfit(
                      color: _cAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (runtime != null) ...[
                    _dot(),
                    Text(
                      '${runtime}m',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: _cMuted,
            shape: BoxShape.circle,
          ),
        ),
      );

  // Replaces the flat `Container(color: _cCard)` that used to fill the hero
  // when a backdrop image was missing or failed to load. The old behaviour
  // was indistinguishable from a render glitch, especially on the Trending
  // PH tab where many discover results have no `backdrop_path`. This shows
  // a soft gradient + either a spinner (still loading) or a film icon
  // (genuinely missing) so the user knows what's going on.
  Widget _buildBackdropPlaceholder({required bool isLoading}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cCard, _cVelvet],
        ),
      ),
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: _cDeepRose,
                strokeWidth: 2,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.movie_creation_outlined,
                  color: _cMuted.withValues(alpha: 0.6),
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  'No preview available',
                  style: GoogleFonts.outfit(
                    color: _cMuted,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // META SECTION
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

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

          // Anime-specific meta row: studio + format + airing status.
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
                  color: _cDeepRose,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'WATCHLIST STATUS',
                style: GoogleFonts.outfit(
                  color: _cMuted,
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
            if (isCinemaOnly) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildStatusChip('Want to Watch', 'to-watch',
                        icon: Icons.bookmark_rounded),
                    const SizedBox(width: 8),
                    _buildStatusChip('Watched', 'watched-self',
                        icon: Icons.check_circle_rounded,
                        activeColor: const Color(0xFF2E7D32)),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildStatusChip('Want to Watch', 'to-watch',
                      icon: Icons.bookmark_rounded),
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
                color: _cWhite.withValues(alpha: 0.75),
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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // PLAY BUTTON
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _playMovie,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cDeepRose, Color(0xFF8E1444)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _cDeepRose.withValues(alpha: 0.45),
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

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // EPISODE HEADER
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildEpisodeHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Episodes',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _cWhite,
              ),
            ),
            Text(
              'SELECT AN EPISODE TO PLAY',
              style: GoogleFonts.outfit(
                fontSize: 9,
                color: _cMuted,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        // Season dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _cCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cRose.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedSeasonNumber,
              dropdownColor: _cCard,
              isDense: true,
              icon: const Icon(Icons.expand_more_rounded,
                  color: _cDeepRose, size: 18),
              style: GoogleFonts.outfit(
                  color: _cWhite, fontWeight: FontWeight.w600, fontSize: 13),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() => _selectedSeasonNumber = value);
                  _fetchSeasonEpisodes(value);
                }
              },
              items: _seasons
                  .where((s) => s['season_number'] is int)
                  .map<DropdownMenuItem<int>>((s) {
                return DropdownMenuItem<int>(
                  value: s['season_number'] as int,
                  child: Text(s['name'] ?? 'Season ${s['season_number']}'),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // EPISODE TILE
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildEpisodeTile(dynamic ep, int index) {
    final epNum = ep['episode_number'] ?? (index + 1);
    final epName = ep['name'] ?? 'Episode $epNum';
    final epOverview = ep['overview'] ?? '';
    final epStillPath = ep['still_path'];
    final epStillUrl = epStillPath != null
        ? 'https://image.tmdb.org/t/p/w300$epStillPath'
        : null;

    return _EpisodeTile(
      epNum: epNum,
      epName: epName,
      epOverview: epOverview,
      stillUrl: epStillUrl,
      onTap: () =>
          _playEpisode(_selectedSeasonNumber ?? 1, epNum, epName),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // CAST SECTION
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildCastSection() {
    if (_isLoadingCast) return _buildLoader();
    if (_cast.isEmpty) return _buildEmptySection('No cast info available');

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _cast.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final m = _cast[i];
          final hasPhoto =
              (m['profilePath'] ?? '').toString().isNotEmpty;
          return SizedBox(
            width: 80,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cCard,
                    border: Border.all(
                        color: _cRose.withValues(alpha: 0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasPhoto
                        ? Image.network(m['profilePath'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _castInitial(m['name'] ?? ''))
                        : _castInitial(m['name'] ?? ''),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  m['name'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: _cWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((m['character'] ?? '').toString().isNotEmpty)
                  Text(
                    m['character'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: _cMuted,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _castInitial(String name) {
    return Container(
      color: _avatarColor(name).withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(
        _getInitial(name),
        style: GoogleFonts.cormorantGaramond(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: _avatarColor(name),
        ),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // REVIEWS SECTION
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildReviewsSection() {
    if (_isLoadingReviews) return _buildLoader();
    if (_reviews.isEmpty) {
      return _buildEmptySection('No reviews yet');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _reviews.map((review) {
          final author = review['author'] ?? 'Anonymous';
          final content = (review['content'] ?? '').toString();
          final rating = review['rating'];
          final preview =
              content.length > 300 ? '${content.substring(0, 300)}Ã¢â‚¬Â¦' : content;
          final hasAvatar =
              (review['avatar'] ?? '').toString().isNotEmpty;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cRose.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _avatarColor(author).withValues(alpha: 0.2),
                        border: Border.all(
                            color: _avatarColor(author).withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: ClipOval(
                        child: hasAvatar
                            ? Image.network(
                                review['avatar'],
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _castInitial(author),
                              )
                            : _castInitial(author),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: _cWhite,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (rating != null)
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: _cAmber, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toString(),
                                  style: GoogleFonts.outfit(
                                    color: _cAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  preview,
                  style: GoogleFonts.outfit(
                    color: _cWhite.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // SIMILAR SECTION
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildSimilarSection() {
    if (_isLoadingSimilar) return _buildLoader();
    if (_similar.isEmpty) {
      return _buildEmptySection('No similar titles found');
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _similar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _similar[index];
          return GestureDetector(
            onTap: () => _showSimilarItem(item),
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.posterPath.isNotEmpty
                            ? Image.network(item.posterPath,
                                fit: BoxFit.cover)
                            : Container(
                                color: _cCard,
                                child: const Center(
                                  child: Icon(
                                      Icons.movie_creation_outlined,
                                      color: _cMuted,
                                      size: 28),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: _cWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.year.isNotEmpty
                        ? item.year
                        : (item.mediaType == 'movie' ? 'Movie' : 'Series'),
                    style: GoogleFonts.outfit(color: _cMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // HELPERS
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

  Widget _buildDrawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_cDeepRose, Color(0x44C2185B)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _cWhite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String name) {
    // Assign a color per genre for distinction
    final colors = [
      _cDeepRose,
      _cAmber,
      AppTheme.softLavender,
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
      const Color(0xFF9C27B0),
    ];
    final color = name.isEmpty
        ? _cDeepRose
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
        color: _cCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cGold.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _cGold, size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: _cGold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    String status, {
    IconData icon = Icons.check_circle_rounded,
    Color activeColor = _cDeepRose,
  }) {
    final isSelected = _currentStatus == status;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : _cCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.7)
                : _cRose.withValues(alpha: 0.15),
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
                  isSelected ? activeColor : _cMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? activeColor : _cMuted,
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

  Widget _buildLoader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: _cDeepRose, strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptySection(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        msg,
        style: GoogleFonts.outfit(color: _cMuted, fontSize: 13),
      ),
    );
  }
}

// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
// EPISODE TILE WIDGET
// Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â

class _EpisodeTile extends StatefulWidget {
  final int epNum;
  final String epName;
  final String epOverview;
  final String? stillUrl;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.epNum,
    required this.epName,
    required this.epOverview,
    this.stillUrl,
    required this.onTap,
  });

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _pressed ? _cCard.withValues(alpha: 0.8) : _cCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cRose.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ep number accent
            Column(
              children: [
                const SizedBox(height: 2),
                Text(
                  widget.epNum.toString().padLeft(2, '0'),
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _cDeepRose.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Still thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 130,
                height: 76,
                color: _cBlack,
                child: widget.stillUrl != null
                    ? Image.network(widget.stillUrl!, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.tv_rounded, color: _cMuted, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + overview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.epName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: _cWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  if (widget.epOverview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.epOverview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: _cMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Play icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _cDeepRose.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _cDeepRose.withValues(alpha: 0.4), width: 1),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: _cDeepRose, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}


