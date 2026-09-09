import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              AppColors.plum.withValues(alpha: 0.72),
              AppColors.silk.withValues(alpha: 0.72),
              AppColors.inkDeep.withValues(alpha: 0.88),
            ],
          ),
          borderRadius: AppRadius.radiusX2,
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkDeep.withValues(alpha: 0.55),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.blushGold.withValues(alpha: 0.07),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Faint romantic watermark — cheap (two icons, no blur).
            Positioned(
              top: -14,
              right: -10,
              child: IgnorePointer(
                child: Icon(
                  Icons.favorite_rounded,
                  size: 118,
                  color: AppColors.auroraRose.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 14,
              child: IgnorePointer(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 22,
                  color: AppColors.blushGold.withValues(alpha: 0.16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
              child: Column(
                children: [
                  _buildMonthHeader(),
                  const SizedBox(height: 12),
                  _buildWeekdayHeader(),
                  const SizedBox(height: 8),
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
          ],
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
                  fontSize: 24,
                  height: 1.0,
                  letterSpacing: 0.4,
                  color: AppColors.petalWhite,
                  shadows: [
                    Shadow(
                      color: AppColors.blushGold.withValues(alpha: 0.28),
                      blurRadius: 14,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 7),
              GestureDetector(
                onTap: isCurrentMonth ? null : _goToToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.blushGold.withValues(alpha: 0.20),
                        AppColors.auroraRose.withValues(alpha: 0.14),
                      ],
                    ),
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(
                      color: AppColors.blushGold.withValues(alpha: 0.36),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.10),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCurrentMonth
                            ? Icons.favorite_rounded
                            : Icons.today_rounded,
                        size: 10,
                        color: AppColors.blushGold,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isCurrentMonth
                            ? '$count special ${count == 1 ? 'date' : 'dates'}'
                            : 'Back to today',
                        style: AppTypography.outfitBold.copyWith(
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                          color: AppColors.blushGold,
                        ),
                      ),
                    ],
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
    return Column(
      children: [
        Row(
          children: List.generate(7, (index) {
            final isWeekend = index >= 5;
            return Expanded(
              child: Center(
                child: Text(
                  _weekdays[index].toUpperCase(),
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: isWeekend
                        ? AppColors.auroraGold
                        : AppColors.petalWhite.withValues(alpha: 0.62),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.blushGold.withValues(alpha: 0.30),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
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
              return const Expanded(child: SizedBox(height: 52));
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

            final semLabel = events.isEmpty
                ? DateFormat('EEEE, MMMM d, y').format(day)
                : '${DateFormat('EEEE, MMMM d, y').format(day)}, ${events.length} ${events.length == 1 ? 'event' : 'events'}';
            return Expanded(
              child: Semantics(
                button: true,
                label: semLabel,
                selected: isSelected,
                child: FocusableActionDetector(
                  mouseCursor: SystemMouseCursors.click,
                  onShowFocusHighlight: (f) =>
                      setState(() => _hoveredDay = f ? dayNumber : null),
                  onShowHoverHighlight: (h) =>
                      setState(() => _hoveredDay = h ? dayNumber : null),
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                  },
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        widget.onDaySelected(day);
                        return null;
                      },
                    ),
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredDay = dayNumber),
                    onExit: (_) => setState(() => _hoveredDay = null),
                    child: GestureDetector(
                      onTap: () => widget.onDaySelected(day),
                      child: AnimatedContainer(
                        duration: AppMotion.orZero(AppMotion.fast),
                        curve: AppMotion.easeOutStrong,
                        margin: const EdgeInsets.all(3),
                        height: 52,
                        transform: Matrix4.identity()
                          ..scaleByDouble(
                            isSelected ? 1.05 : 1.0,
                            isSelected ? 1.05 : 1.0,
                            1.0,
                            1.0,
                          ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? AppTheme.roseGoldGradient
                              : null,
                          color: isSelected
                              ? null
                              : isToday
                              ? AppColors.blushGold.withValues(alpha: 0.14)
                              : isHovered
                              ? AppColors.moonlight.withValues(alpha: 0.10)
                              : events.isNotEmpty
                              ? AppColors.moonlight.withValues(alpha: 0.05)
                              : Colors.transparent,
                          borderRadius: AppRadius.radiusMd,
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.55,
                                  ),
                                  width: 1.2,
                                )
                              : isToday
                              ? Border.all(
                                  color: AppColors.blushGold.withValues(
                                    alpha: 0.7,
                                  ),
                                  width: 1.4,
                                )
                              : isHovered
                              ? Border.all(
                                  color: AppColors.moonlight.withValues(
                                    alpha: 0.24,
                                  ),
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.deepRose.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 18,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : isToday
                              ? [
                                  BoxShadow(
                                    color: AppColors.blushGold.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 14,
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
                                fontSize: isSelected ? 14.5 : 13.5,
                                fontWeight: isToday || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.petalWhite
                                    : isToday
                                    ? AppColors.blushGold
                                    : AppColors.petalWhite.withValues(
                                        alpha: isWeekend ? 0.92 : 0.74,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (events.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: events
                                    .take(3)
                                    .map(
                                      (e) => Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? AppColors.petalWhite
                                              : calendarEventHue(e.type),
                                          boxShadow: [
                                            BoxShadow(
                                              color: calendarEventHue(
                                                e.type,
                                              ).withValues(alpha: 0.7),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              )
                            else if (isToday)
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.blushGold.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 6),
                          ],
                        ),
                      ),
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
    final eventsForSel = sel == null
        ? const <CalendarEvent>[]
        : _eventsForDay(sel);
    final label = sel == null
        ? 'Tap a day to see its details'
        : DateFormat('EEEE, MMM d').format(sel);

    return GestureDetector(
      onTap: sel == null ? null : () => widget.onDaySelected(sel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.blushGold.withValues(alpha: 0.12),
              AppColors.auroraRose.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: AppColors.blushGold.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blushGold.withValues(alpha: 0.14),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                sel == null
                    ? Icons.touch_app_rounded
                    : Icons.favorite_rounded,
                size: 13,
                color: AppColors.blushGold,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: AppTypography.outfitBold.copyWith(
                  fontSize: 12,
                  letterSpacing: 0.2,
                  color: AppColors.petalWhite.withValues(alpha: 0.85),
                ),
              ),
            ),
            if (eventsForSel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.auroraRose, AppColors.deepRose],
                  ),
                  borderRadius: AppRadius.radiusFull,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  '${eventsForSel.length} '
                  'event${eventsForSel.length == 1 ? '' : 's'} ♥',
                  style: AppTypography.outfitBold.copyWith(
                    fontSize: 10,
                    color: AppColors.petalWhite,
                  ),
                ),
              )
            else
              Text(
                sel == null ? '' : 'no events yet',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.petalWhite.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _hovered
                  ? LinearGradient(
                      colors: [
                        AppColors.blushGold.withValues(alpha: 0.28),
                        AppColors.auroraRose.withValues(alpha: 0.20),
                      ],
                    )
                  : null,
              color: _hovered
                  ? null
                  : AppColors.moonlight.withValues(alpha: 0.08),
              border: Border.all(
                color: _hovered
                    ? AppColors.blushGold.withValues(alpha: 0.6)
                    : AppColors.moonlight.withValues(alpha: 0.22),
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: AppColors.blushGold.withValues(alpha: 0.22),
                        blurRadius: 16,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(widget.icon, color: AppColors.blushGold, size: 22),
          ),
        ),
      ),
    );
  }
}
