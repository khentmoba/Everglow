import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  StreamSubscription<List<CalendarEvent>>? _sub;
  Timer? _retryTimer;
  List<CalendarEvent>? _events;
  Object? _error;
  bool _isLoading = true;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // Preview shares the 60-day window with Coming Up (which renders 3
    // cards): one shared query shape instead of two overlapping
    // listeners (30d + 60d) doubling rule evals on every dashboard visit.
    // One subscription for the widget lifetime so dashboard rebuilds don't
    // resubscribe and restart the Firestore listener on every frame.
    _service = CalendarService();
    final cached = _service.cachedUpcoming;
    if (cached != null) {
      _events = cached;
      _isLoading = false;
    }
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _sub = _service.getUpcomingEvents(days: 60).listen(
      (data) {
        if (!mounted) return;
        _retryCount = 0;
        setState(() {
          _events = data;
          _error = null;
          _isLoading = false;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        _scheduleSilentRetry(error);
      },
      onDone: () {
        // withFirestoreTimeout closes the stream without an error when the
        // first snapshot never arrives (cold Firestore WebChannel on first
        // load). Retry silently — the loading row stays up, so Clair never
        // sees a spurious "could not load" that needs a manual tap. The
        // error row only appears after the retries are exhausted.
        if (!mounted) return;
        if (_isLoading && _events == null) _scheduleSilentRetry(_error);
      },
    );
  }

  void _scheduleSilentRetry(Object? error) {
    if (!mounted) return;
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _error = error ?? _error;
      _retryTimer = Timer(Duration(seconds: 1 + _retryCount), () {
        if (mounted) _subscribe();
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = error ?? _error;
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
      _retryCount = 0;
    });
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    // While loading — including silent background retries after a slow
    // first snapshot — keep the loading row up so first load never flashes
    // "could not load calendar". The error row only appears after all
    // retries are exhausted, and the manual tap stays as a last resort.
    // Error (or timeout-closed with no data) must never masquerade as
    // "empty" — the calendar screen would still show dates on tap.
    if (!_isLoading && (_error != null || events == null)) {
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
                    '${firestoreErrorHint(_error)} — tap here to retry.',
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
    if (events == null) {
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

    final displayEvents = events;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FeatureSection(
        icon: Icons.calendar_month_rounded,
        hue: AppColors.warmAmber,
        title: 'Upcoming Dates',
        subtitle: displayEvents.isEmpty
            ? 'nothing on the calendar'
            : 'next ${displayEvents.length} ${displayEvents.length == 1 ? 'date' : 'dates'}',
        trailing: const SectionChevron(hue: AppColors.warmAmber),
        onTap: () => context.push('/calendar'),
        child: displayEvents.isEmpty
            ? Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.warmAmber.withValues(alpha: 0.22),
                          AppColors.auroraRose.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warmAmber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.warmAmber,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No dates yet',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.petalWhite,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to plan something special ♥',
                          style: AppTypography.outfitWhite.copyWith(
                            fontSize: 11,
                            color: AppColors.petalWhite.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.warmAmber,
                    size: 20,
                  ),
                ],
              )
            : Column(
                children: displayEvents.take(3).map((event) {
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

                  final isToday = dayDiff == 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.warmAmber.withValues(alpha: 0.2),
                                AppColors.auroraRose.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.warmAmber.withValues(
                                alpha: 0.38,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat(
                                  'MMM',
                                ).format(event.date).toUpperCase(),
                                style: AppTypography.outfitBold.copyWith(
                                  fontSize: 8,
                                  letterSpacing: 1.0,
                                  color: AppColors.warmAmber,
                                ),
                              ),
                              Text(
                                '${event.date.day}',
                                style: AppTypography.cormorantBold.copyWith(
                                  fontSize: 17,
                                  height: 1.1,
                                  color: AppColors.petalWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${info.$1}  ${event.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 12.5,
                                  color: AppColors.petalWhite,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat(
                                  'EEEE · h:mm a',
                                ).format(event.date),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: isToday
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.auroraRose,
                                      AppColors.deepRose,
                                    ],
                                  )
                                : null,
                            color: isToday
                                ? null
                                : AppColors.warmAmber.withValues(
                                    alpha: 0.14,
                                  ),
                            borderRadius: BorderRadius.circular(20),
                            border: isToday
                                ? null
                                : Border.all(
                                    color: AppColors.warmAmber.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                          ),
                          child: Text(
                            isToday ? 'Today ♥' : timeLabel,
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10,
                              color: isToday
                                  ? AppColors.petalWhite
                                  : AppColors.warmAmber,
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
  }
}
