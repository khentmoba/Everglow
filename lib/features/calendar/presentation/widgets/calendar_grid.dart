import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

import '../../domain/models/calendar_event.dart';
import 'calendar_event_style.dart';

class CalendarGrid extends StatefulWidget {
  final DateTime initialMonth;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onMonthChanged;

  const CalendarGrid({
    super.key,
    required this.initialMonth,
    required this.events,
    required this.onDaySelected,
    this.selectedDay,
    this.onMonthChanged,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  static const List<String> _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late DateTime _currentMonth;
  int? _hoveredDay;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
    );
  }

  void _previousMonth() {
    setState(() {
      _hoveredDay = null;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    widget.onMonthChanged?.call(_currentMonth);
  }

  void _nextMonth() {
    setState(() {
      _hoveredDay = null;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    widget.onMonthChanged?.call(_currentMonth);
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _hoveredDay = null;
      _currentMonth = DateTime(now.year, now.month);
    });
    widget.onMonthChanged?.call(_currentMonth);
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  bool _isSelected(DateTime day) {
    final sel = widget.selectedDay;
    if (sel == null) return false;
    return day.year == sel.year && day.month == sel.month && day.day == sel.day;
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    return widget.events
        .where(
          (e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstDayWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday;
    // Mon=1 ... Sun=7. We want Mon first: already correct.
    final leadingEmptyDays = firstDayWeekday - 1;
    final totalCells = leadingEmptyDays + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.moonlight.withValues(alpha: 0.09),
              AppColors.inkDeep.withValues(alpha: 0.50),
            ],
          ),
          borderRadius: AppRadius.radiusX2,
          border: Border.all(
            color: AppColors.moonlight.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          child: Column(
            children: [
              _buildMonthHeader(),
              const SizedBox(height: 10),
              _buildWeekdayHeader(),
              const SizedBox(height: 6),
              _buildDayGrid(
                daysInMonth: daysInMonth,
                leadingEmptyDays: leadingEmptyDays,
                rows: rows,
              ),
              const SizedBox(height: 10),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final now = DateTime.now();
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;
    final count = widget.events.length;

    return Row(
      children: [
        _NavButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous month',
          onTap: _previousMonth,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${_monthNames[_currentMonth.month]} ${_currentMonth.year}',
                style: AppTypography.cormorantBold.copyWith(
                  fontSize: 20,
                  height: 1.0,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: isCurrentMonth ? null : _goToToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blushGold.withValues(alpha: 0.12),
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    isCurrentMonth
                        ? '$count special ${count == 1 ? 'date' : 'dates'}'
                        : 'Back to today',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 9.5,
                      letterSpacing: 0.5,
                      color: AppColors.blushGold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _NavButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next month',
          onTap: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    return Row(
      children: List.generate(7, (index) {
        final isWeekend = index >= 5;
        return Expanded(
          child: Center(
            child: Text(
              _weekdays[index].toUpperCase(),
              style: AppTypography.outfitBold.copyWith(
                fontSize: 9,
                letterSpacing: 1.3,
                color: isWeekend
                    ? AppColors.blushGold.withValues(alpha: 0.75)
                    : AppColors.petalWhite.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayGrid({
    required int daysInMonth,
    required int leadingEmptyDays,
    required int rows,
  }) {
    return Column(
      children: List.generate(rows, (rowIndex) {
        return Row(
          children: List.generate(7, (colIndex) {
            final cellIndex = rowIndex * 7 + colIndex;
            final dayNumber = cellIndex - leadingEmptyDays + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 46));
            }

            final day = DateTime(
              _currentMonth.year,
              _currentMonth.month,
              dayNumber,
            );
            final events = _eventsForDay(day);
            final isToday = _isToday(day);
            final isSelected = _isSelected(day);
            final isHovered = _hoveredDay == dayNumber;
            final isWeekend = colIndex >= 5;

            return Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredDay = dayNumber),
                onExit: (_) => setState(() => _hoveredDay = null),
                child: GestureDetector(
                  onTap: () => widget.onDaySelected(day),
                  child: AnimatedContainer(
                    duration: AppMotion.orZero(AppMotion.fast),
                    curve: AppMotion.easeOutStrong,
                    margin: const EdgeInsets.all(2),
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? AppTheme.roseGoldGradient
                          : null,
                      color: !isSelected && (isToday || isHovered)
                          ? AppColors.blushGold.withValues(
                              alpha: isToday ? 0.16 : 0.08,
                            )
                          : Colors.transparent,
                      borderRadius: AppRadius.radiusSm,
                      border: isToday && !isSelected
                          ? Border.all(
                              color: AppColors.blushGold.withValues(
                                alpha: 0.55,
                              ),
                              width: 1.2,
                            )
                          : isHovered && !isSelected
                          ? Border.all(
                              color: AppColors.moonlight.withValues(
                                alpha: 0.16,
                              ),
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.deepRose.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 14,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 13.5,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.petalWhite
                                : isToday
                                ? AppColors.blushGold
                                : AppColors.petalWhite.withValues(
                                    alpha: isWeekend ? 0.85 : 0.68,
                                  ),
                          ),
                        ),
                        if (events.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: events
                                .take(3)
                                .map(
                                  (e) => Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: calendarEventHue(e.type),
                                      boxShadow: [
                                        BoxShadow(
                                          color: calendarEventHue(e.type)
                                              .withValues(alpha: 0.55),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildFooter() {
    final sel = widget.selectedDay;
    final eventsForSel =
        sel == null ? const <CalendarEvent>[] : _eventsForDay(sel);
    final label = sel == null
        ? 'Tap a day to see its details'
        : DateFormat('EEEE, MMM d').format(sel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.moonlight.withValues(alpha: 0.06),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.moonlight.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 14,
            color: AppColors.blushGold.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 11,
                color: AppColors.petalWhite.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (eventsForSel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.auroraRose.withValues(alpha: 0.14),
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: AppColors.auroraRose.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${eventsForSel.length} '
                'event${eventsForSel.length == 1 ? '' : 's'}',
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 9.5,
                  color: AppColors.auroraRose,
                ),
              ),
            )
          else
            Text(
              'no events',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 10,
                color: AppColors.petalWhite.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.moonlight.withValues(
                alpha: _hovered ? 0.16 : 0.08,
              ),
              border: Border.all(
                color: _hovered
                    ? AppColors.blushGold.withValues(alpha: 0.5)
                    : AppColors.moonlight.withValues(alpha: 0.22),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.18),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(widget.icon, color: AppColors.roseQuartz, size: 22),
          ),
        ),
      ),
    );
  }
}
