import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/data/services/tmdb/tmdb_watchlist_service.dart';
import '../../../cinema/presentation/widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';
import '../../../../shared/widgets/everglow/everglow_marquee.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';

/// "Watched" shelf on the dashboard.
///
/// For couple users (khentsgdz / clairjassen) the shelf splits into
/// two labeled sub-rows — "Me" and the partner — so each partner can
/// see what the other has finished without leaving the dashboard.
/// Non-couple users keep the original single-row layout (one stream
/// of their own watched items only).
class CinemaPreview extends StatelessWidget {
  const CinemaPreview({super.key});

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
          _CinemaHeader(userName: userName),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _CinemaShelf(userName: userName, label: 'ME', isSelf: true),
            _CinemaShelf(userName: partner, label: partnerLabel, isSelf: false),
          ] else
            _CinemaShelf(userName: userName, label: null, isSelf: true),
        ],
      ),
    );
  }
}

class _CinemaHeader extends StatefulWidget {
  final String userName;
  const _CinemaHeader({required this.userName});

  @override
  State<_CinemaHeader> createState() => _CinemaHeaderState();
}

class _CinemaHeaderState extends State<_CinemaHeader> {
  final TMDBService _service = TMDBService();
  List<MediaItem> _items = [];
  StreamSubscription<List<MediaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _CinemaHeader oldWidget) {
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
    // Realtime (bounded by previewLimit via limit) so watched counts drop
    // immediately on undo instead of lingering until reload.
    _streamSub?.cancel();
    _streamSub = _service
        .getWatchListStream(
          widget.userName,
          limit: TMDBWatchlistService.previewLimit,
        )
        .listen(
      (items) {
        if (!mounted) return;
        // Cinema owns every watched movie (live-action or anime) plus
        // non-anime TV — see MediaItem.isCinemaItem. Anime series live in
        // the Anime rail.
        final watched = items.watchedCinema;
        watched.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        setState(() => _items = watched);
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
      title: 'Watched',
      itemCount: _items.length,
      onViewAll: () => context.push('/cinema'),
    );
  }
}

class _CinemaShelf extends StatefulWidget {
  final String userName;
  final String? label;
  final bool isSelf;
  const _CinemaShelf({
    required this.userName,
    required this.label,
    required this.isSelf,
  });

  @override
  State<_CinemaShelf> createState() => _CinemaShelfState();
}

class _CinemaShelfState extends State<_CinemaShelf> {
  final TMDBService _service = TMDBService();
  List<MediaItem> _items = [];
  bool _hasLoaded = false;
  bool _loadError = false;
  StreamSubscription<List<MediaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _CinemaShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _streamSub?.cancel();
      _items = [];
      _hasLoaded = false;
      _loadError = false;
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.userName.isEmpty) {
      if (mounted) {
        setState(() => _hasLoaded = true);
      }
      return;
    }
    // Realtime (bounded by previewLimit via limit) so undo/remove updates
    // the shelf immediately. Mirrors the Currently Watching shelf.
    _streamSub?.cancel();
    _streamSub = _service
        .getWatchListStream(
          widget.userName,
          limit: TMDBWatchlistService.previewLimit,
        )
        .listen(
      (items) {
        if (!mounted) return;
        // Cinema owns every watched movie (live-action or anime) plus
        // non-anime TV — see MediaItem.isCinemaItem. Anime series live in
        // the Anime rail.
        final watched = items.watchedCinema;
        watched.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        setState(() {
          _items = watched;
          _hasLoaded = true;
          _loadError = false;
        });
        if (watched.isNotEmpty) _backfillPosters(watched);
      },
      onError: (Object e) {
        if (!mounted) return;
        // Report the failure instead of a false-empty shelf: a denied
        // fetch means the data is unreachable, not absent.
        setState(() {
          _hasLoaded = true;
          _loadError = true;
        });
      },
    );
  }

  /// Resolves posters for entries saved without one (e.g. older docs from
  /// before `posterPath` was stored, or progress saves from the video
  /// player). Mirrors the Currently Watching shelf — without this, Watched
  /// cards fall back to the placeholder tile forever.
  Future<void> _backfillPosters(List<MediaItem> items) async {
    try {
      var updated = await _service.backfillMissingPosters(items);
      updated = await _service.refreshAnimePosters(updated);
      if (mounted) setState(() => _items = updated);
    } catch (_) {
      // Silently fail — placeholder will show
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

  String _subtitleFor(MediaItem item) {
    final parts = <String>[];
    if (item.year.isNotEmpty) parts.add(item.year);
    if (item.mediaType.isNotEmpty) {
      parts.add(item.mediaType == 'tv' ? 'Series' : 'Movie');
    }
    return parts.join(' • ');
  }

  List<Widget> _buildCards() {
    return _items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ShelfCard(
              accent: ShelfAccent.cinema,
              imageUrl: item.posterPath,
              title: item.title,
              subtitle: _subtitleFor(item),
              topBadge: item.mediaType.toUpperCase() == 'TV' ? 'TV' : null,
              onTap: () => _openDetails(item),
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
              : 'No movies watched yet. Start a movie night!',
        );
      }
      return EverglowMarquee(
        height: 194,
        children: cards.take(12).toList(),
      );
    }
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.cinema,
      emptyMessage: _loadError
          ? 'Couldn\'t load — check connection and reopen.'
          : widget.isSelf
          ? 'You haven\'t finished anything yet.'
          : 'Nothing finished on their end.',
      children: _hasLoaded ? cards : const [],
    );
  }
}
