import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/firestore_stream_utils.dart';

import '../../../calendar/data/services/calendar_service.dart';
import '../../../calendar/domain/models/calendar_event.dart';
import '../../../calendar/presentation/widgets/calendar_event_style.dart';
import 'feature_section.dart';
import 'dashboard_load_tracker.dart';
import '../../../../core/utils/logger.dart';

part 'upcoming_countdowns_cards.dart';
part 'upcoming_countdowns_footer.dart';

// Shared formatter: constructing DateFormat per card per build re-parses
// the pattern on every emission while scrolling.
final _eventDateFormat = DateFormat('EEE, MMM d');

class UpcomingCountdowns extends StatefulWidget {
  const UpcomingCountdowns({super.key});

  @override
  State<UpcomingCountdowns> createState() => _UpcomingCountdownsState();
}

class _UpcomingCountdownsState extends State<UpcomingCountdowns> {
  late final CalendarService _calendarService;
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
    _calendarService = CalendarService();
    final cached = _calendarService.cachedUpcoming;
    if (cached != null) {
      _events = cached;
      _isLoading = false;
      // Cache-first paint counts as ready; report post-frame since
      // notifyListeners must not fire during initState's build pass.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportLoaded());
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
    _sub = _calendarService
        .getUpcomingEvents(days: 60)
        .listen(
          (data) {
            if (!mounted) return;
            _retryCount = 0;
            setState(() {
              _events = data;
              _error = null;
              _isLoading = false;
            });
            _reportLoaded();
          },
          onError: (Object error, StackTrace st) {
            Logger.e(
              'UpcomingCountdowns: upcoming events stream error',
              error: error,
              stackTrace: st,
            );
            if (!mounted) return;
            _scheduleSilentRetry(error);
          },
          onDone: () {
            // withFirestoreTimeout closes the stream without an error when the
            // first snapshot never arrives (cold Firestore WebChannel on first
            // load). Retry silently — the loading row stays up, so the user
            // never sees a spurious "could not load dates". The error UI only
            // appears after the retries are exhausted.
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
      // Retries exhausted: the error row is final, so the veil can
      // stop waiting on us even though no dates arrived.
      _reportLoaded();
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

  /// First-screen progress: dates have settled (data, cache, or final
  /// error), so the load veil can count us. Marking is idempotent —
  /// cache hits, snapshots, and manual retries all funnel here safely.
  void _reportLoaded() {
    if (!mounted) return;
    try {
      context.read<DashboardLoadTracker>().mark(DashboardLoadSignal.dates);
    } catch (e, st) {
      Logger.e(
        'UpcomingCountdowns: failed to report dates load signal',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    // While loading — including silent background retries after a slow
    // first snapshot — keep the loading row up so first load never flashes
    // "could not load dates". The error row only appears after all retries
    // are exhausted, and the manual tap stays as a last resort.
    if (!_isLoading && (_error != null || events == null)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: FeatureSection(
          icon: Icons.event_rounded,
          hue: AppColors.warmAmber,
          title: 'Coming Up',
          subtitle: 'could not load dates',
          trailing: SectionPillLink(
            label: 'Calendar',
            hue: AppColors.warmAmber,
            onTap: () => context.push('/calendar'),
          ),
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
                const SectionChevron(hue: AppColors.warmAmber),
              ],
            ),
          ),
        ),
      );
    }

    // Waiting for the first snapshot (or a silent retry) is loading,
    // not empty — and never an error the user must dismiss by hand.
    if (events == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: FeatureSection(
          icon: Icons.event_rounded,
          hue: AppColors.warmAmber,
          title: 'Coming Up',
          subtitle: 'loading dates…',
          trailing: SectionPillLink(
            label: 'Calendar',
            hue: AppColors.warmAmber,
            onTap: () => context.push('/calendar'),
          ),
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

    final displayEvents = events.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FeatureSection(
        icon: Icons.event_rounded,
        hue: AppColors.warmAmber,
        title: 'Coming Up',
        subtitle: displayEvents.isEmpty
            ? 'no dates planned yet'
            : '${displayEvents.length} upcoming '
                  '${displayEvents.length == 1 ? 'date' : 'dates'}',
        trailing: SectionPillLink(
          label: 'Calendar',
          hue: AppColors.warmAmber,
          onTap: () => context.push('/calendar'),
        ),
        onTap: () => context.push('/calendar'),
        child: displayEvents.isEmpty
            ? const _EmptyDatesCta()
            : SizedBox(
                height: 182,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemCount: displayEvents.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _CountdownEventCard(
                      event: displayEvents[index],
                      index: index,
                    );
                  },
                ),
              ),
      ),
    );
  }
}
