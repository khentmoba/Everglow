part of 'upcoming_countdowns.dart';

/// Warm invite shown when no dates are planned yet — a golden calendar
/// tile plus the reason to tap, instead of a bare text row.
class _EmptyDatesCta extends StatelessWidget {
  const _EmptyDatesCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warmAmber.withValues(alpha: 0.14),
            AppColors.warmAmber.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.auroraGold, AppColors.warmAmber],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.warmAmber.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 26,
              color: AppColors.inkDeep,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing on the horizon',
                  style: AppTypography.cormorantBold.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plan the next date together ♥',
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 12,
                    color: AppColors.petalWhite.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SectionChevron(hue: AppColors.warmAmber),
        ],
      ),
    );
  }
}

class _CountdownEventCard extends StatefulWidget {
  final CalendarEvent event;
  final int index;

  const _CountdownEventCard({required this.event, required this.index});

  @override
  State<_CountdownEventCard> createState() => _CountdownEventCardState();
}

class _CountdownEventCardState extends State<_CountdownEventCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final info = calendarEventTypeInfo[widget.event.type] ?? ('📌', '');
    final hue = calendarEventHue(widget.event.type);
    final isImminent = _isImminent(widget.event.date);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.orZero(AppMotion.fast),
        curve: AppMotion.easeOutStrong,
        transform: Matrix4.identity()
          ..translateByDouble(0, _hovered ? -4.0 : 0, 0, 1.0),
        width: 268,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusXl,
          border: Border.all(
            color: _hovered
                ? hue.withValues(alpha: 0.55)
                : hue.withValues(alpha: 0.28),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: hue.withValues(alpha: _hovered ? 0.22 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            if (isImminent)
              BoxShadow(
                color: hue.withValues(alpha: 0.10),
                blurRadius: 32,
                spreadRadius: -8,
              ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      hue.withValues(alpha: 0.24),
                      AppColors.velvet.withValues(alpha: 0.92),
                      AppColors.inkDeep.withValues(alpha: 0.96),
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [hue.withValues(alpha: 0.22), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      hue.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            _WatermarkDays(target: widget.event.date),
            if (isImminent)
              Positioned(
                top: 12,
                right: 12,
                child: _UrgencyPill(target: widget.event.date, hue: hue),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EventBadge(
                        emoji: info.$1,
                        hue: hue,
                        imminent: isImminent,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfitHeading.copyWith(
                                fontSize: 13,
                                letterSpacing: 0.7,
                                height: 1.1,
                                color: AppColors.petalWhite,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.moonlight.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 10,
                                    color: hue.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _eventDateFormat.format(
                                        widget.event.date,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.outfitBold.copyWith(
                                        fontSize: 10,
                                        letterSpacing: 0.3,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.78,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.event.type ==
                                      CalendarEventType.anniversary) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: hue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'ANNIVERSARY',
                                      style: AppTypography.outfitBold.copyWith(
                                        fontSize: 7.5,
                                        letterSpacing: 0.8,
                                        color: hue.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CountdownUnits(target: widget.event.date, hue: hue),
                  const Spacer(),
                  _DashedDivider(hue: hue),
                  const SizedBox(height: 10),
                  _CountdownFooter(target: widget.event.date, hue: hue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isImminent(DateTime d) {
    final hours = d.difference(DateTime.now()).inHours;
    return hours >= 0 && hours < 48;
  }
}

class _WatermarkDays extends StatefulWidget {
  final DateTime target;
  const _WatermarkDays({required this.target});

  @override
  State<_WatermarkDays> createState() => _WatermarkDaysState();
}

class _WatermarkDaysState extends State<_WatermarkDays> {
  Timer? _t;
  int _days = 0;

  @override
  void initState() {
    super.initState();
    _days = _calc();
    _t = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final n = _calc();
      if (n != _days) setState(() => _days = n);
    });
  }

  int _calc() {
    final diff = widget.target.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays;
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 28,
      child: IgnorePointer(
        child: Text(
          '$_days',
          style: AppTypography.cormorantBlackWhite.copyWith(
            fontSize: 78,
            height: 1.0,
            letterSpacing: -4,
            color: AppColors.petalWhite.withValues(alpha: 0.045),
          ),
        ),
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  final String emoji;
  final Color hue;
  final bool imminent;

  const _EventBadge({
    required this.emoji,
    required this.hue,
    required this.imminent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                hue.withValues(alpha: 0.32),
                hue.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: hue.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: hue.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.radiusMd,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.petalWhite.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(child: Text(emoji, style: const TextStyle(fontSize: 19))),
            ],
          ),
        ),
        if (imminent)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: hue,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.inkDeep, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: hue.withValues(alpha: 0.7),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _UrgencyPill extends StatelessWidget {
  final DateTime target;
  final Color hue;
  const _UrgencyPill({required this.target, required this.hue});

  @override
  Widget build(BuildContext context) {
    final diff = target.difference(DateTime.now());
    final days = diff.inDays;
    final label = diff.inHours < 24
        ? (diff.inHours < 1 ? 'NOW' : 'TODAY')
        : days == 1
        ? 'TOMORROW'
        : null;
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [hue, AppColors.blushGold]),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: hue.withValues(alpha: 0.35), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.petalWhite,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              fontSize: 8,
              letterSpacing: 1.0,
              color: AppColors.inkDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownUnits extends StatefulWidget {
  final DateTime target;
  final Color hue;

  const _CountdownUnits({required this.target, required this.hue});

  @override
  State<_CountdownUnits> createState() => _CountdownUnitsState();
}

class _CountdownUnitsState extends State<_CountdownUnits> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _remaining = _remainingFor(widget.target);
    _schedule();
  }

  @override
  void didUpdateWidget(_CountdownUnits oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _timer?.cancel();
      _remaining = _remainingFor(widget.target);
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _remainingFor(DateTime target) {
    final now = DateTime.now();
    return target.isAfter(now) ? target.difference(now) : Duration.zero;
  }

  void _schedule() {
    _timer?.cancel();
    final close = _remaining.inHours < 24;
    _timer = Timer.periodic(
      close ? const Duration(seconds: 1) : const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        final next = _remainingFor(widget.target);
        if (next != _remaining) {
          setState(() => _remaining = next);
          _schedule();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final showSeconds = _remaining.inHours < 24 && _remaining > Duration.zero;

    return Row(
      children: [
        _TimeCapsule(
          value: days,
          label: 'days',
          hue: widget.hue,
          emphasized: true,
        ),
        _TickSeparator(hue: widget.hue),
        _TimeCapsule(value: hours, label: 'hrs', hue: widget.hue),
        _TickSeparator(hue: widget.hue),
        _TimeCapsule(value: minutes, label: 'min', hue: widget.hue),
        if (showSeconds) ...[
          _TickSeparator(hue: widget.hue),
          _TimeCapsule(
            value: seconds,
            label: 'sec',
            hue: widget.hue,
            live: true,
          ),
        ],
      ],
    );
  }
}
