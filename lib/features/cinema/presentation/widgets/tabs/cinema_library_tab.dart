import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:everglow/core/theme/app_breakpoints.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_colors.dart';
import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_poster_card.dart';

enum _LibraryFilter { all, watching, toWatch, watched }

/// My List - a quiet poster grid of the couple's cinema collection.
class CinemaLibraryTab extends StatefulWidget {
  final List<MediaItem> watchlist;
  final void Function(MediaItem) onMediaTap;
  final void Function(int) onSwitchTab;

  const CinemaLibraryTab({
    super.key,
    required this.watchlist,
    required this.onMediaTap,
    required this.onSwitchTab,
  });

  @override
  State<CinemaLibraryTab> createState() => _CinemaLibraryTabState();
}

class _CinemaLibraryTabState extends State<CinemaLibraryTab> {
  _LibraryFilter _filter = _LibraryFilter.all;

  List<MediaItem> get _visible {
    final all = widget.watchlist;
    return switch (_filter) {
      _LibraryFilter.all => all,
      _LibraryFilter.watching =>
        all.where((i) => i.isCurrentlyWatching).toList(),
      _LibraryFilter.toWatch => all.where((i) => i.isToWatch).toList(),
      _LibraryFilter.watched => all.where((i) => i.isWatched).toList(),
    };
  }

  double _progress(MediaItem item) {
    if (item.mediaType == 'tv') {
      final ep = item.currentEpisode ?? 1;
      return ((ep - 1) % 12) / 12;
    }
    return 0.12;
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.watchlist
        .where((i) => i.isCurrentlyWatching || i.isToWatch || i.isWatched)
        .isEmpty;

    if (isEmpty) return _buildEmptyLibrary(context);

    final isDesktop = AppBreakpoint.isDesktop(context);
    final visible = _visible;
    return ListView(
      padding: EdgeInsets.only(bottom: 110),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            isDesktop ? 24 : (MediaQuery.paddingOf(context).top + 12),
            isDesktop ? 48 : 16,
            2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'My List',
                style: GoogleFonts.outfit(
                  fontSize: isDesktop ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  color: NetflixColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${widget.watchlist.length} ${widget.watchlist.length == 1 ? 'title' : 'titles'}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: NetflixColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 48 : 16,
            14,
            isDesktop ? 48 : 16,
            18,
          ),
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
                onTap: () => setState(() => _filter = _LibraryFilter.watching),
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
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Text(
                'Nothing here yet.',
                style: GoogleFonts.outfit(
                  color: NetflixColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 16),
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
              );
            },
          ),
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
            Icon(
              Icons.bookmark_border_rounded,
              color: NetflixColors.textMuted,
              size: 52,
            ),
            const SizedBox(height: 18),
            Text(
              'Your list is empty',
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 19 : 17,
                fontWeight: FontWeight.w700,
                color: NetflixColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Movies and shows you save or watch will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
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
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
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
          style: GoogleFonts.outfit(
            color: selected ? Colors.black : NetflixColors.textSecondary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
