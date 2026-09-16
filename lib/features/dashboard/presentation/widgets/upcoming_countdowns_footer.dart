part of 'upcoming_countdowns.dart';

class _TimeCapsule extends StatelessWidget {
  final int value;
  final String label;
  final Color hue;
  final bool emphasized;
  final bool live;

  const _TimeCapsule({
    required this.value,
    required this.label,
    required this.hue,
    this.emphasized = false,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: emphasized
              ? AppColors.petalWhite.withValues(alpha: 0.08)
              : hue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: emphasized
                ? AppColors.petalWhite.withValues(alpha: 0.14)
                : hue.withValues(alpha: 0.22),
          ),
          boxShadow: emphasized
              ? [
                  BoxShadow(
                    color: hue.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            if (emphasized)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.petalWhite.withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Column(
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.orZero(const Duration(milliseconds: 280)),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim.drive(
                      CurveTween(curve: AppMotion.easeOutStrong),
                    ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    key: ValueKey(value),
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: emphasized ? 17 : 15.5,
                      height: 1.0,
                      letterSpacing: -0.5,
                      color: live
                          ? hue
                          : emphasized
                          ? AppColors.petalWhite
                          : AppColors.petalWhite.withValues(alpha: 0.92),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 7.5,
                    letterSpacing: 1.3,
                    color: emphasized
                        ? AppColors.blushGold
                        : hue.withValues(alpha: 0.85),
                  ),
                ),
                if (live) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 16,
                    height: 2,
                    decoration: BoxDecoration(
                      color: hue.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TickSeparator extends StatefulWidget {
  final Color hue;
  const _TickSeparator({required this.hue});

  @override
  State<_TickSeparator> createState() => _TickSeparatorState();
}

class _TickSeparatorState extends State<_TickSeparator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      child: FadeTransition(
        opacity: _c.drive(Tween(begin: 0.25, end: 0.85)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: widget.hue.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: widget.hue.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color hue;
  const _DashedDivider({required this.hue});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        const dash = 6.0;
        const gap = 4.0;
        final count = (w / (dash + gap)).floor();
        return Row(
          children: List.generate(count, (i) {
            final isEdge = i == 0 || i == count - 1;
            return Expanded(
              child: Container(
                height: 1,
                margin: EdgeInsets.only(right: i == count - 1 ? 0 : gap),
                decoration: BoxDecoration(
                  color: isEdge
                      ? Colors.transparent
                      : AppColors.moonlight.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: isEdge
                    ? null
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              hue.withValues(alpha: 0.0),
                              hue.withValues(alpha: 0.18),
                              hue.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CountdownFooter extends StatelessWidget {
  final DateTime target;
  final Color hue;

  const _CountdownFooter({required this.target, required this.hue});

  @override
  Widget build(BuildContext context) {
    return _CountdownFooterBody(target: target, hue: hue);
  }
}

// Minute-granularity footer: the progress fraction and "X days to go"
// label cannot move within a minute, so rebuilding on every parent
// frame (or every second from _CountdownUnits above) is wasted layout.
// This wrapper ticks at minute boundaries only.
class _CountdownFooterBody extends StatefulWidget {
  final DateTime target;
  final Color hue;

  const _CountdownFooterBody({required this.target, required this.hue});

  @override
  State<_CountdownFooterBody> createState() => _CountdownFooterBodyState();
}

class _CountdownFooterBodyState extends State<_CountdownFooterBody> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final toNextMinute = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(toNextMinute, _tickMinute);
  }

  void _tickMinute() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _timer = Timer(const Duration(minutes: 1), _tickMinute);
  }

  @override
  void didUpdateWidget(_CountdownFooterBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final target = widget.target;
    final hue = widget.hue;
    final remaining = target.isAfter(now)
        ? target.difference(now)
        : Duration.zero;
    const window = Duration(days: 60);
    final fraction = (1 - remaining.inMilliseconds / window.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final daysLeft = remaining.inDays;
    final hoursLeft = remaining.inHours % 24;
    final label = daysLeft == 0
        ? (remaining.inHours == 0
              ? '${remaining.inMinutes}m to go'
              : '${remaining.inHours}h ${hoursLeft > 0 ? "" : ""}to go')
        : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} to go';
    final isSoon = daysLeft <= 1;

    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.moonlight.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.moonlight.withValues(alpha: 0.06),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSoon
                          ? [hue, AppColors.auroraRose]
                          : [hue, AppColors.blushGold],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: hue.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 1),
                      decoration: BoxDecoration(
                        color: AppColors.petalWhite.withValues(alpha: 0.95),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: hue.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: isSoon
                ? hue.withValues(alpha: 0.16)
                : hue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (isSoon ? hue : hue).withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSoon ? Icons.bolt_rounded : Icons.hourglass_bottom_rounded,
                size: 11,
                color: isSoon ? hue : hue.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.2,
                  color: isSoon ? hue : hue.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
