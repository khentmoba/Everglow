import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/mangakakalot_service.dart';
import 'package:everglow/features/manga/presentation/screens/manga_library_screen.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_details_drawer.dart';
import 'package:everglow/services/auth_service.dart';
import 'shelf_widgets.dart';

/// "Reading" shelf on the dashboard.
///
/// For the couple (khentsgdz / clairjassen) it streams the combined
/// manga library from both partners. For other users it falls back
/// to the current user's own library.
class MangaPreview extends StatelessWidget {
  const MangaPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = MangaKakalotService();
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCouple = auth.isCoupleUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _MangaShelf(
        stream: isCouple
            ? service.getCoupleLibraryStream()
            : service.getLibraryStream(userName),
      ),
    );
  }
}

class _MangaShelf extends StatefulWidget {
  final Stream<List<MangaItem>> stream;
  const _MangaShelf({required this.stream});

  @override
  State<_MangaShelf> createState() => _MangaShelfState();
}

class _MangaShelfState extends State<_MangaShelf> {
  List<MangaItem> _items = [];
  bool _hasLoaded = false;
  StreamSubscription<List<MangaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _streamSub = widget.stream.listen((items) {
      final filtered = items.where((i) => i.libraryStatus != 'none').toList();
      filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _hasLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  void _openDetails(MangaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MangaDetailsDrawer(item: item),
    );
  }

  String _subtitleFor(MangaItem item) {
    final author = item.author.isNotEmpty ? item.author : item.artist;
    if (author.isEmpty) return item.contentType;
    return '$author • ${item.contentType}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShelfHeader(
          accent: ShelfAccent.manga,
          title: 'Reading',
          itemCount: _items.length,
          onViewAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MangaLibraryScreen(),
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
              accent: ShelfAccent.manga,
              message: 'No manga in your library yet. Find your next read!',
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
                        accent: ShelfAccent.manga,
                        imageUrl: item.coverUrl,
                        title: item.title,
                        subtitle: _subtitleFor(item),
                        topBadge: item.contentType.toUpperCase(),
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
