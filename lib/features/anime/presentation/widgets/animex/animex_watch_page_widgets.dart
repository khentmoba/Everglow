part of 'animex_watch_page.dart';

class _AudioToggle extends StatelessWidget {
  final String audio;
  final ValueChanged<String> onChanged;

  const _AudioToggle({required this.audio, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
        border: Border.all(color: AnimeXTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in ['sub', 'dub'])
            GestureDetector(
              onTap: () => onChanged(a),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: audio == a ? AnimeXTokens.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
                ),
                child: Text(
                  a == 'sub' ? 'SUB' : 'DUB',
                  style: dmSansStyle(
                    size: 11.5,
                    color: audio == a
                        ? Colors.white
                        : AnimeXTokens.textSecondary,
                    weight: FontWeight.w700,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: dmSansStyle(
              size: 10.5,
              color: AnimeXTokens.textMuted,
              weight: FontWeight.w700,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: dmSansStyle(
              size: 13,
              color: AnimeXTokens.textPrimary,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeStepButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _EpisodeStepButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
          border: Border.all(
            color: enabled ? AnimeXTokens.borderStrong : AnimeXTokens.border,
          ),
        ),
        child: Text(
          label,
          style: dmSansStyle(
            size: 12,
            color: enabled ? AnimeXTokens.textPrimary : AnimeXTokens.textMuted,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
