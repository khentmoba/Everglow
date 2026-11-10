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
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onChanged(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: audio == a
                        ? AnimeXTokens.accent
                        : Colors.transparent,
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
            ),
        ],
      ),
    );
  }
}

/// Small on/off pill for a playback preference (Auto next, Skip intro).
/// Tappable as a whole so it works with a thumb on a phone.
class _PrefToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: value
                  ? AnimeXTokens.accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AnimeXTokens.radiusSm),
              border: Border.all(
                color: value
                    ? AnimeXTokens.accent.withValues(alpha: 0.45)
                    : AnimeXTokens.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value ? Icons.check_rounded : Icons.remove_rounded,
                  size: 13,
                  color: value
                      ? AnimeXTokens.accentWarm
                      : AnimeXTokens.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: dmSansStyle(
                    size: 12,
                    color: value
                        ? AnimeXTokens.accentWarm
                        : AnimeXTokens.textSecondary,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              weight: FontWeight.w600,
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
  final IconData? icon;

  const _EpisodeStepButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: enabled
                      ? AnimeXTokens.accentWarm
                      : AnimeXTokens.textMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: dmSansStyle(
                  size: 12,
                  color: enabled
                      ? (icon != null
                            ? AnimeXTokens.accentWarm
                            : AnimeXTokens.textPrimary)
                      : AnimeXTokens.textMuted,
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
