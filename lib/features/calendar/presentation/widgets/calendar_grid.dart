import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../domain/models/calendar_event.dart';
import 'package:everglow/core/theme/app_typography.dart';

class CalendarGrid extends StatefulWidget {
  final DateTime initialMonth;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? selectedDay;

  const CalendarGrid({
    super.key,
    required this.initialMonth,
    required this.events,
    required this.onDaySelected,
    this.selectedDay,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  late DateTime _currentMonth;

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
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
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

    final monthNames = [
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

    return Column(
      children: [
        // ── Month Header ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.roseQuartz,
                  size: 28,
                ),
              ),
              Text(
                '${monthNames[_currentMonth.month]} ${_currentMonth.year}',
                style: AppTypography.cormorantBold.copyWith(fontSize: 22),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.roseQuartz,
                  size: 28,
                ),
              ),
            ],
          ),
        ),

        // ── Weekday Headers ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 11,
                          color: AppTheme.petalWhite.withValues(alpha: 0.65),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 4),

        // ── Day Grid ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: List.generate(rows, (rowIndex) {
              return Row(
                children: List.generate(7, (colIndex) {
                  final cellIndex = rowIndex * 7 + colIndex;
                  final dayNumber = cellIndex - leadingEmptyDays + 1;

                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 44));
                  }

                  final day = DateTime(
                    _currentMonth.year,
                    _currentMonth.month,
                    dayNumber,
                  );
                  final events = _eventsForDay(day);
                  final isToday = _isToday(day);
                  final isSelected = _isSelected(day);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onDaySelected(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(2),
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.deepRose.withValues(alpha: 0.6)
                              : isToday
                              ? AppTheme.blushGold.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: AppTheme.blushGold.withValues(
                                    alpha: 0.6,
                                  ),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNumber',
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 14,
                                fontWeight: isToday || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isToday || isSelected
                                    ? AppTheme.petalWhite
                                    : AppTheme.petalWhite.withValues(
                                        alpha: 0.7,
                                      ),
                              ),
                            ),
                            if (events.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: events
                                    .take(3)
                                    .map(
                                      (e) => Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _eventColor(e.type),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }

  Color _eventColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.dateNight:
        return AppTheme.deepRose;
      case CalendarEventType.anniversary:
        return AppTheme.blushGold;
      case CalendarEventType.reminder:
        return AppTheme.softLavender;
      case CalendarEventType.custom:
        return AppTheme.roseQuartz;
    }
  }
}
