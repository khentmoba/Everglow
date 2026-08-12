import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/shared/widgets/everglow/everglow_background.dart';
import 'package:everglow/shared/widgets/everglow/everglow_feature_header.dart';

import '../../data/services/calendar_service.dart';
import '../../domain/models/calendar_event.dart';
import '../widgets/add_event_dialog.dart';
import '../widgets/calendar_event_style.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/day_detail_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  late final Stream<List<CalendarEvent>> _monthEventsStream;
  late final Stream<List<CalendarEvent>> _upcomingStream;

  DateTime _selectedDay = DateTime.now();
  final DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _monthEventsStream = _calendarService.getEventsForMonth(_currentMonth);
    _upcomingStream = _calendarService.getUpcomingEvents(days: 60);
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
    _openDaySheet(day);
  }

  void _openDaySheet(DateTime day) {
    // Soft scrim keeps the calendar visible behind the day sheet.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => DayDetailSheet(day: day, onEventAdded: _refresh),
    );
  }

  void _refresh() {
    setState(() {});
  }

  Future<void> _openAddEvent() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AddEventDialog(selectedDay: _selectedDay),
    );
    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: const [
                RadialGlow(
                  color: AppColors.warmAmber,
                  alignment: Alignment(-0.7, -0.9),
                  size: 0.9,
                  opacity: 0.12,
                ),
                RadialGlow(
                  color: AppColors.softLavender,
                  alignment: Alignment(0.9, 0.8),
                  size: 0.7,
                  opacity: 0.10,
                ),
              ],
              showPetals: true,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const EverglowFeatureHeader(
                  title: 'Shared Calendar',
                  subtitle: 'our special dates',
                  icon: Icons.calendar_month_rounded,
                  hue: AppColors.warmAmber,
                  actions: [_CalendarRefreshButton()],
                ),
                Expanded(
                  child: StreamBuilder<List<CalendarEvent>>(
                    stream: _monthEventsStream,
                    builder: (context, snapshot) {
                      final events = snapshot.data ?? [];
                      return Column(
                        children: [
                          CalendarGrid(
                            initialMonth: _currentMonth,
                            events: events,
                            selectedDay: _selectedDay,
                            onDaySelected: _onDaySelected,
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: StreamBuilder<List<CalendarEvent>>(
                              stream: _upcomingStream,
                              builder: (context, snapshot) {
                                final upcoming = snapshot.data ?? [];
                                return Column(
                                  children: [
                                    _buildUpcomingHeader(count: upcoming.length),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: upcoming.isEmpty
                                          ? _buildEmptyState()
                                          : ListView.builder(
                                              padding: const EdgeInsets.fromLTRB(
                                                16,
                                                2,
                                                16,
                                                96,
                                              ),
                                              itemCount: upcoming.length.clamp(
                                                0,
                                                10,
                                              ),
                                              itemBuilder: (context, index) {
                                                final event = upcoming[index];
                                                return _UpcomingEventCard(
                                                  event: event,
                                                  onTap: () =>
                                                      _openDaySheet(event.date),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _CalendarFab(onPressed: _openAddEvent),
    );
  }

  Widget _buildUpcomingHeader({required int count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppTheme.roseGoldGradient,
              borderRadius: AppRadius.radiusFull,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Upcoming',
            style: AppTypography.titleLarge().copyWith(
              fontSize: 18,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.auroraRose.withValues(alpha: 0.14),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: AppColors.auroraRose.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$count',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 11,
                  color: AppColors.auroraRose,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.moonlight.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.moonlight.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              Icons.event_busy_rounded,
              color: AppColors.textDisabled,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No upcoming events',
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 13,
              color: AppColors.petalWhite.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _openAddEvent,
            icon: const Icon(
              Icons.add_rounded,
              size: 16,
              color: AppColors.blushGold,
            ),
            label: Text(
              'Plan the next date',
              style: AppTypography.outfitBold.copyWith(
                fontSize: 11.5,
                color: AppColors.blushGold,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.blushGold,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _UpcomingEventCard({required this.event, required this.onTap});

  @override
  State<_UpcomingEventCard> createState() => _UpcomingEventCardState();
}

class _UpcomingEventCardState extends State<_UpcomingEventCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final info = calendarEventTypeInfo[event.type] ?? ('gift', '');
    final hue = calendarEventHue(event.type);
    final dayDiff = event.date.difference(DateTime.now()).inDays;
    final timeLabel = dayDiff == 0
        ? 'Today'
        : dayDiff == 1
        ? 'Tomorrow'
        : 'In $dayDiff days';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.moonlight.withValues(alpha: 0.10),
                  AppColors.inkDeep.withValues(alpha: 0.55),
                ],
              ),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: _hovered
                    ? hue.withValues(alpha: 0.5)
                    : hue.withValues(alpha: 0.2),
              ),
              boxShadow: [
                if (_hovered)
                  BoxShadow(
                    color: hue.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Row(
              children: [
                _EventEmojiChip(emoji: info.$1, hue: hue),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 3),
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
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hue.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              info.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 10,
                                letterSpacing: 0.3,
                                color: hue.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _TimePill(label: timeLabel, hue: hue),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hue.withValues(alpha: 0.10),
                    border: Border.all(color: hue.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: hue,
                    size: 16,
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

class _EventEmojiChip extends StatelessWidget {
  final String emoji;
  final Color hue;

  const _EventEmojiChip({required this.emoji, required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hue.withValues(alpha: 0.26), hue.withValues(alpha: 0.08)],
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final Color hue;

  const _TimePill({required this.label, required this.hue});

  @override
  Widget build(BuildContext context) {
    final isToday = label == 'Today';
    final fill = isToday ? AppColors.deepRose : hue;
    final edge = isToday ? AppColors.auroraRose : hue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.16),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: edge.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.outfitBold.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.2,
          color: edge,
        ),
      ),
    );
  }
}

class _CalendarRefreshButton extends StatefulWidget {
  const _CalendarRefreshButton();

  @override
  State<_CalendarRefreshButton> createState() => _CalendarRefreshButtonState();
}

class _CalendarRefreshButtonState extends State<_CalendarRefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          curve: AppMotion.easeOutStrong,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.moonlight.withValues(
              alpha: _hovered ? 0.16 : 0.08,
            ),
            border: Border.all(
              color: _hovered
                  ? AppColors.blushGold.withValues(alpha: 0.5)
                  : AppColors.moonlight.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            Icons.refresh_rounded,
            color: AppColors.blushGold,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _CalendarFab extends StatefulWidget {
  final VoidCallback onPressed;

  const _CalendarFab({required this.onPressed});

  @override
  State<_CalendarFab> createState() => _CalendarFabState();
}

class _CalendarFabState extends State<_CalendarFab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add an event',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..scaleByDouble(
                _hovered ? 1.08 : 1.0,
                _hovered ? 1.08 : 1.0,
                _hovered ? 1.08 : 1.0,
                1.0,
              ),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.roseGoldGradient,
              border: Border.all(
                color: AppColors.petalWhite.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.petalWhite,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
