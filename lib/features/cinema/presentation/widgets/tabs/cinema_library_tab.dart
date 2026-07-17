import 'package:flutter/material.dart' hide FilterChip;
import 'package:google_fonts/google_fonts.dart';

import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/shared/widgets/shelf/shelf_icon_button.dart';
import 'package:everglow/shared/widgets/shelf/shelf_poster_card.dart';
import 'package:everglow/core/theme/app_breakpoints.dart';

// ─── Cinema Color Tokens ─────────────────────────────────────────────
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cAmber = Color(0xFFF0A500);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);

// ─────────────────────────────────────────────────────────────────────
// 4. LIBRARY TAB
// ─────────────────────────────────────────────────────────────────────

class CinemaLibraryTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currentlyWatching =
        watchlist.where((i) => i.isCurrentlyWatching).toList();
    final wantToWatch = watchlist.where((i) => i.isToWatch).toList();
    final watched = watchlist.where((i) => i.isWatched).toList();

    if (currentlyWatching.isEmpty && wantToWatch.isEmpty && watched.isEmpty) {
      return _buildEmptyLibrary(context);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 14,
            20,
            0,
          ),
          child: Row(
            children: [
              ShelfIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                semanticLabel: 'Back to Home',
                tooltip: 'Back to Home',
                onTap: () => onSwitchTab(0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Library',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _cWhite,
                      ),
                    ),
                    Text(
                      'CINEMA COLLECTION',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _cMuted,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Currently Watching
        if (currentlyWatching.isNotEmpty) ...[
          _librarySectionHeader(
            context,
            'Currently Watching',
            'RESUME PLAYING',
            Icons.play_circle_filled_rounded,
            const Color(0xFFFF6D00),
            currentlyWatching.length,
          ),
          _libraryGrid(context, currentlyWatching),
        ],
        // Want to Watch
        if (wantToWatch.isNotEmpty) ...[
          _librarySectionHeader(
            context,
            'Want to Watch',
            'YOUR QUEUE',
            Icons.bookmark_rounded,
            _cGold,
            wantToWatch.length,
          ),
          _libraryGrid(context, wantToWatch, badgeColor: _cGold),
        ],
        // Watched
        if (watched.isNotEmpty) ...[
          _librarySectionHeader(
            context,
            'Watched',
            'COMPLETED',
            Icons.check_circle_rounded,
            const Color(0xFF2E7D32),
            watched.length,
          ),
          _libraryGrid(context, watched, badgeColor: const Color(0xFF2E7D32)),
        ],
      ],
    );
  }

  Widget _buildEmptyLibrary(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_cDeepRose, _cAmber],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _cDeepRose.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: -8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.collections_bookmark_rounded,
                color: _cWhite,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cinema library is empty',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _cWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Search for movies or shows and add them to your library.\nItems you're watching or have watched will appear here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: _cMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => onSwitchTab(1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _cDeepRose.withValues(alpha: 0.3),
                      _cDeepRose.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _cDeepRose.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: _cWhite,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Search Movies & TV',
                      style: GoogleFonts.outfit(
                        color: _cWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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

  Widget _librarySectionHeader(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color accent,
    int count,
  ) {
    final isDesktop = AppBreakpoint.isDesktop(context);
    final horizontalPad = isDesktop ? 48.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _cWhite,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: _cMuted,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.outfit(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _libraryGrid(
    BuildContext context,
    List<MediaItem> items, {
    Color? badgeColor,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            isDesktop ? 6 : (AppBreakpoint.isTablet(context) ? 4 : 2),
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        String badgeLabel;
        Color bColor;
        IconData bIcon;
        if (item.isCurrentlyWatching) {
          badgeLabel = item.currentEpisode != null
              ? 'S${item.currentSeason ?? 1}E${item.currentEpisode}'
              : 'WATCHING';
          bColor = const Color(0xFFFF6D00);
          bIcon = Icons.play_circle_filled_rounded;
        } else if (item.isWatched) {
          badgeLabel = item.watchedDisplay.toUpperCase();
          bColor = badgeColor ?? const Color(0xFF2E7D32);
          bIcon = Icons.check_rounded;
        } else {
          badgeLabel = item.wanterDisplay.toUpperCase();
          bColor = badgeColor ?? _cGold;
          bIcon = Icons.bookmark_rounded;
        }
        return ShelfPosterCard(
          imageUrl: item.posterPath,
          title: item.title,
          subtitle: item.year.isNotEmpty ? item.year : null,
          badge: badgeLabel,
          badgeColor: bColor,
          badgeIcon: bIcon,
          onTap: () => onMediaTap(item),
        );
      },
    );
  }
}
