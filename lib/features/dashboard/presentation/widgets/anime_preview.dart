import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../cinema/data/models/media_item.dart';
import '../../../cinema/data/services/tmdb_service.dart';
import '../../../cinema/presentation/widgets/episode_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';

/// "Anime" shelf on the dashboard.
///
/// For couple users (khentsgdz / clairjassen) the shelf splits into
/// two labeled sub-rows — "Me" and the partner — so each partner can
/// see what the other has finished watching in the anime column.
/// Non-couple users keep the original single-row layout (one stream
/// of their own watched anime only).
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
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _AnimeShelf(
              userName: userName,
              label: 'ME',
              isSelf: true,
            ),
            _AnimeShelf(
              userName: partner,
              label: partnerLabel,
              isSelf: false,
            ),
          ] else
            _AnimeShelf(
              userName: userName,
              label: null,
              isSelf: true,
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

  void _subscribe() {
    _streamSub =
        _service.getAnimeWatchListStream(widget.userName).listen((items) {
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
      accent: ShelfAccent.anime,
      title: 'Anime',
      itemCount: _items.length,
      badge: _items.isNotEmpty ? null : 'NEW',
      onViewAll: () => context.push('/anime'),
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
      _subscribe();
    }
  }

  void _subscribe() {
    _streamSub =
        _service.getAnimeWatchListStream(widget.userName).listen((items) {
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
        return const SizedBox(
          height: 160,
          child: ShelfMarquee(hasLoaded: false, children: []),
        );
      }
      if (cards.isEmpty) {
        return SizedBox(
          height: 110,
          child: ShelfEmpty(
            accent: ShelfAccent.anime,
            message: 'No anime watched yet. Time for a binge!',
          ),
        );
      }
      return SizedBox(height: 168, child: ShelfMarquee(children: cards));
    }
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.anime,
      emptyMessage: widget.isSelf
          ? 'You haven\'t finished any anime yet.'
          : 'Nothing finished on their end.',
      children: _hasLoaded ? cards : const [],
    );
  }
}
