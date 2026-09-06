import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/firestore_stream_utils.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../../../calendar/data/services/calendar_service.dart';
import '../../../../core/theme/app_typography.dart';
import 'feature_section.dart';

class CalendarPreview extends StatefulWidget {
  const CalendarPreview({super.key});

  @override
  State<CalendarPreview> createState() => _CalendarPreviewState();
}

class _CalendarPreviewState extends State<CalendarPreview> {
  late final CalendarService _service;
  late Stream<List<CalendarEvent>> _upcoming;

  @override
  void initState() {
    super.initState();
    _service = CalendarService();
    _upcoming = _service.getUpcomingEvents(days: 30);
  }

  void _retry() {
    setState(() {
      _upcoming = _service.getUpcomingEvents(days: 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _upcoming,
      builder: (context, snapshot) {
        // Error (or timeout-closed with no data) must never masquerade as
        // "empty" — the calendar screen would still show dates on tap.
        if (snapshot.hasError ||
            (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.done)) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: FeatureSection(
              icon: Icons.calendar_month_rounded,
              hue: AppColors.warmAmber,
              title: 'Upcoming Dates',
              subtitle: 'could not load calendar',
              trailing: const SectionChevron(hue: AppColors.warmAmber),
              onTap: () => context.push('/calendar'),
              child: GestureDetector(
                onTap: _retry,
                child: Row(
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.warmAmber,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${firestoreErrorHint(snapshot.error)} — tap here to retry.',
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 12,
                          color: AppColors.petalWhite.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Waiting for the first snapshot is loading, not empty.
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: FeatureSection(
              icon: Icons.calendar_month_rounded,
              hue: AppColors.warmAmber,
              title: 'Upcoming Dates',
              subtitle: 'loading dates…',
              trailing: const SectionChevron(hue: AppColors.warmAmber),
              onTap: () => context.push('/calendar'),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Loading upcoming dates…',
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final events = snapshot.data!;

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
