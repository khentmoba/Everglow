import 'package:flutter/material.dart';import 'package:go_router/go_router.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/shared/widgets/everglow/everglow_countdown.dart';
import '../../../calendar/data/services/calendar_service.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import 'package:everglow/core/theme/app_typography.dart';

/// Dashboard section showing upcoming calendar events as countdown cards.
class UpcomingCountdowns extends StatelessWidget {
  final CalendarService _calendarService = CalendarService();

  UpcomingCountdowns({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _calendarService.getUpcomingEvents(days: 60),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return GestureDetector(
            onTap: () => context.push('/calendar'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Coming Up',
                    style: AppTypography.cormorantBold.copyWith(fontSize: 20),
                  ),
                  const Spacer(),
                  Text(
                    'Add dates →',
                    style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppTheme.blushGold.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          );
        }

        final events = snapshot.data!;
        // Show up to 3 upcoming events
        final displayEvents = events.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Coming Up',
                    style: AppTypography.cormorantBold.copyWith(fontSize: 20),
                  ),
                  TextButton(
                    onPressed: () => context.push('/calendar'),
                    child: Text(
                      'Calendar',
                      style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.blushGold),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: displayEvents.length,
                itemBuilder: (context, index) {
                  return _CountdownEventCard(event: displayEvents[index]);
                },
              ),
            ),
          ],
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

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.velvet.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.moonlight.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Event type + title
            Row(
              children: [
                Text(
                  info?.$1 ?? '📌',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitWhite.copyWith(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.petalWhite),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Countdown
            EverglowCountdown(
              target: event.date,
              style: EverglowCountdownStyle.compact,
            ),
          ],
        ),
      ),
    );
  }
}
