part of 'watch_party_screen_web.dart';

class _CinemaPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;
  final bool accent;
  final VoidCallback onTap;

  const _CinemaPillButton({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.deepRose : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.deepRose.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: accent
                ? AppColors.deepRose.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.outfitHeading.copyWith(
                  color: color,
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WatchPartyCinematicLoader extends StatefulWidget {
  final String serverName;

  const _WatchPartyCinematicLoader({required this.serverName});

  @override
  State<_WatchPartyCinematicLoader> createState() =>
      _WatchPartyCinematicLoaderState();
}

class _WatchPartyCinematicLoaderState extends State<_WatchPartyCinematicLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (AppTheme.shouldReduceMotion) {
      _controller.value = 0.5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: AppColors.inkDeep.withValues(alpha: 0.96),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.8 + _controller.value * 0.5,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.deepRose.withValues(
                                  alpha: (1 - _controller.value) * 0.45,
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.velvet, AppColors.deepRose],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.deepRose.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.petalWhite,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Fetching Media',
                    style: AppTypography.cormorantBoldWhite.copyWith(
                      fontSize: 22,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trying streaming servers...',
                    style: AppTypography.outfitWhite.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.moonlight.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.blushGold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.serverName,
                          style: AppTypography.outfitHeading.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Trying...',
                          style: AppTypography.outfitWhite.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
