import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/gamified_background.dart';
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
  DateTime _currentMonth = DateTime.now();
  bool _showDayDetail = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    // The stream will handle real-time updates
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
      _showDayDetail = true;
    });
  }

  void _refresh() {
    setState(() {}); // triggers rebuild → stream re-evaluates
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GamifiedBackground(
        child: SafeArea(
          child: Stack(
            children: [
            Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/dashboard'),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.roseQuartz,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Shared Calendar',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.roseQuartz,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // ── Calendar Grid ──
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
                          const SizedBox(height: 8),

                          // ── Upcoming Events ──
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Text(
                                  'Upcoming',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.roseQuartz,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: StreamBuilder<List<CalendarEvent>>(
                              stream:
                                  _calendarService.getUpcomingEvents(days: 60),
                              builder: (context, snapshot) {
                                final upcoming = snapshot.data ?? [];
                                if (upcoming.isEmpty) {
                                  return Center(
                                    child: Text(
                                      "No upcoming events",
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppTheme.petalWhite
                                            .withValues(alpha: 0.4),
                                      ),
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
                                            ('📌', '');
                                    final dayDiff = event.date
                                        .difference(DateTime.now())
                                        .inDays;
                                    final timeLabel = dayDiff == 0
                                        ? 'Today'
                                        : dayDiff == 1
                                            ? 'Tomorrow'
                                            : 'In $dayDiff days';

                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.moonlight.withValues(
                                          alpha: AppTheme.glassOpacity,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppTheme.blushGold
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            info.$1,
                                            style: const TextStyle(
                                              fontSize: 20,
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
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: AppTheme
                                                        .petalWhite,
                                                  ),
                                                ),
                                                Text(
                                                  timeLabel,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    color: AppTheme
                                                        .blushGold,
                                                  ),
                                                ),
                                              ],
                                            ),
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

            // ── Day Detail Sheet ──
            if (_showDayDetail)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showDayDetail = false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),
            if (_showDayDetail)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: DayDetailSheet(
                  day: _selectedDay,
                  onEventAdded: _refresh,
                ),
              ),
          ],
        ),
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            barrierColor: Colors.transparent,
            builder: (_) => AddEventDialog(selectedDay: _selectedDay),
          );
          if (result == true) _refresh();
        },
        backgroundColor: AppTheme.deepRose,
        foregroundColor: AppTheme.petalWhite,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
