import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/shared/widgets/everglow/everglow_countdown.dart';
import '../../../calendar/data/services/calendar_service.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import 'package:everglow/core/theme/app_typography.dart';
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
                : '${displayEvents.length} upcoming ${displayEvents.length == 1 ? 'date' : 'dates'}',
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
                    height: 96,
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
    final info = calendarEventTypeInfo[event.type];

    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.moonlight.withValues(alpha: 0.12),
            AppColors.inkDeep.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(info?.$1 ?? 'gift', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.outfitWhite.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.petalWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          EverglowCountdown(
            target: event.date,
            style: EverglowCountdownStyle.compact,
          ),
        ],
      ),
    );
  }
}
