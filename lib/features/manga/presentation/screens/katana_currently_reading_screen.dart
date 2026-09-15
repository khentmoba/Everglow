import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/models/manga_item.dart';
import '../../data/services/katana_service.dart';
import '../../data/services/mangakakalot_service.dart';
import '../katana/currently_reading_shelf.dart' show CurrentlyReadingShelf;
import '../katana/katana_header.dart' show KatanaNav;
import '../katana/katana_nav.dart';
import '../katana/katana_tab_shell.dart';
import '../katana/katana_theme.dart';
import '../widgets/manga_details_drawer.dart';

/// Full Currently Reading list for MangaCelestia.
///
/// Couple users get "You" / partner tabs backed by each partner's
/// `manga_library` reading list. Tapping a card opens the Katana
/// detail page (or the classic drawer for older entries), Resume
/// jumps straight back into the saved chapter, and the X removes the
/// title from Currently Reading without deleting chapter progress.
class KatanaCurrentlyReadingScreen extends StatefulWidget {
  const KatanaCurrentlyReadingScreen({super.key, this.embed = false});

  /// When true, renders headerless tab content for [KatanaTabShell].
  /// When false (standalone route), wraps in the tab shell so header
  /// tabs still switch in place.
  final bool embed;

  @override
  State<KatanaCurrentlyReadingScreen> createState() =>
      _KatanaCurrentlyReadingScreenState();
}

class _KatanaCurrentlyReadingScreenState
    extends State<KatanaCurrentlyReadingScreen> {
  final MangaKakalotService _library = MangaKakalotService();
  final KatanaService _katana = KatanaService();

  List<MangaItem> _mine = const [];
  List<MangaItem> _partner = const [];
  Map<String, KatanaBookmark> _bookmarksBySlug = const {};
  bool _loading = true;
  bool _showPartner = false;
  String? _busySlug;

  StreamSubscription<List<MangaItem>>? _mineSub;
  StreamSubscription<List<MangaItem>>? _partnerSub;
  StreamSubscription<List<KatanaBookmark>>? _bookmarkSub;

  String get _user => context.read<AuthService>().currentUser ?? '';
  String? get _partnerName =>
      context.read<AuthService>().partnerUsername;

  bool get _hasPartner =>
      _partnerName != null && _partnerName!.isNotEmpty;

  String _displayName(String user) {
    if (user == 'khentsgdz') return 'Khent';
    if (user == 'clairjassen') return 'Clair';
    return user;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    final user = _user;
    if (user.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _mineSub = _library
        .getReadingPreviewStream(user, limit: 100)
        .listen((items) {
      if (mounted) {
        setState(() {
          _mine = items;
          _loading = false;
        });
      }
    });
    if (_hasPartner) {
      _partnerSub = _library
          .getReadingPreviewStream(_partnerName!, limit: 100)
          .listen((items) {
        if (mounted) setState(() => _partner = items);
      });
    }
    _bookmarkSub = _katana.bookmarkStream(user).listen((items) {
      if (mounted) {
        setState(() {
          _bookmarksBySlug = {for (final b in items) b.slug: b};
        });
      }
    });
  }

  @override
  void dispose() {
    _mineSub?.cancel();
    _partnerSub?.cancel();
    _bookmarkSub?.cancel();
    super.dispose();
  }

  List<MangaItem> get _visible => _showPartner ? _partner : _mine;

  Future<void> _resume(MangaItem item) async {
    final slug = CurrentlyReadingShelf.katanaSlugOf(item);
    if (slug.isEmpty || _busySlug != null) return;
    if (!item.mangaId.startsWith('katana|')) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MangaDetailsDrawer(item: item),
      );
      return;
    }
    setState(() => _busySlug = slug);
    try {
      final detail = await _katana.fetchMangaDetail(slug);
      if (!mounted) return;
      final chapters = detail?.chapters ?? const <KatanaChapter>[];
      final sorted = sortChaptersAscending(chapters);
      if (sorted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No chapters available for this series yet.'),
            backgroundColor: KatanaColors.headerDark,
          ),
        );
        return;
      }
      final progress = _bookmarksBySlug[slug];
      KatanaChapter target = sorted.first;
      final wantId = progress?.lastReadChapterId.isNotEmpty == true
          ? progress!.lastReadChapterId
          : item.lastReadChapterId;
      if (wantId.isNotEmpty) {
        target = sorted.firstWhere((c) => c.id == wantId,
            orElse: () => sorted.first);
      }
      pushReader(
        context,
        slug: slug,
        chapterId: target.path,
        chapters: chapters,
        mangaTitle: item.title,
        coverUrl: item.coverUrl,
      );
    } finally {
      if (mounted) setState(() => _busySlug = null);
    }
  }

  void _open(MangaItem item) {
    final slug = CurrentlyReadingShelf.katanaSlugOf(item);
    if (slug.isNotEmpty && item.mangaId.startsWith('katana|')) {
      pushDetail(context, slug);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MangaDetailsDrawer(item: item),
    );
  }

  Future<void> _remove(MangaItem item) async {
    final user = _user;
    if (item.mangaId.startsWith('katana|')) {
      final slug = CurrentlyReadingShelf.katanaSlugOf(item);
      await _katana.setReading(
        KatanaManga(slug: slug, id: slug, title: item.title, coverUrl: item.coverUrl),
        user,
        reading: false,
      );
    } else {
      await _library.removeFromLibrary(item.mangaId, user);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embed) {
      return const KatanaTabShell(initialTab: KatanaNav.reading);
    }
    return _buildContent();
  }

  /// Headerless tab content for [KatanaTabShell].
  Widget _buildContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: KatanaColors.accent,
                        ),
                      )
                    : _user.isEmpty
                        ? _empty(
                            icon: Icons.person_off_outlined,
                            title: 'Sign in to track reading',
                            subtitle:
                                'Your Currently Reading list will show up here.',
                          )
                        : ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 14, 16, 60),
                            children: [
                              const KatanaSectionHeader(
                                title: 'Currently Reading',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Everything you marked as Reading, with where you left off.',
                                style: KatanaType.small,
                              ),
                              if (_hasPartner) ...[
                                const SizedBox(height: 12),
                                _tabs(),
                              ],
                              const SizedBox(height: 12),
                              if (_visible.isEmpty)
                                _empty(
                                  icon: Icons.auto_stories_rounded,
                                  title: _showPartner
                                      ? 'Nothing here yet'
                                      : 'Nothing in progress yet',
                                  subtitle: _showPartner
                                      ? 'Nothing on their reading list.'
                                      : 'Open any series and tap "Reading" to pin it here for Clair.',
                                )
                              else
                                for (final item in _visible) ...[
                                  _ReadingListCard(
                                    item: item,
                                    progress: _bookmarksBySlug[
                                        CurrentlyReadingShelf.katanaSlugOf(
                                            item)],
                                    busy: _busySlug ==
                                        CurrentlyReadingShelf.katanaSlugOf(
                                            item),
                                    canRemove: !_showPartner,
                                    onResume: () => _resume(item),
                                    onOpen: () => _open(item),
                                    onRemove: () => _remove(item),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                            ],
                          ),
        ),
    );
  }

  Widget _tabs() {
    return Row(
      children: [
        _tab('You', !_showPartner, () => setState(() => _showPartner = false)),
        const SizedBox(width: 8),
        _tab(
          _displayName(_partnerName!),
          _showPartner,
          () => setState(() => _showPartner = true),
        ),
      ],
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? KatanaColors.accent.withValues(alpha: 0.18)
              : KatanaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? KatanaColors.accent : KatanaColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            color: selected ? KatanaColors.accent : KatanaColors.text,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: KatanaColors.textLight),
            const SizedBox(height: 14),
            Text(title, style: KatanaType.heading),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center, style: KatanaType.body),
          ],
        ),
      ),
    );
  }
}

class _ReadingListCard extends StatelessWidget {
  final MangaItem item;
  final KatanaBookmark? progress;
  final bool busy;
  final bool canRemove;
  final VoidCallback onResume;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _ReadingListCard({
    required this.item,
    required this.progress,
    required this.busy,
    required this.canRemove,
    required this.onResume,
    required this.onOpen,
    required this.onRemove,
  });

  String get _progressLine {
    final chapter = progress?.lastReadChapterTitle.isNotEmpty == true
        ? progress!.lastReadChapterTitle
        : (item.lastReadChapterId.isNotEmpty ? item.lastReadChapterId : '');
    final page = progress?.lastReadPage ?? item.lastReadPage;
    if (chapter.isEmpty && page <= 0) return 'Just started';
    if (chapter.isEmpty) return 'Page $page';
    if (page > 0) return '$chapter • Page $page';
    return chapter;
  }

  @override
  Widget build(BuildContext context) {
    return KatanaCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 78,
                height: 110,
                child: item.coverUrl.isEmpty
                    ? Container(
                        color: KatanaColors.border,
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: KatanaColors.textLight,
                        ),
                      )
                    : KatanaNetworkImage(
                        item.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: KatanaColors.border,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: KatanaColors.textLight,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onOpen,
                  child: Text(
                    item.title.isEmpty ? 'Untitled series' : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.text,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _progressLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KatanaType.accent.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    KatanaButton(
                      label: busy ? 'Opening...' : 'Resume',
                      icon: Icons.play_arrow_rounded,
                      onTap: busy ? null : onResume,
                    ),
                    if (canRemove)
                      KatanaButton(
                        label: 'Remove',
                        icon: Icons.close_rounded,
                        filled: false,
                        onTap: onRemove,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
