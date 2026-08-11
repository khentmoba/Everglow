import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_colors.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../../../calendar/data/services/calendar_service.dart';
import 'package:everglow/core/theme/app_typography.dart';
import 'feature_section.dart';

class CalendarPreview extends StatelessWidget {
  const CalendarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: CalendarService().getUpcomingEvents(days: 30),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: FeatureSection(
            icon: Icons.calendar_month_rounded,
            hue: AppColors.warmAmber,
            title: 'Upcoming Dates',
            subtitle: events.isEmpty
                ? 'nothing on the calendar'
                : 'next ${events.length} ${events.length == 1 ? 'date' : 'dates'}',
            trailing: const SectionChevron(hue: AppColors.warmAmber),
            onTap: () => context.push('/calendar'),
            child: events.isEmpty
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
                          'Plan the next special day',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12,
                            color: AppColors.petalWhite.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: events.take(3).map((event) {
                      final info =
                          calendarEventTypeInfo[event.type] ?? ('gift', '');
                      final dayDiff = event.date
                          .difference(DateTime.now())
                          .inDays;
                      final timeLabel = dayDiff == 0
                          ? 'Today'
                          : dayDiff == 1
                          ? 'Tomorrow'
                          : 'In $dayDiff days';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.warmAmber.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.warmAmber.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  info.$1,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                event.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 12,
                                  color: AppColors.petalWhite,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warmAmber.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                timeLabel,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10,
                                  color: AppColors.warmAmber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        );
      },
    );
  }
}
