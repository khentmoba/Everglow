import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/services/auth_service.dart';
import 'shelf_widgets.dart';

/// "Currently Watching" shelf on the dashboard. Shows items that have
/// a watching status across both cinema and anime, sorted by most
/// recently updated. For the couple it merges both partners' lists;
/// for other users it shows their own.
class CurrentlyWatchingPreview extends StatelessWidget {
  const CurrentlyWatchingPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tmdbService = TMDBService();
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCouple = auth.isCoupleUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _CurrentlyWatchingShelf(
        stream: isCouple
            ? tmdbService.getCoupleCurrentlyWatchingStream()
            : tmdbService.getCurrentlyWatchingStream(userName),
      ),
    );
  }
}

class _CurrentlyWatchingShelf extends StatefulWidget {
  final Stream<List<MediaItem>> stream;
  const _CurrentlyWatchingShelf({required this.stream});

  @override
  State<_CurrentlyWatchingShelf> createState() =>
      _CurrentlyWatchingShelfState();
}

class _CurrentlyWatchingShelfState extends State<_CurrentlyWatchingShelf> {
  List<MediaItem> _items = [];
  bool _hasLoaded = false;
  StreamSubscription<List<MediaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _streamSub = widget.stream.listen((items) {
      if (!mounted) return;
      setState(() {
        _items = items;
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

  String? _subtitleFor(MediaItem item) {
    final parts = <String>[];
    if (item.currentEpisode != null) {
      parts.add('S${item.currentSeason ?? 1}E${item.currentEpisode}');
    }
    if (item.year.isNotEmpty) parts.add(item.year);
    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShelfHeader(
          accent: ShelfAccent.cinema,
          title: 'Currently Watching',
          itemCount: _items.length,
          onViewAll: () {},
        ),
        const SizedBox(height: 14),
        if (!_hasLoaded)
          const SizedBox(
            height: 160,
            child: ShelfMarquee(
              hasLoaded: false,
              children: [],
            ),
          )
        else if (_items.isEmpty)
          SizedBox(
            height: 90,
            child: ShelfEmpty(
              accent: ShelfAccent.cinema,
              message: 'Nothing playing right now. Start a movie or show!',
            ),
          )
        else
          SizedBox(
            height: 168,
            child: ShelfMarquee(
              children: _items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ShelfCard(
                        accent:
                            item.isAnime ? ShelfAccent.anime : ShelfAccent.cinema,
                        imageUrl: item.posterPath,
                        title: item.title,
                        subtitle: _subtitleFor(item),
                        topBadge: item.currentEpisode != null
                            ? 'S${item.currentSeason ?? 1}E${item.currentEpisode}'
                            : null,
                        onTap: () => _openDetails(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
