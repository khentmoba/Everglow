part of 'book_detail_screen.dart';

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _TopIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? _cDeepRose.withValues(alpha: 0.25)
              : _cCard.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? _cDeepRose : _cRose.withValues(alpha: 0.12),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: active ? _cDeepRose : _cRose, size: 18),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dim = enabled ? 1.0 : 0.3;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: dim,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Opacity(
            opacity: dim,
            child: Text(
              label,
              style: AppTypography.outfitHeading.copyWith(
                color: _cRose,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final int count;

  _TabHeaderDelegate({required this.controller, required this.count});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: _cBlack,
      child: TabBar(
        controller: controller,
        indicatorColor: _cDeepRose,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorWeight: 2.5,
        labelColor: _cWhite,
        unselectedLabelColor: _cMuted,
        labelStyle: AppTypography.outfitBold.copyWith(fontSize: 11.5),
        unselectedLabelStyle: AppTypography.outfitWhite.copyWith(
          fontSize: 11.5,
        ),
        tabs: const [
          Tab(text: 'Downloads'),
          Tab(text: 'Details'),
          Tab(text: 'Similar'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _DownloadSheet extends StatelessWidget {
  final BookSearchResult? result;
  final BookItem item;

  const _DownloadSheet({required this.result, required this.item});

  @override
  Widget build(BuildContext context) {
    final downloads = <String, String>{...?(result?.downloadUrls)};
    if (downloads.isEmpty && item.iaId.isNotEmpty) {
      downloads['epub'] =
          'https://archive.org/download/${item.iaId}/${item.iaId}.epub';
    }
    final entries = downloads.entries.toList();
    return Container(
      decoration: const BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _cRose.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Download',
            style: AppTypography.cormorantBlack.copyWith(
              fontSize: 24,
              color: _cWhite,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Public-domain formats',
            style: AppTypography.outfitWhite.copyWith(
              color: _cMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text(
              'No downloadable file available for this title.',
              style: TextStyle(color: _cMuted, fontSize: 13),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _cDeepRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.key.toUpperCase(),
                        style: AppTypography.outfitBold.copyWith(
                          color: _cDeepRose,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${entry.key.toUpperCase()} file',
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cWhite,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => downloadUrl(entry.value),
                      style: TextButton.styleFrom(
                        backgroundColor: _cDeepRose,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Download'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
