import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../manga/data/models/manga_item.dart';
import '../../../manga/data/services/mangadex_service.dart';
import '../../../manga/data/services/mangakakalot_service.dart';
import '../../../manga/presentation/katana/katana_nav.dart';
import '../../../manga/presentation/widgets/manga_details_drawer.dart';
import '../../../../core/services/auth_service.dart';
import '_partner_label.dart';
import 'partner_subrow.dart';
import 'shelf_widgets.dart';

/// "Reading" shelf on the dashboard.
///
/// For couple users (khentsgdz / clairjassen) the shelf splits into
/// two labeled sub-rows — "Me" and the partner — sourced from each
/// partner's `manga_library` collection filtered by
/// `libraryStatus == 'reading'`. This gives each partner a quick view
/// of what the other is actively reading.
///
/// Non-couple users keep the original merged-couple or single-user
/// layout that streams every title in their library (any status).
class MangaPreview extends StatelessWidget {
  const MangaPreview({super.key});

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
          _MangaHeader(userName: userName, isCouple: isCouple),
          if (isCouple && partner != null && partner.isNotEmpty) ...[
            _MangaShelf(
              userName: userName,
              readingOnly: true,
              label: 'ME',
              isSelf: true,
            ),
            _MangaShelf(
              userName: partner,
              readingOnly: true,
              label: partnerLabel,
              isSelf: false,
            ),
          ] else
            _MangaShelf(
              userName: userName,
              readingOnly: false,
              label: null,
              isSelf: true,
            ),
        ],
      ),
    );
  }
}

class _MangaHeader extends StatefulWidget {
  final String userName;
  final bool isCouple;
  const _MangaHeader({required this.userName, required this.isCouple});

  @override
  State<_MangaHeader> createState() => _MangaHeaderState();
}

class _MangaHeaderState extends State<_MangaHeader> {
  final MangaKakalotService _service = MangaKakalotService();
  List<MangaItem> _items = [];
  StreamSubscription<List<MangaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _MangaHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName ||
        oldWidget.isCouple != widget.isCouple) {
      _streamSub?.cancel();
      _items = [];
      _subscribe();
    }
  }

  void _subscribe() {
    final stream = widget.isCouple
        ? _service.getCoupleLibraryStream()
        : _service.getLibraryStream(widget.userName);
    _streamSub = stream.listen((items) {
      final filtered = items.where((i) => i.libraryStatus != 'none').toList();
      filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
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
      accent: ShelfAccent.manga,
      title: 'Reading',
      itemCount: _items.length,
      onViewAll: () => context.push('/manga'),
    );
  }
}

class _MangaShelf extends StatefulWidget {
  final String userName;
  final bool readingOnly;
  final String? label;
  final bool isSelf;
  const _MangaShelf({
    required this.userName,
    required this.readingOnly,
    required this.label,
    required this.isSelf,
  });

  @override
  State<_MangaShelf> createState() => _MangaShelfState();
}

class _MangaShelfState extends State<_MangaShelf> {
  final MangaKakalotService _service = MangaKakalotService();
  List<MangaItem> _items = [];
  bool _hasLoaded = false;
  StreamSubscription<List<MangaItem>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _MangaShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName ||
        oldWidget.readingOnly != widget.readingOnly) {
      _streamSub?.cancel();
      _items = [];
      _hasLoaded = false;
      _subscribe();
    }
  }

  void _subscribe() {
    final stream = widget.readingOnly
        ? _service.getReadingStream(widget.userName)
        : _service.getLibraryStream(widget.userName);
    _streamSub = stream.listen((items) {
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

  void _openDetails(MangaItem item) {
    // Katana-sourced entries (added via "Khent Reading" / "Claire Reading")
    // open the Katana detail page so the reading button stays reachable.
    if (item.mangaId.startsWith('katana|')) {
      pushDetail(context, item.mangaKakalotId);
      return;
    }
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

  String _proxyCoverUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http')) {
      if (url.contains('proxyMangaImage')) return url;
      if (url.contains('mangadex.org') || url.contains('mangadex.network')) {
        return MangaDexService().proxiedImageUrl(url);
      }
    }
    return url;
  }

  List<Widget> _buildCards() {
    return _items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ShelfCard(
              accent: ShelfAccent.manga,
              imageUrl: _proxyCoverUrl(item.coverUrl),
              title: item.title,
              subtitle: _subtitleFor(item),
              topBadge: item.contentType.toUpperCase(),
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
            accent: ShelfAccent.manga,
            message: 'No manga in your library yet. Find your next read!',
          ),
        );
      }
      return SizedBox(height: 168, child: ShelfMarquee(children: cards));
    }
    return PartnerSubrow(
      label: widget.label!,
      accent: ShelfAccent.manga,
      emptyMessage: widget.isSelf
          ? 'You aren\'t reading anything right now.'
          : 'Nothing on their reading list.',
      children: _hasLoaded ? cards : const [],
    );
  }
}
