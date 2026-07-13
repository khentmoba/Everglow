import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../../../calendar/data/services/calendar_service.dart';

class CalendarPreview extends StatelessWidget {
  const CalendarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: CalendarService().getUpcomingEvents(days: 30),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => context.push('/calendar'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.blushGold.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: AppTheme.blushGold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upcoming Dates',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.roseQuartz,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      color: AppTheme.blushGold.withValues(alpha: 0.65),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...events.take(3).map((event) {
                  final info = calendarEventTypeInfo[event.type] ??
                      ('📌', '');
                  final dayDiff = event.date
                      .difference(DateTime.now())
                      .inDays;
                  final timeLabel = dayDiff == 0
                      ? 'Today'
                      : dayDiff == 1
                          ? 'Tomorrow'
                          : 'In $dayDiff days';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(info.$1, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.petalWhite,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: AppTheme.blushGold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
