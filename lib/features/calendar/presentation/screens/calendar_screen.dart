import 'package:flutter/material.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/core/theme/app_motion.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/shared/widgets/everglow/everglow_background.dart';
import 'package:everglow/shared/widgets/everglow/everglow_feature_header.dart';
import '../../domain/models/calendar_event.dart';
import '../../data/services/calendar_service.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/add_event_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  DateTime _selectedDay = DateTime.now();
  final DateTime _currentMonth = DateTime.now();
  bool _showDayDetail = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    // The stream handles real-time updates.
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
      _showDayDetail = true;
    });
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
                    stream: _calendarService.getEventsForMonth(_currentMonth),
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
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.roseGoldGradient,
                                    borderRadius: BorderRadius.circular(2),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: StreamBuilder<List<CalendarEvent>>(
                              stream: _calendarService.getUpcomingEvents(
                                days: 60,
                              ),
                              builder: (context, snapshot) {
                                final upcoming = snapshot.data ?? [];
                                if (upcoming.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.event_busy_rounded,
                                          color: AppColors.textDisabled,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No upcoming events',
                                          style: AppTypography.outfitWhite
                                              .copyWith(
                                                fontSize: 13,
                                                color: AppColors.petalWhite
                                                    .withValues(alpha: 0.45),
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: upcoming.length.clamp(0, 10),
                                  itemBuilder: (context, index) {
                                    final event = upcoming[index];
                                    final info =
                                        calendarEventTypeInfo[event.type] ??
                                        ('gift', '');
                                    final dayDiff = event.date
                                        .difference(DateTime.now())
                                        .inDays;
                                    final timeLabel = dayDiff == 0
                                        ? 'Today'
                                        : dayDiff == 1
                                        ? 'Tomorrow'
                                        : 'In $dayDiff days';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.moonlight.withValues(
                                              alpha: 0.10,
                                            ),
                                            AppColors.inkDeep.withValues(
                                              alpha: 0.55,
                                            ),
                                          ],
                                        ),
                                        borderRadius: AppRadius.radiusLg,
                                        border: Border.all(
                                          color: AppColors.blushGold.withValues(
                                            alpha: 0.16,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: AppColors.warmAmber
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: AppColors.warmAmber
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                info.$1,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  event.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTypography
                                                      .outfitWhite
                                                      .copyWith(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .petalWhite,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  timeLabel,
                                                  style: AppTypography
                                                      .outfitWhite
                                                      .copyWith(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.blushGold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: AppColors.blushGold,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
          if (_showDayDetail)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showDayDetail = false),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
          if (_showDayDetail)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: DayDetailSheet(day: _selectedDay, onEventAdded: _refresh),
            ),
        ],
      ),
      floatingActionButton: _CalendarFab(onPressed: _openAddEvent),
    );
  }
}

class _CalendarRefreshButton extends StatelessWidget {
  const _CalendarRefreshButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.moonlight.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.2)),
        ),
        child: const Icon(
          Icons.refresh_rounded,
          color: AppColors.blushGold,
          size: 18,
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
