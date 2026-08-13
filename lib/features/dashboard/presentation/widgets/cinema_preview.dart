import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/presentation/widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '../../../ai/presentation/widgets/ai_recommendations.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';

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
          _CinemaHeader(userName: userName),
          const AIRecommendations(title: "Mochi's Picks"),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _CinemaShelf(
              userName: userName,
              label: 'ME',
              isSelf: true,
            ),
            _CinemaShelf(
              userName: partner,
              label: partnerLabel,
              isSelf: false,
            ),
          ] else
            _CinemaShelf(
              userName: userName,
              label: null,
              isSelf: true,
            ),
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
    _streamSub = _service.getWatchListStream(widget.userName).listen((items) {
      final watched = items.where((i) => i.isWatched).toList();
      watched.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      if (!mounted) return;
      setState(() => _items = watched);
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
      _subscribe();
    }
  }

  void _subscribe() {
    _streamSub = _service.getWatchListStream(widget.userName).listen((items) {
      final watched = items.where((i) => i.isWatched).toList();
      watched.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      if (!mounted) return;
      setState(() {
        _items = watched;
        _hasLoaded = true;
      });
    });
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
        return const SizedBox(
          height: 160,
          child: ShelfMarquee(hasLoaded: false, children: []),
        );
      }
      if (cards.isEmpty) {
        return SizedBox(
          height: 110,
          child: ShelfEmpty(
            accent: ShelfAccent.cinema,
            message: 'No movies watched yet. Start a movie night!',
          ),
        );
      }
      return SizedBox(height: 168, child: ShelfMarquee(children: cards));
    }
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.cinema,
      emptyMessage: widget.isSelf
          ? 'You haven\'t finished anything yet.'
          : 'Nothing finished on their end.',
      children: _hasLoaded ? cards : const [],
    );
  }
}
