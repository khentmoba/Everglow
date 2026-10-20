part of 'book_detail_screen.dart';

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _cCard.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: _cRose.withValues(alpha: 0.12)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: _cRose, size: 18),
        ),
      ),
    );
  }
}

/// Round icon with a label under it, like the My List / Rate / Share
/// row on a Netflix title page. Fills rose when switched on.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: active
                      ? _cDeepRose.withValues(alpha: 0.22)
                      : _cCard.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active
                        ? _cDeepRose.withValues(alpha: 0.7)
                        : _cRose.withValues(alpha: 0.15),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: active ? AppColors.auroraRose : _cRose,
                  size: 21,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitWhite.copyWith(
                  color: active ? _cWhite : _cMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadSheet extends StatelessWidget {
  final List<MapEntry<String, String>> entries;
  final String sourceLabel;
  final Future<void> Function(String format, String url) onDownload;

  const _DownloadSheet({
    required this.entries,
    required this.sourceLabel,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
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
              'Free public-domain files from $sourceLabel',
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _cDeepRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.key.toUpperCase(),
                        style: AppTypography.outfitBold.copyWith(
                          color: AppColors.auroraRose,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry == entries.first
                            ? '${entry.key.toUpperCase()} · best for reading'
                            : '${entry.key.toUpperCase()} file',
                        style: AppTypography.outfitWhite.copyWith(
                          color: _cWhite,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Download ${entry.key.toUpperCase()}',
                      onPressed: () {
                        onDownload(entry.key, entry.value);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.download_rounded),
                      color: _cWhite,
                      style: IconButton.styleFrom(backgroundColor: _cDeepRose),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
