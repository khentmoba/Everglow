part of 'books_screen.dart';

class _RankingTile extends StatelessWidget {
  final BookItem item;
  final int rank;
  final VoidCallback onTap;
  const _RankingTile({
    required this.item,
    required this.rank,
    required this.onTap,
  });
  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFF0A500);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFBF8040);
      default:
        return _cMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTop3
                ? _rankColor.withValues(alpha: 0.3)
                : _cRose.withValues(alpha: 0.07),
            width: isTop3 ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          children: [
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
                          color: _rankColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _rankColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: AppTypography.cormorantBlack.copyWith(
                          fontSize: 18,
                          color: _rankColor,
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        '$rank',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 14,
                          color: _cMuted,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 62,
                child: item.coverUrl.isNotEmpty
                    ? Image.network(
                        item.coverUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 120,
                      )
                    : Container(color: _cCard),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitHeading.copyWith(
                      color: _cWhite,
                      fontSize: 13,
                    ),
                  ),
                  if (item.author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        color: _cMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (item.year.isNotEmpty) ...[
                        Text(
                          item.year,
                          style: AppTypography.outfitBold.copyWith(
                            color: _cGold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _cDeepRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'BOOK',
                          style: AppTypography.outfitWhite.copyWith(
                            color: _cDeepRose,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _cMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  const _RowAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.3,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueReadingRail extends StatelessWidget {
  final List<BookItem> items;
  final ValueChanged<BookItem> onOpen;

  const _ContinueReadingRail({required this.items, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final recent = items.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShelfSectionHeader(
            eyebrow: 'Open That Book Again',
            title: 'Continue Reading',
            icon: Icons.menu_book_rounded,
            accent: _cAmber,
            count: 8,
            countLabel: 'titles',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = recent[i];
                return SizedBox(
                  width: 220,
                  child: GestureDetector(
                    onTap: () => onOpen(item),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: _cAmber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (item.coverUrl.isNotEmpty)
                              Image.network(
                                item.coverUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                                errorBuilder: (_, _, _) =>
                                    Container(color: _cCard),
                              )
                            else
                              Container(color: _cCard),
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
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _cAmber,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'READ',
                                      style: TextStyle(
                                        color: Colors.black,
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
                                    style: AppTypography.cormorantBold.copyWith(
                                      fontSize: 15,
                                      height: 1.15,
                                      color: _cWhite,
                                    ),
                                  ),
                                  if (item.author.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'by ${item.author}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.outfitWhite.copyWith(
                                        color: _cRose.withValues(alpha: 0.85),
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
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
                                  color: _cAmber.withValues(alpha: 0.9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cAmber.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.replay_rounded,
                                  color: Colors.black,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _compactCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class _BookResultRow extends StatelessWidget {
  final BookSearchResult result;
  final VoidCallback onOpen;
  final VoidCallback? onListen;
  final VoidCallback? onRead;
  final VoidCallback? onDownload;
  final VoidCallback onShare;
  final VoidCallback onSave;

  const _BookResultRow({
    required this.result,
    required this.onOpen,
    required this.onListen,
    required this.onRead,
    required this.onDownload,
    required this.onShare,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onOpen();
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cCard.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cRose.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 58,
                  height: 82,
                  child: result.coverUrl.isNotEmpty
                      ? Image.network(
                          result.coverUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          errorBuilder: (_, _, _) => Container(color: _cBlack),
                        )
                      : Container(
                          color: _cBlack,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: _cMuted,
                            size: 22,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitBold.copyWith(
                        color: _cWhite,
                        fontSize: 13.5,
                        height: 1.2,
                      ),
                    ),
                    if (result.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (result.metaLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cGold.withValues(alpha: 0.85),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                    if (result.hasRating) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(
                              i <= result.rating!.round()
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: _cGold,
                              size: 13,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            result.rating!.toStringAsFixed(1),
                            style: AppTypography.outfitBold.copyWith(
                              color: _cMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ] else if (result.ratingCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_compactCount(result.ratingCount!)} downloads',
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _RowAction(
                          icon: Icons.headphones_rounded,
                          tooltip: 'Listen',
                          color: _cAmber,
                          onTap: onListen,
                        ),
                        _RowAction(
                          icon: Icons.auto_stories_rounded,
                          tooltip: 'Read',
                          color: _cDeepRose,
                          onTap: onRead,
                        ),
                        _RowAction(
                          icon: Icons.download_rounded,
                          tooltip: 'Download',
                          color: const Color(0xFF2E7D32),
                          onTap: onDownload,
                        ),
                        _RowAction(
                          icon: Icons.share_rounded,
                          tooltip: 'Share',
                          color: const Color(0xFF1976D2),
                          onTap: onShare,
                        ),
                        _RowAction(
                          icon: Icons.bookmark_border_rounded,
                          tooltip: 'Save',
                          color: const Color(0xFF7B1FA2),
                          onTap: onSave,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
