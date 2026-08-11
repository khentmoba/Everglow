import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_breakpoints.dart';
import 'motion.dart';
import 'shelf_section_header.dart';

/// Mochi's Picks recommendation row — powered by AI based on what
/// Khent and Clair have actually watched.
/// that suggests content based on watch history. Uses a horizontal
/// scroll of poster cards with a custom header.
class ForYouSection extends StatelessWidget {
  final List<_ForYouItem> items;
  final String eyebrow;
  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback? onSeeAll;

  const ForYouSection({
    super.key,
    required this.items,
    this.eyebrow = "Mochi's Picks",
    this.title = "Mochi's Picks 🐱",
    this.icon = Icons.favorite_rounded,
    this.accent = AppTheme.deepRose,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isDesktop ? 48 : 20, 28, isDesktop ? 48 : 20, 0),
          child: ShelfSectionHeader(
            eyebrow: eyebrow,
            title: title,
            icon: icon,
            accent: accent,
            count: items.length,
            countLabel: 'picks',
            onSeeAll: onSeeAll,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: isDesktop ? 260 : 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final item = items[i];
              return _ForYouCard(
                item: item,
                width: isDesktop ? 180 : 140,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ForYouCard extends StatefulWidget {
  final _ForYouItem item;
  final double width;

  const _ForYouCard({required this.item, required this.width});

  @override
  State<_ForYouCard> createState() => _ForYouCardState();
}

class _ForYouCardState extends State<_ForYouCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (show) => setState(() => _hovered = show),
        child: GestureDetector(
          onTap: widget.item.onTap,
          child: AnimatedContainer(
            duration: ShelfMotion.orZero(ShelfMotion.medium),
            curve: ShelfMotion.easeOutStrong,
            transform: _hovered
                ? (Matrix4.translationValues(0.0, -4.0, 0.0)
                      ..setEntry(0, 0, 1.03)
                      ..setEntry(1, 1, 1.03))
                : Matrix4.identity(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.item.imageUrl.isNotEmpty)
                          Image.network(
                            widget.item.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 400,
                            errorBuilder: (_, _, _) =>
                                Container(color: const Color(0xFF1C1228)),
                          )
                        else
                          Container(color: const Color(0xFF1C1228)),
                        // Hover overlay
                        if (_hovered)
                          Container(
                            color: Colors.black.withValues(alpha: 0.1),
                          ),
                        // Match badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.item.matchColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                        Text(
                          '${widget.item.matchPercent}%',
                          style: AppTypography.outfitHeading.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitHeading.copyWith(
                    fontSize: 12,
                  ),
                ),
                if (widget.item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitMuted.copyWith(
                    fontSize: 10,
                  ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Data model for a "For You" recommendation item.
class _ForYouItem {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final int matchPercent;
  final Color matchColor;
  final VoidCallback? onTap;

  const _ForYouItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.matchPercent = 95,
    this.matchColor = AppTheme.deepRose,
    this.onTap,
  });
}

/// Creates a list of [_ForYouItem] from a generic list of items
/// that have id, title, posterUrl, and year properties.
List<_ForYouItem> buildForYouItems<T>({
  required List<T> items,
  required String Function(T) getId,
  required String Function(T) getTitle,
  required String Function(T) getImageUrl,
  String? Function(T)? getSubtitle,
  int Function(T)? getMatchPercent,
  void Function(T)? onTap,
}) {
  return items.map((item) {
    return _ForYouItem(
      id: getId(item),
      title: getTitle(item),
      subtitle: getSubtitle?.call(item),
      imageUrl: getImageUrl(item),
      matchPercent: getMatchPercent?.call(item) ?? 95,
      matchColor: AppTheme.deepRose,
      onTap: onTap != null ? () => onTap(item) : null,
    );
  }).toList();
}

// ── Top 10 Ranking Section ──────────────────────────────────

/// "TOP 10 Today" ranking section — a vertical list of ranked items,
/// inspired by cineby's popular ranking display.
class TopTenRankingSection extends StatelessWidget {
  final List<_RankingItem> items;
  final String eyebrow;
  final String title;
  final IconData icon;
  final Color accent;

  const TopTenRankingSection({
    super.key,
    required this.items,
    this.eyebrow = 'Trending Today',
    this.title = 'TOP 10 Today',
    this.icon = Icons.leaderboard_rounded,
    this.accent = AppTheme.warmAmber,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);
    final displayItems = items.take(10).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 48 : 20, 32, isDesktop ? 48 : 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShelfSectionHeader(
            eyebrow: eyebrow,
            title: title,
            icon: icon,
            accent: accent,
            count: displayItems.length,
          ),
          const SizedBox(height: 14),
          ...List.generate(displayItems.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < displayItems.length - 1 ? 8 : 0),
              child: _RankingTile(
                rank: i + 1,
                item: displayItems[i],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RankingItem {
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? badge;
  final VoidCallback? onTap;

  const _RankingItem({
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.badge,
    this.onTap,
  });
}

class _RankingTile extends StatefulWidget {
  final int rank;
  final _RankingItem item;

  const _RankingTile({required this.rank, required this.item});

  @override
  State<_RankingTile> createState() => _RankingTileState();
}

class _RankingTileState extends State<_RankingTile> {
  bool _hovered = false;

  Color get _rankColor {
    switch (widget.rank) {
      case 1:
        return const Color(0xFFF0A500);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFBF8040);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = widget.rank <= 3;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (show) => setState(() => _hovered = show),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: ShelfMotion.orZero(ShelfMotion.fast),
          curve: ShelfMotion.easeOutStrong,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF1C1228).withValues(alpha: 0.8)
                : const Color(0xFF1C1228).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTop3
                  ? _rankColor.withValues(alpha: 0.3)
                  : AppTheme.roseQuartz.withValues(alpha: 0.07),
              width: isTop3 ? 1.0 : 0.5,
            ),
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 38,
                child: isTop3
                    ? Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _rankColor.withValues(alpha: 0.15),
                          border: Border.all(
                              color: _rankColor.withValues(alpha: 0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: _rankColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.rank}',
                          style: AppTypography.cormorantBlack.copyWith(fontSize: 18, color: _rankColor),
                        ),
                      )
                    : Center(
                        child: Text(
                          '${widget.rank}',
                            style: AppTypography.outfitMuted.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              // Poster thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 62,
                  child: widget.item.imageUrl.isNotEmpty
                      ? Image.network(widget.item.imageUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                          errorBuilder: (_, _, _) =>
                              Container(color: const Color(0xFF1C1228)))
                      : Container(color: const Color(0xFF1C1228)),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitHeading.copyWith(
                        fontSize: 13,
                      ),
                    ),
                    if (widget.item.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.item.subtitle!,
                      style: AppTypography.outfitBold.copyWith(
                        color: AppTheme.warmAmber,
                        fontSize: 11,
                      ),
                      ),
                    ],
                    if (widget.item.badge != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.deepRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.badge!,
                          style: AppTypography.outfitHeading.copyWith(
                            color: AppTheme.deepRose,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Build ranking items from generic data.
List<_RankingItem> buildRankingItems<T>({
  required List<T> items,
  required String Function(T) getTitle,
  required String Function(T) getImageUrl,
  String? Function(T)? getSubtitle,
  String? Function(T)? getBadge,
  void Function(T)? onTap,
}) {
  return items.map((item) {
    return _RankingItem(
      title: getTitle(item),
      subtitle: getSubtitle?.call(item),
      imageUrl: getImageUrl(item),
      badge: getBadge?.call(item),
      onTap: onTap != null ? () => onTap(item) : null,
    );
  }).toList();
}

// ── Only On (Provider) Section ──────────────────────────────

/// "Only on" provider section — shows content available on specific
/// streaming services (Netflix, Amazon, Disney, HBO, etc.), matching
/// cineby's "Only on" display.
class OnlyOnSection extends StatelessWidget {
  final List<_ProviderRow> providers;

  const OnlyOnSection({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 48 : 20, 32, isDesktop ? 48 : 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShelfSectionHeader(
            eyebrow: 'Streaming Providers',
            title: 'Only on',
            icon: Icons.live_tv_rounded,
            accent: AppTheme.softLavender,
          ),
          const SizedBox(height: 14),
          ...providers.map((provider) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _ProviderRowWidget(
                  provider: provider,
                  isDesktop: isDesktop,
                ),
              )),
        ],
      ),
    );
  }
}

class _ProviderRow {
  final String name;
  final IconData icon;
  final Color color;
  final List<_ProviderItem> items;

  const _ProviderRow({
    required this.name,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _ProviderItem {
  final String id;
  final String title;
  final String imageUrl;
  final VoidCallback? onTap;

  const _ProviderItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.onTap,
  });
}

class _ProviderRowWidget extends StatelessWidget {
  final _ProviderRow provider;
  final bool isDesktop;

  const _ProviderRowWidget({
    required this.provider,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(provider.icon, color: provider.color, size: 18),
            const SizedBox(width: 8),
            Text(
              provider.name,
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 13,
                color: provider.color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: isDesktop ? 200 : 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: provider.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = provider.items[i];
              final cardWidth = (isDesktop ? 130 : 110).toDouble();
              return SizedBox(
                width: cardWidth,
                child: GestureDetector(
                  onTap: item.onTap,
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.imageUrl.isNotEmpty
                              ? Image.network(item.imageUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                  errorBuilder: (_, _, _) => Container(
                                      color: const Color(0xFF1C1228)))
                              : Container(color: const Color(0xFF1C1228)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitMuted.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Build provider row from generic data.
_ProviderRow buildProviderRow<T>({
  required String name,
  required IconData icon,
  required Color color,
  required List<T> items,
  required String Function(T) getId,
  required String Function(T) getTitle,
  required String Function(T) getImageUrl,
  void Function(T)? onTap,
}) {
  return _ProviderRow(
    name: name,
    icon: icon,
    color: color,
    items: items.map((item) {
      return _ProviderItem(
        id: getId(item),
        title: getTitle(item),
        imageUrl: getImageUrl(item),
        onTap: onTap != null ? () => onTap(item) : null,
      );
    }).toList(),
  );
}

// ── Continue Watching (enhanced) ────────────────────────────

/// Enhanced "Continue Watching" row — shows recently-watched items
/// with backdrop images and a gradient overlay, like cineby's
/// continue-watching rail.
class ContinueWatchingRow extends StatelessWidget {
  final List<_ContinueItem> items;
  final String eyebrow;
  final String title;
  final Color accent;

  const ContinueWatchingRow({
    super.key,
    required this.items,
    this.eyebrow = 'Pick Up Where You Left Off',
    this.title = 'Continue Watching',
    this.accent = AppTheme.deepRose,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDesktop = AppBreakpoint.isDesktop(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 48 : 20, 28, isDesktop ? 48 : 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShelfSectionHeader(
            eyebrow: eyebrow,
            title: title,
            icon: Icons.play_circle_outline_rounded,
            accent: accent,
            count: items.length,
            countLabel: 'titles',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                return SizedBox(
                  width: isDesktop ? 280 : 220,
                  child: _ContinueCard(item: item, accent: accent),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueItem {
  final String id;
  final String title;
  final String? year;
  final String imageUrl;
  final String? progressLabel;
  final VoidCallback? onTap;

  const _ContinueItem({
    required this.id,
    required this.title,
    this.year,
    required this.imageUrl,
    this.progressLabel,
    this.onTap,
  });
}

class _ContinueCard extends StatelessWidget {
  final _ContinueItem item;
  final Color accent;

  const _ContinueCard({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.45),
              Colors.black.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.25),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.imageUrl.isNotEmpty)
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, _, _) =>
                      Container(color: const Color(0xFF1C1228)),
                )
              else
                Container(color: const Color(0xFF1C1228)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 0,
                bottom: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.progressLabel ?? 'WATCHED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 15, height: 1.15),
                    ),
                    if (item.year != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.year!,
                        style: AppTypography.outfitBold.copyWith(
                          color: AppTheme.warmAmber,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.replay_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              // Bottom progress bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.45, // ~45% watched as a visual hint
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Build continue-watching items from generic data.
List<_ContinueItem> buildContinueItems<T>({
  required List<T> items,
  required String Function(T) getId,
  required String Function(T) getTitle,
  required String Function(T) getImageUrl,
  String? Function(T)? getYear,
  String? Function(T)? getProgressLabel,
  void Function(T)? onTap,
}) {
  return items.map((item) {
    return _ContinueItem(
      id: getId(item),
      title: getTitle(item),
      year: getYear?.call(item),
      imageUrl: getImageUrl(item),
      progressLabel: getProgressLabel?.call(item),
      onTap: onTap != null ? () => onTap(item) : null,
    );
  }).toList();
}
