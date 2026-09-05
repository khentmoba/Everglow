import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/presentation/widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_typography.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';
import '../../../../shared/widgets/everglow/everglow_marquee.dart';
import '../../../../shared/widgets/everglow/everglow_skeleton.dart';

/// "Anime" shelf on the dashboard.
///
/// For couple users (khentsgdz / clairjassen) the shelf splits into
/// two labeled sub-rows — "Me" and the partner — so each partner can
/// see what the other has finished watching in the anime column.
/// Non-couple users keep the original single-row layout (one stream
/// of their own watched anime only).
///
/// "Watching Now" anime no longer lives in the generic *Currently
/// Watching* shelf — it now lives here so the two rails never
/// duplicate the same title. Each partner's currently-watching anime
/// is rendered just above their finished row under a small
/// "WATCHING NOW" divider.
class AnimePreview extends StatelessWidget {
  const AnimePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCouple = auth.isCoupleUser;
    final partner = auth.partnerUsername;
    final partnerLabel = partnerEyebrowLabelFor(userName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnimeHeader(userName: userName),
          // ── WATCHING NOW ──────────────────────────────────────
          const _AnimeSectionLabel(
            label: 'WATCHING NOW',
            icon: Icons.play_circle_fill_rounded,
          ),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _AnimeWatchingShelf(userName: userName, label: 'ME', isSelf: true),
            _AnimeWatchingShelf(
              userName: partner,
              label: partnerLabel,
              isSelf: false,
            ),
          ] else
            _AnimeWatchingShelf(userName: userName, label: null, isSelf: true),
          // ── FINISHED ──────────────────────────────────────────
          const _AnimeSectionLabel(
            label: 'FINISHED',
            icon: Icons.check_circle_rounded,
          ),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _AnimeShelf(userName: userName, label: 'ME', isSelf: true),
            _AnimeShelf(userName: partner, label: partnerLabel, isSelf: false),
          ] else
            _AnimeShelf(userName: userName, label: null, isSelf: true),
        ],
      ),
    );
  }
}

class _AnimeSectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _AnimeSectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ShelfAccent.anime.color.withValues(alpha: 0.0),
                  ShelfAccent.anime.color.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 13, color: ShelfAccent.anime.color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ShelfAccent.anime.color.withValues(alpha: 0.85),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ShelfAccent.anime.color.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimeHeader extends StatefulWidget {
  final String userName;
  const _AnimeHeader({required this.userName});

  @override
  State<_AnimeHeader> createState() => _AnimeHeaderState();
}

class _AnimeHeaderState extends State<_AnimeHeader> {
  final TMDBService _service = TMDBService();
  List<MediaItem> _items = [];
  StreamSubscription<List<MediaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _AnimeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _streamSub?.cancel();
      _items = [];
      _subscribe();
    }
  }

  int _retryCount = 0;

  void _subscribe() {
    if (widget.userName.isEmpty) {
      if (mounted) setState(() => _items = []);
      return;
    }
    _streamSub?.cancel();
    _streamSub = _service.getAnimeWatchListStream(widget.userName).listen(
      (items) {
        _retryCount = 0;
        // Count both watching and finished so the header never reads
        // "0 titles" while a watching-now row is populated.
        final visible = items
            .where((i) => i.isWatched || i.isCurrentlyWatching)
            .toList();
        visible.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        if (!mounted) return;
        setState(() => _items = visible);
      },
      onError: (Object e) {
        // ignore: avoid_print
        print(
          '[AnimePreview/header:${widget.userName}] anime stream error: $e',
        );
        if (!mounted) return;
        if (_retryCount < 3) {
          _retryCount++;
          Future.delayed(Duration(seconds: 1 + _retryCount), () {
            if (mounted) _subscribe();
          });
        } else {
          setState(() => _items = []);
        }
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
      accent: ShelfAccent.anime,
      title: 'Anime',
      itemCount: _items.length,
      badge: _items.isNotEmpty ? null : 'NEW',
      onViewAll: () => context.push('/anime'),
    );
  }
}

class _AnimeWatchingShelf extends StatefulWidget {
  final String userName;
  final String? label;
  final bool isSelf;
  const _AnimeWatchingShelf({
    required this.userName,
    required this.label,
    required this.isSelf,
  });

  @override
  State<_AnimeWatchingShelf> createState() => _AnimeWatchingShelfState();
}

class _AnimeWatchingShelfState extends State<_AnimeWatchingShelf> {
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
  void didUpdateWidget(covariant _AnimeWatchingShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _streamSub?.cancel();
      _items = [];
      _hasLoaded = false;
      _loadError = false;
      _subscribe();
    }
  }

  int _retryCount = 0;

  void _subscribe() {
    if (widget.userName.isEmpty) {
      if (mounted) {
        setState(() => _hasLoaded = true);
      }
      return;
    }
    _streamSub?.cancel();
    _streamSub = _service.getCurrentlyWatchingAnimeStream(widget.userName).listen(
      (items) {
        _retryCount = 0;
        // Already anime+watching filtered by the service; sort by most recent progress.
        final sorted = List<MediaItem>.from(items)
          ..sort((a, b) {
            final aTime = a.progressUpdatedAt ?? a.addedAt;
            final bTime = b.progressUpdatedAt ?? b.addedAt;
            return bTime.compareTo(aTime);
          });
        if (!mounted) return;
        setState(() {
          _items = sorted;
          _hasLoaded = true;
          _loadError = false;
        });
        _backfillPosters(sorted);
      },
      onError: (Object e) {
        // ignore: avoid_print
        print(
          '[AnimePreview/watching:${widget.userName}] anime stream error: $e',
        );
        if (!mounted) return;
        if (_retryCount < 3) {
          _retryCount++;
          Future.delayed(Duration(seconds: 1 + _retryCount), () {
            if (mounted) _subscribe();
          });
        } else {
          setState(() {
            _hasLoaded = true;
            _loadError = true;
          });
        }
      },
    );
  }

  Future<void> _backfillPosters(List<MediaItem> items) async {
    try {
      var updated = await _service.backfillMissingPosters(items);
      updated = await _service.refreshAnimePosters(updated);
      if (mounted) setState(() => _items = updated);
    } catch (_) {}
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

  static String _sanitizeTitle(String title) {
    var cleaned = title.replaceAll(_cssArtifactRegex, ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    return cleaned.isNotEmpty ? cleaned : title;
  }

  String? _subtitleFor(MediaItem item) {
    final parts = <String>[];
    if (item.isMovie) {
      if (item.year.isNotEmpty) parts.add(item.year);
      parts.add('Movie');
    } else {
      if (item.currentEpisode != null) {
        parts.add('S${item.currentSeason ?? 1}E${item.currentEpisode}');
      } else if (item.format.isNotEmpty) {
        parts.add(item.format);
      } else if (item.studio.isNotEmpty) {
        parts.add(item.studio);
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
              accent: ShelfAccent.anime,
              imageUrl: item.posterPath,
              title: _sanitizeTitle(item.title),
              subtitle: _subtitleFor(item),
              topBadge: !item.isMovie && item.currentEpisode != null
                  ? 'S${item.currentSeason ?? 1}E${item.currentEpisode}'
                  : null,
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
          accent: ShelfAccent.anime,
          message: _loadError
              ? 'Couldn\'t load your anime — check your connection and reopen.'
              : 'No anime in progress. Start one to see it here!',
        );
      }
      return EverglowMarquee(
        height: 194,
        children: cards.take(12).toList(),
      );
    }
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.anime,
      emptyMessage: _loadError
          ? 'Couldn\'t load — check connection and reopen.'
          : widget.isSelf
          ? 'You aren\'t watching any anime right now.'
          : 'Nothing playing on their end.',
      children: _hasLoaded ? cards : const [],
    );
  }
}

class _AnimeShelf extends StatefulWidget {
  final String userName;
  final String? label;
  final bool isSelf;
  const _AnimeShelf({
    required this.userName,
    required this.label,
    required this.isSelf,
  });

  @override
  State<_AnimeShelf> createState() => _AnimeShelfState();
}

class _AnimeShelfState extends State<_AnimeShelf> {
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
  void didUpdateWidget(covariant _AnimeShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _streamSub?.cancel();
      _items = [];
      _hasLoaded = false;
      _loadError = false;
      _subscribe();
    }
  }

  int _retryCount = 0;

  void _subscribe() {
    if (widget.userName.isEmpty) {
      if (mounted) {
        setState(() => _hasLoaded = true);
      }
      return;
    }
    _streamSub?.cancel();
    _streamSub = _service.getAnimeWatchListStream(widget.userName).listen(
      (items) {
        _retryCount = 0;
        final watched = items.watched;
        watched.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        if (!mounted) return;
        setState(() {
          _items = watched;
          _hasLoaded = true;
          _loadError = false;
        });
      },
      onError: (Object e) {
        // ignore: avoid_print
        print(
          '[AnimePreview/finished:${widget.userName}] anime stream error: $e',
        );
        if (!mounted) return;
        if (_retryCount < 3) {
          _retryCount++;
          Future.delayed(Duration(seconds: 1 + _retryCount), () {
            if (mounted) _subscribe();
          });
        } else {
          setState(() {
            _hasLoaded = true;
            _loadError = true;
          });
        }
      },
    );
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
    if (item.studio.isNotEmpty) {
      parts.add(item.studio);
    } else if (item.format.isNotEmpty) {
      parts.add(item.format);
    } else if (item.year.isNotEmpty) {
      parts.add(item.year);
    }
    return parts.join(' • ');
  }

  List<Widget> _buildCards() {
    return _items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ShelfCard(
              accent: ShelfAccent.anime,
              imageUrl: item.posterPath,
              title: item.title,
              subtitle: _subtitleFor(item),
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
          accent: ShelfAccent.anime,
          message: _loadError
              ? 'Couldn\'t load your anime — check your connection and reopen.'
              : 'No anime watched yet. Time for a binge!',
        );
      }
      return EverglowMarquee(
        height: 194,
        children: cards.take(12).toList(),
      );
    }
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.anime,
      emptyMessage: _loadError
          ? 'Couldn\'t load — check connection and reopen.'
          : widget.isSelf
          ? 'You haven\'t finished any anime yet.'
          : 'Nothing finished on their end.',
      children: _hasLoaded ? cards : const [],
    );
  }
}
