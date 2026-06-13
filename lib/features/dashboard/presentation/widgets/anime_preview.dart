import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/screens/anime_screen.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';

/// "Anime" preview card on the dashboard.
///
/// Mirrors [CinemaPreview] / [MangaPreview] — a constant-speed marquee
/// of the watched anime catalog. For the couple (khentsgdz / clairjassen)
/// it streams the combined anime list from both partners so Khent and
/// Clair always see the same shared reel. For other users (Breyan /
/// Octagram) it falls back to the current user's own list.
///
/// Anime filtering happens in [TMDBService.getAnimeWatchListStream] /
/// [TMDBService.getCoupleAnimeStream] — both rely on the `isAnime` flag
/// that's auto-detected from TMDB (original_language == 'ja' + Animation
/// genre) the first time a TV show is saved to the watchlist.
class AnimePreview extends StatelessWidget {
  const AnimePreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tmdbService = TMDBService();
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCouple = auth.isCoupleUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Anime',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.roseQuartz,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.deepRose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.deepRose.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'NEW',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.deepRose,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AnimeScreen()),
                ),
                child: Text(
                  'View All',
                  style: GoogleFonts.outfit(
                    color: AppTheme.blushGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: _AnimeCarousel(
              stream: isCouple
                  ? tmdbService.getCoupleAnimeStream()
                  : tmdbService.getAnimeWatchListStream(userName),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same marquee implementation as CinemaPreview / MangaPreview — items
/// are streamed in, deduplicated visually, then laid out in a row that's
/// duplicated once. A `Ticker` advances a `ScrollController` at a fixed
/// pixel-per-second rate, looping back to 0 when it reaches one full
/// set's width so the user never sees the seam.
class _AnimeCarousel extends StatefulWidget {
  final Stream<List<MediaItem>> stream;
  const _AnimeCarousel({required this.stream});

  @override
  State<_AnimeCarousel> createState() => _AnimeCarouselState();
}

class _AnimeCarouselState extends State<_AnimeCarousel>
    with SingleTickerProviderStateMixin {
  List<MediaItem> _items = [];
  bool _hasLoaded = false;
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  StreamSubscription<List<MediaItem>>? _streamSub;
  Duration _lastTick = Duration.zero;

  static const double _itemWidth = 112.0;
  static const double _speed = 30.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick)..start();
    _streamSub = widget.stream.listen((items) {
      final watched = items.where((i) => i.isWatched).toList();
      watched.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      if (!mounted) return;
      setState(() {
        _items = watched;
        _hasLoaded = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    });
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients || _items.isEmpty) {
      _lastTick = elapsed;
      return;
    }
    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6;
    _lastTick = elapsed;

    final viewportWidth = _scrollController.position.viewportDimension;
    final singleSetWidth = _items.length * _itemWidth;
    final effectiveSingleSet = singleSetWidth < viewportWidth
        ? (viewportWidth * 2)
        : singleSetWidth;

    var newOffset = _scrollController.offset + _speed * dt;
    if (newOffset >= effectiveSingleSet) {
      newOffset -= effectiveSingleSet;
    }
    _scrollController.jumpTo(newOffset);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLoaded) {
      return _buildShimmer();
    }
    if (_items.isEmpty) {
      return _AnimePreviewEmpty();
    }
    return _MarqueeRow(
      items: _items,
      controller: _scrollController,
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => Container(
        width: 100,
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _MarqueeRow extends StatelessWidget {
  final List<MediaItem> items;
  final ScrollController controller;
  const _MarqueeRow({required this.items, required this.controller});

  @override
  Widget build(BuildContext context) {
    final posters = items.map((item) => _AnimePoster(item: item)).toList();
    return ClipRect(
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            ...posters,
            ...posters,
          ],
        ),
      ),
    );
  }
}

class _AnimePoster extends StatefulWidget {
  final MediaItem item;
  const _AnimePoster({required this.item});

  @override
  State<_AnimePoster> createState() => _AnimePosterState();
}

class _AnimePosterState extends State<_AnimePoster> {
  bool _pressed = false;

  void _openDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpisodeDrawer(item: widget.item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _openDetails();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: Container(
          width: 100,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepRose.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.item.posterPath.isNotEmpty
                ? Image.network(widget.item.posterPath, fit: BoxFit.cover)
                : Container(
                    color: AppTheme.velvet,
                    child: Icon(
                      Icons.animation_rounded,
                      color: AppTheme.roseQuartz.withValues(alpha: 0.4),
                      size: 28,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AnimePreviewEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.moonlight.withValues(alpha: 0.15), width: 1),
      ),
      child: Center(
        child: Text(
          'No anime watched yet. Time for a binge!',
          style: GoogleFonts.outfit(
            color: AppTheme.roseQuartz.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
