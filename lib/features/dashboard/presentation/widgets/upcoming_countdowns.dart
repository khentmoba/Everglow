import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_typography.dart';

import '../../../calendar/data/services/calendar_service.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../../../calendar/presentation/widgets/calendar_event_style.dart';
import 'feature_section.dart';

/// Dashboard section showing upcoming calendar events as countdown cards.
class UpcomingCountdowns extends StatelessWidget {
  final CalendarService _calendarService = CalendarService();

  UpcomingCountdowns({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _calendarService.getUpcomingEvents(days: 60),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        final displayEvents = events.take(3).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.event_rounded,
            hue: AppColors.warmAmber,
            title: 'Coming Up',
            subtitle: displayEvents.isEmpty
                ? 'no dates planned yet'
                : '${displayEvents.length} upcoming '
                      '${displayEvents.length == 1 ? 'date' : 'dates'}',
            trailing: TextButton(
              onPressed: () => context.push('/calendar'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: AppColors.blushGold,
              ),
              child: Text(
                'Calendar',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.blushGold,
                ),
              ),
            ),
            onTap: () => context.push('/calendar'),
            child: displayEvents.isEmpty
                ? Row(
                    children: [
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.warmAmber,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tap to add the next special date',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SectionChevron(hue: AppColors.warmAmber),
                    ],
                  )
                : SizedBox(
                    height: 158,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayEvents.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _CountdownEventCard(event: displayEvents[index]);
                      },
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _CountdownEventCard extends StatelessWidget {
  final CalendarEvent event;

  const _CountdownEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final info = calendarEventTypeInfo[event.type] ?? ('gift', '');
    final hue = calendarEventHue(event.type);

    return Container(
      width: 232,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hue.withValues(alpha: 0.18),
            AppColors.inkDeep.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: hue.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EventEmoji(emoji: info.$1, hue: hue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.petalWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: hue.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('EEE, MMM d').format(event.date),
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 10.5,
                            color: AppColors.petalWhite.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CountdownUnits(target: event.date, hue: hue),
          const SizedBox(height: 12),
          _CountdownFooter(target: event.date, hue: hue),
        ],
      ),
    );
  }
}

class _EventEmoji extends StatelessWidget {
  final String emoji;
  final Color hue;

  const _EventEmoji({required this.emoji, required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hue.withValues(alpha: 0.30), hue.withValues(alpha: 0.08)],
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
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

    return Row(
      children: [
        _CountdownUnit(value: days, label: 'days', hue: widget.hue),
        const SizedBox(width: 8),
        _CountdownUnit(value: hours, label: 'hrs', hue: widget.hue),
        const SizedBox(width: 8),
        _CountdownUnit(value: minutes, label: 'min', hue: widget.hue),
      ],
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final int value;
  final String label;
  final Color hue;

  const _CountdownUnit({
    required this.value,
    required this.label,
    required this.hue,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: hue.withValues(alpha: 0.10),
          borderRadius: AppRadius.radiusSm,
          border: Border.all(color: hue.withValues(alpha: 0.26)),
        ),
        child: Column(
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: AppTypography.outfitHeading.copyWith(
                fontSize: 15,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: AppTypography.outfitBold.copyWith(
                fontSize: 8,
                letterSpacing: 1.4,
                color: hue.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownFooter extends StatelessWidget {
  final DateTime target;
  final Color hue;

  const _CountdownFooter({required this.target, required this.hue});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = target.isAfter(now)
        ? target.difference(now)
        : Duration.zero;
    const window = Duration(days: 60);
    final fraction = (1 - remaining.inMilliseconds / window.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final daysLeft = remaining.inDays;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.radiusFull,
            child: Container(
              height: 4,
              color: AppColors.moonlight.withValues(alpha: 0.12),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [hue, AppColors.blushGold],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} to go',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 10,
            letterSpacing: 0.3,
            color: hue.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
