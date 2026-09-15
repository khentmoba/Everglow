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
        return AppColors.warmAmber;
      case 2:
        return AppColors.rankSilver;
      case 3:
        return AppColors.rankBronze;
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
                    ? AppNetworkImage(
                        imageUrl: item.coverUrl,
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
                              AppNetworkImage(
                                imageUrl: item.coverUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                                errorWidget: Container(color: _cCard),
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

/// Tune button next to the search box. Glows amber while advanced
/// filters are active so Clair can see at a glance that the list
/// is narrowed.
class _AdvancedButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _AdvancedButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Tooltip(
        message: 'Advanced search',
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: active
                ? _cAmber.withValues(alpha: 0.18)
                : _cCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? _cAmber.withValues(alpha: 0.5)
                  : _cRose.withValues(alpha: 0.15),
            ),
          ),
          child: Icon(
            Icons.tune_rounded,
            color: active ? _cAmber : _cDeepRose,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Z-Lib style "Load more" footer for the paged result list.
class _LoadMoreRow extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoadMoreRow({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: loading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _cDeepRose.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cDeepRose.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: _cDeepRose,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Load more results',
                  style: AppTypography.outfitBold.copyWith(
                    color: _cDeepRose,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}

