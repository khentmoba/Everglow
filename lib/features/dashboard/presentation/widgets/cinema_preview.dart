import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/screens/cinema_screen.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/shared/widgets/adblocker_gate.dart';
import 'package:everglow/services/auth_service.dart';
import 'shelf_widgets.dart';

/// "Watched" shelf on the dashboard.
///
/// For the couple (khentsgdz / clairjassen) it streams the combined
/// watched catalog from both partners so Khent and Clair always see
/// the same shared reel. For other users (Breyan / Octagram) it
/// falls back to the current user's own watched list.
class CinemaPreview extends StatelessWidget {
  const CinemaPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tmdbService = TMDBService();
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCouple = auth.isCoupleUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _CinemaShelf(
        stream: isCouple
            ? tmdbService.getCoupleWatchListStream()
            : tmdbService.getWatchListStream(userName),
      ),
    );
  }
}

class _CinemaShelf extends StatefulWidget {
  final Stream<List<MediaItem>> stream;
  const _CinemaShelf({required this.stream});

  @override
  State<_CinemaShelf> createState() => _CinemaShelfState();
}

class _CinemaShelfState extends State<_CinemaShelf> {
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
    if (item.year.isNotEmpty) parts.add(item.year);
    if (item.mediaType.isNotEmpty) {
      parts.add(item.mediaType == 'tv' ? 'Series' : 'Movie');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShelfHeader(
          accent: ShelfAccent.cinema,
          title: 'Watched',
          itemCount: _items.length,
          onViewAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdblockerGate(child: CinemaScreen()),
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
              accent: ShelfAccent.cinema,
              message: 'No movies watched yet. Start a movie night!',
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
                        accent: ShelfAccent.cinema,
                        imageUrl: item.posterPath,
                        title: item.title,
                        subtitle: _subtitleFor(item),
                        topBadge: item.mediaType.toUpperCase() == 'TV'
                            ? 'TV'
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
