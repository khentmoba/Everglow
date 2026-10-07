part of 'video_player_screen_web.dart';

/// Show name only for the player chrome. Routes used to carry
/// `Show: Episode 3` in the title while the S/E badge below said it
/// again — strip any trailing episode suffix so the badge is the single
/// episode label. Iterates because a title can stack suffixes
/// (`Show Episode 3 Episode 3`).
String _playerDisplayTitle(String raw) {
  var title = raw.trim();
  if (title.isEmpty) return title;
  final suffixes = [
    RegExp(r'\s*[:|–—-]\s*S\d+\s*E\d+.*$', caseSensitive: false),
    RegExp(r'\s*[:|–—-]\s*E\d+.*$', caseSensitive: false),
    RegExp(r'\s*[:|–—-]\s*Episode\s*\d+.*$', caseSensitive: false),
    RegExp(r'\s+S\d+\s*E\d+\s*$', caseSensitive: false),
    RegExp(r'\s+E\d+\s*$', caseSensitive: false),
    RegExp(r'\s+Episode\s*\d+\s*$', caseSensitive: false),
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final pattern in suffixes) {
      final next = title.replaceAll(pattern, '').trim();
      if (next.isNotEmpty && next != title) {
        title = next;
        changed = true;
      }
    }
  }
  return title.isEmpty ? raw.trim() : title;
}

class _PlayerPillButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  const _PlayerPillButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.compact = false,
  });

  @override
  State<_PlayerPillButton> createState() => _PlayerPillButtonState();
}

class _PlayerPillButtonState extends State<_PlayerPillButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hovered ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: AppTypography.outfitHeading.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
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

/// Compact square glass icon button for the player chrome.
class _PlayerIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  const _PlayerIconButton({
    required this.icon,
    this.onTap,
    this.compact = false,
  });

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: widget.compact ? 30 : 32,
            height: widget.compact ? 30 : 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _hovered ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: Icon(
              widget.icon,
              color: _hovered ? Colors.white : Colors.white70,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live status dot with a soft pulse for the server selector card.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (AppTheme.shouldReduceMotion) {
      _controller.value = 0.35;
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + _pulse.value * 1.6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NetflixColors.accent.withValues(
                      alpha: (1 - _pulse.value) * 0.35,
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: NetflixColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cinematic buffering state shown over the video area while the embed
/// loads. Purely visual; pointer events pass through it.
class _CinematicLoader extends StatefulWidget {
  final String providerName;

  const _CinematicLoader({required this.providerName});

  @override
  State<_CinematicLoader> createState() => _CinematicLoaderState();
}

class _CinematicLoaderState extends State<_CinematicLoader>
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
        color: NetflixColors.background.withValues(alpha: 0.96),
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
                                color: NetflixColors.accent.withValues(
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
                          decoration: const BoxDecoration(
                            color: NetflixColors.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.movie_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Preparing your stream',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'via ${widget.providerName}',
                    style: AppTypography.outfitMuted.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Container(
                      width: 140,
                      height: 3,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: Align(
                        alignment: Alignment(_controller.value * 2 - 1, 0),
                        child: Container(
                          width: 52,
                          height: 3,
                          color: NetflixColors.accent,
                        ),
                      ),
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
