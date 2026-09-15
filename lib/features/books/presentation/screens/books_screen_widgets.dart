part of 'books_screen.dart';

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


/// One number + label bit in the home stats strip.
class _StatBit extends StatelessWidget {
  final String value;
  final String label;
  const _StatBit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.cormorantBlack.copyWith(
            fontSize: 22,
            color: _cWhite,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.outfitHeading.copyWith(
            fontSize: 9,
            color: _cMuted,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
