import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/presentation/widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';

/// "Currently Watching" shelf on the dashboard.
///
/// For couple users (khentsgdz / clairjassen) the shelf splits into
/// two labeled sub-rows — "Me" and the partner — so each partner can
/// see what the other is currently watching without leaving the
/// dashboard. Non-couple users keep the original single-row layout
/// (one stream of their own items only).
class CurrentlyWatchingPreview extends StatelessWidget {
  const CurrentlyWatchingPreview({super.key});

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
    _streamSub =
        _service.getCurrentlyWatchingStream(widget.userName).listen((items) {
      // Keep anime out of the generic shelf — the Anime rail owns its own
      // watching row now so the two never duplicate the same title.
      final filtered = items.where((i) => !i.isAnime).toList();
      if (!mounted) return;
      setState(() => _items = filtered);
    });
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
      onViewAll: () {},
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
  StreamSubscription<List<MediaItem>>? _streamSub;

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
      });
      _subscribe();
    }
  }

  void _subscribe() {
    _streamSub =
        _service.getCurrentlyWatchingStream(widget.userName).listen((items) {
      final filtered = items.where((i) => !i.isAnime).toList();
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _hasLoaded = true;
      });
      _backfillPosters(filtered);
    });
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

  /// Sanitize title to remove CSS class artifacts like "css-1dbjc4n".
  static final _cssArtifactRegex = RegExp(r'\bcss-[a-zA-Z0-9_-]+\b');

  static String _sanitizeTitle(String title) {
    var cleaned = title.replaceAll(_cssArtifactRegex, ' ').trim();
    // Collapse multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    return cleaned.isNotEmpty ? cleaned : title;
  }

  String? _subtitleFor(MediaItem item) {
    final parts = <String>[];
    if (item.isMovie) {
      // Movies have no episode progress - identify them as films.
      if (item.year.isNotEmpty) parts.add(item.year);
      parts.add('Movie');
    } else {
      if (item.currentEpisode != null) {
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
              accent: item.isAnime ? ShelfAccent.anime : ShelfAccent.cinema,
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
        return const SizedBox(
          height: 194,
          child: ShelfMarquee(hasLoaded: false, children: []),
        );
      }
      if (cards.isEmpty) {
        return ShelfEmpty(
          accent: ShelfAccent.cinema,
          message: 'Nothing playing right now. Start a movie or show!',
        );
      }
      return SizedBox(height: 194, child: ShelfMarquee(children: cards));
    }
    // Couple path: partner sub-row beneath the existing single-row.
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.cinema,
      emptyMessage: widget.isSelf
          ? 'You aren\'t watching anything right now.'
          : 'Nothing playing on their end.',
      children: _hasLoaded ? cards : const [],
    );
  }
}
