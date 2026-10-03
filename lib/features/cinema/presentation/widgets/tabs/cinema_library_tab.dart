import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../data/services/cinema_preferences.dart';
import '../cinema_viewing_preferences.dart';

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../../../core/utils/logger.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import '../netflix/netflix_colors.dart';
import '../netflix/netflix_nav_bar.dart';
import '../netflix/netflix_poster_card.dart';
import '../../../../../core/theme/app_typography.dart';

enum _LibraryFilter { all, watching, toWatch, watched, reminders }

enum _LibrarySort { recentlySaved, lastWatched, title }

/// My List - a quiet poster grid of the couple's cinema collection.
class CinemaLibraryTab extends StatefulWidget {
  final List<MediaItem> watchlist;
  final void Function(MediaItem) onMediaTap;
  final void Function(MediaItem)? onPlayItem;
  final void Function(MediaItem, bool add)? onToggleListItem;
  final void Function(MediaItem, double? rating)? onRateItem;
  final void Function(MediaItem)? onRemoveProgress;
  final void Function(int) onSwitchTab;
  final CinemaPreferences? preferences;

  const CinemaLibraryTab({
    super.key,
    required this.watchlist,
    required this.onMediaTap,
    this.onPlayItem,
    this.onToggleListItem,
    this.onRateItem,
    this.onRemoveProgress,
    required this.onSwitchTab,
    this.preferences,
  });

  @override
  State<CinemaLibraryTab> createState() => _CinemaLibraryTabState();
}

class _CinemaLibraryTabState extends State<CinemaLibraryTab> {
  _LibraryFilter _filter = _LibraryFilter.all;
  _LibrarySort _sort = _LibrarySort.recentlySaved;
  final _search = TextEditingController();
  CinemaPreferences get _preferences =>
      widget.preferences ?? CinemaPreferences.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nullable lookup keeps standalone previews/tests working without DI.
    final auth = context.watch<AuthService?>();
    if (auth != null) unawaited(_preferences.setUser(auth.currentUser));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  final TMDBService _service = TMDBService();
  final Set<String> _healAttempted = {};

  /// Reactive heal: a poster URL that looks valid but 404s (stale TMDB
  /// artwork) triggers one background heal instead of a permanent
  /// placeholder tile. The heal writes to Firestore, so the parent's
  /// watchlist stream picks up the fixed poster automatically. Deduped
  /// per doc id per session.
  void _handleImageError(MediaItem item) {
    if (item.id.isEmpty || _healAttempted.contains(item.id)) return;
    _healAttempted.add(item.id);
    unawaited(
      _service.healPoster(item).catchError((Object e) {
        Logger.e('Cinema library: poster heal failed', error: e);
        return null;
      }),
    );
  }

  List<MediaItem> get _visible {
    // Every movie (live-action or anime) plus non-anime TV lives here —
    // see MediaItem.isCinemaItem. Anime series live in the anime section.
    final all = widget.watchlist.cinemaItems;
    final filtered = switch (_filter) {
      _LibraryFilter.all => all,
      _LibraryFilter.watching => all.currentlyWatching,
      _LibraryFilter.toWatch => all.toWatch,
      _LibraryFilter.watched => all.watched,
      _LibraryFilter.reminders => all.reminded,
    };
    final query = _search.text.trim().toLowerCase();
    final visible = filtered
        .where((item) => item.title.toLowerCase().contains(query))
        .toList();
    visible.sort((a, b) {
      final comparison = switch (_sort) {
        _LibrarySort.recentlySaved => b.addedAt.compareTo(a.addedAt),
        // Unwatched titles follow watched titles, rather than looking recent.
        _LibrarySort.lastWatched =>
          (b.progressUpdatedAt ?? DateTime(1970)).compareTo(
            a.progressUpdatedAt ?? DateTime(1970),
          ),
        _LibrarySort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
      };
      if (comparison != 0) return comparison;
      final titleOrder = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return titleOrder != 0 ? titleOrder : a.id.compareTo(b.id);
    });
    return visible;
  }

  double? _progress(MediaItem item) {
    final position = item.currentTimestamp ?? 0;
    final duration = item.durationSeconds ?? 0;
    if (position <= 0 || duration <= 0) return null;
    return (position / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.watchlist.cinemaItems.isEmpty;

    final isDesktop = AppBreakpoint.isDesktop(context);
    final visible = _visible;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            cinemaTopContentInset(context),
            isDesktop ? 48 : 16,
            2,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'My List',
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: isDesktop ? 22 : 20,
                    color: NetflixColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${widget.watchlist.cinemaItems.length} ${widget.watchlist.cinemaItems.length == 1 ? 'title' : 'titles'}',
                    style: AppTypography.outfitWhite.copyWith(
                      fontSize: 13,
                      color: NetflixColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            14,
            isDesktop ? 48 : 16,
            18,
          ),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LibraryPill(
                  label: 'All',
                  selected: _filter == _LibraryFilter.all,
                  onTap: () => setState(() => _filter = _LibraryFilter.all),
                ),
                _LibraryPill(
                  label: 'Watching',
                  selected: _filter == _LibraryFilter.watching,
                  onTap: () =>
                      setState(() => _filter = _LibraryFilter.watching),
                ),
                _LibraryPill(
                  label: 'To Watch',
                  selected: _filter == _LibraryFilter.toWatch,
                  onTap: () => setState(() => _filter = _LibraryFilter.toWatch),
                ),
                _LibraryPill(
                  label: 'Watched',
                  selected: _filter == _LibraryFilter.watched,
                  onTap: () => setState(() => _filter = _LibraryFilter.watched),
                ),
                _LibraryPill(
                  label: 'Reminders',
                  selected: _filter == _LibraryFilter.reminders,
                  onTap: () =>
                      setState(() => _filter = _LibraryFilter.reminders),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            0,
            isDesktop ? 48 : 16,
            16,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Search My List',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_LibrarySort>(
                  initialValue: _sort,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sort My List'),
                  dropdownColor: NetflixColors.surface,
                  items: const [
                    DropdownMenuItem(
                      value: _LibrarySort.recentlySaved,
                      child: Text('Recently saved'),
                    ),
                    DropdownMenuItem(
                      value: _LibrarySort.lastWatched,
                      child: Text('Last watched'),
                    ),
                    DropdownMenuItem(
                      value: _LibrarySort.title,
                      child: Text('Title'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                ),
                ExpansionTile(
                  title: const Text('Viewing preferences'),
                  children: [
                    CinemaViewingPreferences(preferences: _preferences),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isEmpty)
          SliverToBoxAdapter(child: _buildEmptyLibrary(context))
        else if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  'No titles match your search or filter.',
                  style: AppTypography.outfitWhite.copyWith(
                    color: NetflixColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16),
            sliver: SliverGrid.builder(
              itemCount: visible.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop
                    ? 6
                    : (AppBreakpoint.isTablet(context) ? 5 : 3),
                childAspectRatio: 0.67,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final item = visible[index];
                final card = NetflixPosterCard(
                  item: item,
                  compact: true,
                  selfPreview: true,
                  progress: item.isCurrentlyWatching ? _progress(item) : null,
                  onTap: () => widget.onMediaTap(item),
                  onPlay: widget.onPlayItem,
                  onToggleList: widget.onToggleListItem,
                  onRate: widget.onRateItem,
                  isInList: (_) => true,
                  onImageError: () => _handleImageError(item),
                );
                final remove = widget.onRemoveProgress;
                if (remove == null || !item.isCurrentlyWatching) return card;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    card,
                    Positioned(
                      top: 6,
                      right: 6,
                      child: NetflixRemoveBadge(onTap: () => remove(item)),
                    ),
                  ],
                );
              },
            ),
          ),
        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _buildEmptyLibrary(BuildContext context) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_border_rounded,
              color: NetflixColors.textMuted,
              size: 52,
            ),
            const SizedBox(height: 18),
            Text(
              'Your list is empty',
              style: AppTypography.outfitHeading.copyWith(
                fontSize: isDesktop ? 19 : 17,
                color: NetflixColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Movies and shows you save or watch will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: NetflixColors.textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: () => widget.onSwitchTab(1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.black,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Find Something',
                      style: AppTypography.outfitHeading.copyWith(
                        color: Colors.black,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          backgroundColor: selected
              ? NetflixColors.textPrimary
              : NetflixColors.surface,
          foregroundColor: selected
              ? NetflixColors.background
              : NetflixColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: selected
                  ? NetflixColors.textPrimary
                  : NetflixColors.hairline,
            ),
          ),
          textStyle: AppTypography.outfitHeading.copyWith(fontSize: 12.5),
        ),
        child: Text(label),
      ),
    );
  }
}
