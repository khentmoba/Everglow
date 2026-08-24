import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/media_item.dart';
import '../../../data/services/tmdb_service.dart';
import '../../../../../core/services/auth_service.dart';

import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_grid.dart';
import 'animex_tokens.dart';

/// My List page: stats, source toggle, and the couple's anime catalog in
/// Watching / Plan to Watch / Completed sections.
class AnimeXMyListPage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXMyListPage({super.key, required this.controller});

  @override
  State<AnimeXMyListPage> createState() => _AnimeXMyListPageState();
}

class _AnimeXMyListPageState extends State<AnimeXMyListPage> {
  final TMDBService _tmdb = TMDBService();
  int _source = 0;

  Future<void> _remove(MediaItem item) async {
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) return;
    await _tmdb.removeFromWatchList(item.tmdbId, userName);
  }

  void _showSyncHint(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label sync is ready - connect your $label account to pull your list',
        ),
        backgroundColor: AnimeXTokens.surfaceRaised,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.controller.library;
    final watching = library.where((i) => i.isCurrentlyWatching).toList();
    final toWatch = library.where((i) => i.isToWatch).toList();
    final watched = library.where((i) => i.isWatched).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
      children: [
        Text(
          'My List',
          style: bebasStyle(size: 32, color: AnimeXTokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          '${library.length} anime in your collection',
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        const SizedBox(height: 16),
        _buildSourceToggle(),
        const SizedBox(height: 12),
        _buildQuickLinks(),
        const SizedBox(height: 20),
        _buildStats(watching.length, toWatch.length, watched.length),
        const SizedBox(height: 28),
        if (library.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bookmark_add_outlined,
                    color: AnimeXTokens.textMuted,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your list is empty - add anime from Search',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 14,
                      color: AnimeXTokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (watching.isNotEmpty) ...[
            _sectionTitle('Watching', watching.length),
            AnimeXGrid(
              items: watching,
              onTap: (item) => widget.controller.openWatch(item),
              hoverActionBuilder: (item) => _removeButton(item),
            ),
            const SizedBox(height: 28),
          ],
          if (toWatch.isNotEmpty) ...[
            _sectionTitle('Plan to Watch', toWatch.length),
            AnimeXGrid(
              items: toWatch,
              onTap: (item) => widget.controller.openWatch(item),
              hoverActionBuilder: (item) => _removeButton(item),
            ),
            const SizedBox(height: 28),
          ],
          if (watched.isNotEmpty) ...[
            _sectionTitle('Completed', watched.length),
            AnimeXGrid(
              items: watched,
              onTap: (item) => widget.controller.openWatch(item),
              hoverActionBuilder: (item) => _removeButton(item),
            ),
          ],
        ],
        const SizedBox(height: 24),
        AnimeXFooter(controller: widget.controller),
      ],
    );
  }

  Widget _removeButton(MediaItem item) {
    return GestureDetector(
      onTap: () => _remove(item),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xCC0A0A0F),
            shape: BoxShape.circle,
            border: Border.all(color: AnimeXTokens.borderStrong),
          ),
          child: const Icon(
            Icons.bookmark_remove_rounded,
            size: 15,
            color: AnimeXTokens.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            title,
            style: dmSansStyle(
              size: 16.8,
              color: AnimeXTokens.textPrimary,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: dmSansStyle(
                size: 11,
                color: AnimeXTokens.textSecondary,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(int watching, int toWatch, int watched) {
    return Row(
      children: [
        _Stat(label: 'Watching', count: watching, color: AnimeXTokens.success),
        const SizedBox(width: 10),
        _Stat(
          label: 'Plan to Watch',
          count: toWatch,
          color: AnimeXTokens.accent,
        ),
        const SizedBox(width: 10),
        _Stat(
          label: 'Completed',
          count: watched,
          color: AnimeXTokens.accentWarm,
        ),
        const SizedBox(width: 10),
        _Stat(
          label: 'Total',
          count: watching + toWatch + watched,
          color: AnimeXTokens.textPrimary,
        ),
      ],
    );
  }

  Widget _buildSourceToggle() {
    const sources = ['Everglow', 'AniList', 'MAL'];
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < sources.length; i++)
              GestureDetector(
                onTap: () {
                  setState(() => _source = i);
                  if (i != 0) _showSyncHint(sources[i]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: i == _source
                        ? AnimeXTokens.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    sources[i],
                    style: dmSansStyle(
                      size: 11.5,
                      color: i == _source
                          ? Colors.white
                          : AnimeXTokens.textSecondary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _QuickLink(
          label: 'Playlists',
          icon: Icons.video_library_outlined,
          onTap: () => widget.controller.goTo(AnimexPage.playlists),
        ),
        _QuickLink(
          label: 'Seasonal',
          icon: Icons.calendar_view_month_rounded,
          onTap: () => widget.controller.goTo(AnimexPage.seasonal),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
            border: Border.all(color: AnimeXTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AnimeXTokens.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: dmSansStyle(
                  size: 12.5,
                  color: AnimeXTokens.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _Stat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
          border: Border.all(color: AnimeXTokens.border),
        ),
        child: Column(
          children: [
            Text('$count', style: bebasStyle(size: 24, color: color)),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dmSansStyle(size: 10.5, color: AnimeXTokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
