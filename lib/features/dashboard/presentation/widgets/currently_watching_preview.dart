import 'dart:async';
import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/data/services/tmdb/tmdb_watchlist_service.dart';
import '../../../cinema/presentation/widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/logger.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';
import '../../../../shared/widgets/everglow/everglow_marquee.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';

class CurrentlyWatchingPreview extends StatelessWidget {
  const CurrentlyWatchingPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final userName =
        context.select<AuthService, String>((a) => a.currentUser ?? '');
    final isCouple = context.select<AuthService, bool>((a) => a.isCoupleUser);
    final partner = context.select<AuthService, String?>((a) => a.partnerUsername);
    final partnerLabel = partnerEyebrowLabelFor(userName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CurrentlyWatchingHeader(userName: userName),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _CurrentlyWatchingShelf(
              userName: userName,
              label: 'ME',
              isSelf: true,
            ),
            _CurrentlyWatchingShelf(
              userName: partner,
              label: partnerLabel,
              isSelf: false,
            ),
          ] else
            _CurrentlyWatchingShelf(
              userName: userName,
              label: null,
              isSelf: true,
            ),
        ],
      ),
    );
  }
}

class _CurrentlyWatchingHeader extends StatefulWidget {
  final String userName;
  const _CurrentlyWatchingHeader({required this.userName});

  @override
  State<_CurrentlyWatchingHeader> createState() =>
      _CurrentlyWatchingHeaderState();
}

class _CurrentlyWatchingHeaderState extends State<_CurrentlyWatchingHeader> {
  final TMDBService _service = TMDBService();
  List<MediaItem> _items = [];
  StreamSubscription<List<MediaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _CurrentlyWatchingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _streamSub?.cancel();
      _items = [];
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.userName.isEmpty) {
      if (mounted) setState(() => _items = []);
      return;
    }
    _streamSub?.cancel();
    _streamSub = _service
        .getCurrentlyWatchingStream(
          widget.userName,
          limit: TMDBWatchlistService.previewLimit,
        )
        .listen(
      (items) {
        if (!mounted) return;
        setState(() => _items = items.watchingCinema);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _items = []);
      },
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShelfHeader(
      accent: ShelfAccent.cinema,
      title: 'Currently Watching',
      itemCount: _items.length,
      onViewAll: () => context.push('/cinema'),
    );
  }
}

class _CurrentlyWatchingShelf extends StatefulWidget {
  final String userName;
  final String? label;
  final bool isSelf;
  const _CurrentlyWatchingShelf({
    required this.userName,
    required this.label,
    required this.isSelf,
  });

  @override
  State<_CurrentlyWatchingShelf> createState() =>
      _CurrentlyWatchingShelfState();
}

class _CurrentlyWatchingShelfState extends State<_CurrentlyWatchingShelf> {
  final TMDBService _service = TMDBService();
  List<MediaItem> _items = [];
  bool _hasLoaded = false;
  bool _loadError = false;
  StreamSubscription<List<MediaItem>>? _streamSub;
  final Set<String> _healAttempted = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _CurrentlyWatchingShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _streamSub?.cancel();
      setState(() {
        _items = [];
        _hasLoaded = false;
        _loadError = false;
      });
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.userName.isEmpty) {
      if (mounted) setState(() => _hasLoaded = true);
      return;
    }
    _streamSub?.cancel();
    _streamSub = _service
        .getCurrentlyWatchingStream(
          widget.userName,
          limit: TMDBWatchlistService.previewLimit,
        )
        .listen(
      (items) {
        if (!mounted) return;
        final filtered = items.watchingCinema;
        setState(() {
          _items = filtered;
          _hasLoaded = true;
          _loadError = false;
        });
        if (filtered.isNotEmpty) _backfillPosters(filtered);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _hasLoaded = true;
          _loadError = true;
        });
      },
    );
  }

  Future<void> _backfillPosters(List<MediaItem> items) async {
    try {
      var updated = await _service.backfillMissingPosters(items);
      updated = await _service.refreshAnimePosters(updated);
      if (mounted) setState(() => _items = updated);
    } catch (e) {
      // Silently fail — placeholder will show
    }
  }

  void _handleImageError(MediaItem item) {
    if (item.id.isEmpty || _healAttempted.contains(item.id)) return;
    _healAttempted.add(item.id);
    unawaited(_healOne(item));
  }

  Future<void> _healOne(MediaItem item) async {
    try {
      final healed = await _service.healPoster(item);
      if (healed == null || !mounted) return;
      setState(() {
        final idx = _items.indexWhere((u) => u.id == item.id);
        if (idx != -1) _items[idx] = healed;
      });
    } catch (e) {
      Logger.e('Dashboard: shelf cover heal failed', error: e);
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  void _openDetails(MediaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpisodeDrawer(item: item),
    );
  }

  static final _cssArtifactRegex = RegExp(r'\bcss-[a-zA-Z0-9_-]+\b');
  static final _multiSpaceRegex = RegExp(r'\s{2,}');

  static String _sanitizeTitle(String title) {
    var cleaned = title.replaceAll(_cssArtifactRegex, ' ').trim();
    cleaned = cleaned.replaceAll(_multiSpaceRegex, ' ');
    return cleaned.isNotEmpty ? cleaned : title;
  }

  String? _subtitleFor(MediaItem item) {
    final parts = <String>[];
    if (item.isMovie) {
      if (item.year.isNotEmpty) parts.add(item.year);
      parts.add('Movie');
    } else {
      if (item.hasEpisodeProgress && item.currentEpisode != null) {
        parts.add('S${item.currentSeason ?? 1}E${item.currentEpisode}');
      }
      if (item.year.isNotEmpty) parts.add(item.year);
    }
    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  List<Widget> _buildCards() {
    return _items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ShelfCard(
              accent: ShelfAccent.cinema,
              imageUrl: item.posterPath,
              title: _sanitizeTitle(item.title),
              subtitle: _subtitleFor(item),
              topBadge:
                  item.hasEpisodeProgress && item.currentEpisode != null
                  ? 'S${item.currentSeason ?? 1}E${item.currentEpisode}'
                  : null,
              onTap: () => _openDetails(item),
              onImageError: () => _handleImageError(item),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cards = _buildCards();
    if (widget.label == null) {
      if (!_hasLoaded) {
        return const EverglowSkeletonRow(
          count: 5,
          itemWidth: 128,
          itemHeight: 194,
        );
      }
      if (cards.isEmpty) {
        return ShelfEmpty(
          accent: ShelfAccent.cinema,
          message: _loadError
              ? 'Couldn\'t load your movies — check your connection and reopen.'
              : 'Nothing playing right now. Start a movie or show!',
        );
      }
      return EverglowMarquee(
        height: 194,
        children: cards.take(12).toList(),
      );
    }
    if (!_hasLoaded) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoupleShimmerLabel(label: widget.label!, accent: ShelfAccent.cinema),
            const SizedBox(height: 8),
            const EverglowSkeletonRow(
              count: 5,
              itemWidth: 128,
              itemHeight: 194,
            ),
          ],
        ),
      );
    }
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.cinema,
      emptyMessage: _loadError
          ? 'Couldn\'t load — check connection and reopen.'
          : widget.isSelf
          ? 'You aren\'t watching anything right now.'
          : 'Nothing playing on their end.',
      children: cards,
    );
  }
}

class _CoupleShimmerLabel extends StatelessWidget {
  final String label;
  final ShelfAccent accent;
  const _CoupleShimmerLabel({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 1.2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.color.withValues(alpha: 0.0),
                accent.color.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accent.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.color.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: accent.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ).copyWith(color: accent.color),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.color.withValues(alpha: 0.22), const Color(0x00000000)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
