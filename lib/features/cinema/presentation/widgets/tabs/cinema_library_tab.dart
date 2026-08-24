import 'package:flutter/material.dart';

import '../../../../../core/theme/app_breakpoints.dart';
import '../../../data/models/media_item.dart';
import '../netflix/netflix_colors.dart';
import '../netflix/netflix_nav_bar.dart';
import '../netflix/netflix_poster_card.dart';
import '../../../../../core/theme/app_typography.dart';

enum _LibraryFilter { all, watching, toWatch, watched }

/// My List - a quiet poster grid of the couple's cinema collection.
class CinemaLibraryTab extends StatefulWidget {
  final List<MediaItem> watchlist;
  final void Function(MediaItem) onMediaTap;
  final void Function(MediaItem)? onPlayItem;
  final void Function(MediaItem, bool add)? onToggleListItem;
  final void Function(MediaItem, double? rating)? onRateItem;
  final void Function(int) onSwitchTab;

  const CinemaLibraryTab({
    super.key,
    required this.watchlist,
    required this.onMediaTap,
    this.onPlayItem,
    this.onToggleListItem,
    this.onRateItem,
    required this.onSwitchTab,
  });

  @override
  State<CinemaLibraryTab> createState() => _CinemaLibraryTabState();
}

class _CinemaLibraryTabState extends State<CinemaLibraryTab> {
  _LibraryFilter _filter = _LibraryFilter.all;

  List<MediaItem> get _visible {
    // Anime lives in the dedicated anime section — keep this rail pure
    // cinema so the same title doesn't crowd both lists.
    final all = widget.watchlist.where((i) => !i.isAnime).toList();
    return switch (_filter) {
      _LibraryFilter.all => all,
      _LibraryFilter.watching =>
        all.where((i) => i.isCurrentlyWatching).toList(),
      _LibraryFilter.toWatch => all.where((i) => i.isToWatch).toList(),
      _LibraryFilter.watched => all.where((i) => i.isWatched).toList(),
    };
  }

  double? _progress(MediaItem item) {
    final position = item.currentTimestamp ?? 0;
    final duration = item.durationSeconds ?? 0;
    if (position <= 0 || duration <= 0) return null;
    return (position / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.watchlist
        .where(
          (i) =>
              !i.isAnime &&
              (i.isCurrentlyWatching || i.isToWatch || i.isWatched),
        )
        .isEmpty;

    if (isEmpty) return _buildEmptyLibrary(context);

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
                    '${widget.watchlist.where((i) => !i.isAnime).length} ${widget.watchlist.where((i) => !i.isAnime).length == 1 ? 'title' : 'titles'}',
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
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  'Nothing here yet.',
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
                    : (AppBreakpoint.isTablet(context) ? 4 : 3),
                childAspectRatio: 0.67,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final item = visible[index];
                return NetflixPosterCard(
                  item: item,
                  compact: true,
                  selfPreview: true,
                  progress: item.isCurrentlyWatching ? _progress(item) : null,
                  onTap: () => widget.onMediaTap(item),
                  onPlay: widget.onPlayItem,
                  onToggleList: widget.onToggleListItem,
                  onRate: widget.onRateItem,
                  isInList: (_) => true,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : NetflixColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.white : NetflixColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitHeading.copyWith(
            color: selected ? Colors.black : NetflixColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
