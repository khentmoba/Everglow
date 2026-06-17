import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/screens/anime_screen.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/shared/widgets/adblocker_gate.dart';
import 'package:everglow/services/auth_service.dart';
import 'shelf_widgets.dart';

/// "Anime" shelf on the dashboard. Each user sees only their own
/// watched anime. Anime filtering happens in
/// [TMDBService.getAnimeWatchListStream].
class AnimePreview extends StatelessWidget {
  const AnimePreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tmdbService = TMDBService();
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _AnimeShelf(
        stream: tmdbService.getAnimeWatchListStream(userName),
      ),
    );
  }
}

class _AnimeShelf extends StatefulWidget {
  final Stream<List<MediaItem>> stream;
  const _AnimeShelf({required this.stream});

  @override
  State<_AnimeShelf> createState() => _AnimeShelfState();
}

class _AnimeShelfState extends State<_AnimeShelf> {
  List<MediaItem> _items = [];
  bool _hasLoaded = false;
  StreamSubscription<List<MediaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _streamSub = widget.stream.listen((items) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShelfHeader(
          accent: ShelfAccent.anime,
          title: 'Anime',
          itemCount: _items.length,
          badge: _items.isNotEmpty ? null : 'NEW',
          onViewAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdblockerGate(child: AnimeScreen()),
            ),
          ),
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
            height: 110,
            child: ShelfEmpty(
              accent: ShelfAccent.anime,
              message: 'No anime watched yet. Time for a binge!',
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
                        accent: ShelfAccent.anime,
                        imageUrl: item.posterPath,
                        title: item.title,
                        subtitle: _subtitleFor(item),
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
