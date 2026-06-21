import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/services/auth_service.dart';
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
  const CurrentlyWatchingPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tmdbService = TMDBService();
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
          _CurrentlyWatchingHeader(stream: tmdbService.getCurrentlyWatchingStream(userName)),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _CurrentlyWatchingShelf(
              stream: tmdbService.getCurrentlyWatchingStream(userName),
              label: 'ME',
              isSelf: true,
            ),
            _CurrentlyWatchingShelf(
              stream: tmdbService.getCurrentlyWatchingStream(partner),
              label: partnerLabel,
              isSelf: false,
            ),
          ] else
            _CurrentlyWatchingShelf(
              stream: tmdbService.getCurrentlyWatchingStream(userName),
              label: null,
              isSelf: true,
            ),
        ],
      ),
    );
  }
}

class _CurrentlyWatchingHeader extends StatefulWidget {
  final Stream<List<MediaItem>> stream;
  const _CurrentlyWatchingHeader({required this.stream});

  @override
  State<_CurrentlyWatchingHeader> createState() =>
      _CurrentlyWatchingHeaderState();
}

class _CurrentlyWatchingHeaderState extends State<_CurrentlyWatchingHeader> {
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
    if (oldWidget.stream != widget.stream) {
      _streamSub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _streamSub = widget.stream.listen((items) {
      if (!mounted) return;
      setState(() => _items = items);
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
  final Stream<List<MediaItem>> stream;
  final String? label;
  final bool isSelf;
  const _CurrentlyWatchingShelf({
    required this.stream,
    required this.label,
    required this.isSelf,
  });

  @override
  State<_CurrentlyWatchingShelf> createState() => _CurrentlyWatchingShelfState();
}

class _CurrentlyWatchingShelfState extends State<_CurrentlyWatchingShelf> {
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
    if (oldWidget.stream != widget.stream) {
      _streamSub?.cancel();
      setState(() { _items = []; _hasLoaded = false; });
      _subscribe();
    }
  }

  void _subscribe() {
    _streamSub = widget.stream.listen((items) {
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasLoaded = true;
      });
      _backfillPosters(items);
    });
  }

  Future<void> _backfillPosters(List<MediaItem> items) async {
    final missing = items.where((i) => i.posterPath.isEmpty && i.tmdbId > 0).toList();
    if (missing.isEmpty) return;
    try {
      final tmdbService = TMDBService();
      final updated = await tmdbService.backfillMissingPosters(items);
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
    if (item.currentEpisode != null) {
      parts.add('S${item.currentSeason ?? 1}E${item.currentEpisode}');
    }
    if (item.year.isNotEmpty) parts.add(item.year);
    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  List<Widget> _buildCards() {
    return _items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ShelfCard(
              accent:
                  item.isAnime ? ShelfAccent.anime : ShelfAccent.cinema,
              imageUrl: item.posterPath,
              title: _sanitizeTitle(item.title),
              subtitle: _subtitleFor(item),
              topBadge: item.currentEpisode != null
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
      // Non-couple path: keep the original single-row layout.
      if (!_hasLoaded) {
        return const SizedBox(
          height: 160,
          child: ShelfMarquee(hasLoaded: false, children: []),
        );
      }
      if (cards.isEmpty) {
        return SizedBox(
          height: 90,
          child: ShelfEmpty(
            accent: ShelfAccent.cinema,
            message: 'Nothing playing right now. Start a movie or show!',
          ),
        );
      }
      return SizedBox(
        height: 168,
        child: ShelfMarquee(children: cards),
      );
    }
    // Couple path: partner sub-row beneath the existing single-row.
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.cinema,
      children: _hasLoaded ? cards : const [],
      emptyMessage: widget.isSelf
          ? 'You aren\'t watching anything right now.'
          : 'Nothing playing on their end.',
    );
  }
}
