import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_scaffold.dart';
import '../../../../shared/widgets/everglow/everglow_segmented_control.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';

import '../../data/services/calendar_service.dart';
import '../../domain/models/calendar_event.dart';
import '../widgets/add_event_dialog.dart';
import '../widgets/add_poll_dialog.dart';
import '../widgets/calendar_event_style.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/polls_tab.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  late Stream<List<CalendarEvent>> _monthEventsStream;
  late Stream<List<CalendarEvent>> _upcomingStream;

  DateTime _selectedDay = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  int _tabIndex = 0; // 0 = calendar, 1 = polls (Rallly)

  @override
  void initState() {
    super.initState();
    _monthEventsStream = _calendarService.getEventsForMonth(_currentMonth);
    _upcomingStream = _calendarService.getUpcomingEvents(days: 60);
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
      _monthEventsStream = _calendarService.getEventsForMonth(_currentMonth);
    });
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
    _openDaySheet(day);
  }

  void _openDaySheet(DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (_) => DayDetailSheet(day: day, onEventAdded: _refresh),
    );
  }

  void _refresh() {
    setState(() {
      _monthEventsStream = _calendarService.getEventsForMonth(_currentMonth);
      _upcomingStream = _calendarService.getUpcomingEvents(days: 60);
    });
  }

  Future<void> _openAddEvent() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AddEventDialog(selectedDay: _selectedDay),
    );
    if (result == true) _refresh();
  }

  Future<void> _openAddPoll() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const AddPollDialog(),
    );
    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
        return EverglowScaffold(
      backgroundColor: AppColors.inkDeep,
      glows: [const RadialGlow(color: AppColors.warmAmber, alignment: Alignment(-0.7, -0.9), size: 0.9, opacity: 0.12), const RadialGlow(color: AppColors.softLavender, alignment: Alignment(0.9, 0.8), size: 0.7, opacity: 0.10)],
      body: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Shared Calendar',
                  subtitle: 'our special dates',
                  icon: Icons.calendar_month_rounded,
                  hue: AppColors.warmAmber,
                  actions: [_CalendarRefreshButton(onPressed: _refresh)],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EverglowSegmentedControl(
                    selectedIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                    activeColor: AppColors.warmAmber,
                    items: const [
                      SegmentItem('Calendar', Icons.calendar_month_rounded),
                      SegmentItem('Polls', Icons.how_to_vote_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_tabIndex == 0)
                  Expanded(
                    child: StreamBuilder<List<CalendarEvent>>(
                      stream: _monthEventsStream,
                      builder: (context, snapshot) {
                        final events = snapshot.data ?? [];
                        return Column(
                          children: [
                            CalendarGrid(
                              initialMonth: _currentMonth,
                              events: events,
                              selectedDay: _selectedDay,
                              onDaySelected: _onDaySelected,
                              onMonthChanged: _onMonthChanged,
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: StreamBuilder<List<CalendarEvent>>(
                                stream: _upcomingStream,
                                builder: (context, snapshot) {
                                  final upcoming = snapshot.data ?? [];
                                  return Column(
                                    children: [
                                      _buildUpcomingHeader(
                                        count: upcoming.length,
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: upcoming.isEmpty
                                            ? _buildEmptyState()
                                            : ListView.builder(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      2,
                                                      16,
                                                      96,
                                                    ),
                                                itemCount: upcoming.length
                                                    .clamp(0, 10),
                                                itemBuilder: (context, index) {
                                                  final event = upcoming[index];
                                                  if (index == 0) {
                                                    return _NextDateHero(
                                                      event: event,
                                                      onTap: () => _openDaySheet(
                                                        event.date,
                                                      ),
                                                    );
                                                  }
                                                  return _UpcomingEventCard(
                                                    event: event,
                                                    onTap: () => _openDaySheet(
                                                      event.date,
                                                    ),
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
                        );
                      },
                    ),
                  )
                else
                  const Expanded(child: PollsTab()),
              ],
            ),
      floatingActionButton: _CalendarFab(
        onPressed: _tabIndex == 0 ? _openAddEvent : _openAddPoll,
      ),
    );
  }

  Widget _buildUpcomingHeader({required int count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              gradient: AppTheme.roseGoldGradient,
              borderRadius: AppRadius.radiusFull,
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepRose.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coming up',
                style: AppTypography.cormorantBold.copyWith(
                  fontSize: 21,
                  height: 1.0,
                  letterSpacing: 0.3,
                  color: AppColors.petalWhite,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count == 0 ? 'nothing planned yet' : 'your next dates',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                  color: AppColors.petalWhite.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.auroraRose, AppColors.deepRose],
                ),
                borderRadius: AppRadius.radiusFull,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    size: 10,
                    color: AppColors.petalWhite,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 12,
                      color: AppColors.petalWhite,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.auroraRose.withValues(alpha: 0.22),
                          AppColors.deepRose.withValues(alpha: 0.10),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.auroraRose.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepRose.withValues(alpha: 0.25),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.auroraRose,
                      size: 34,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.inkDeep.withValues(alpha: 0.85),
                        border: Border.all(
                          color: AppColors.blushGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.blushGold,
                        size: 14,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 6,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.inkDeep.withValues(alpha: 0.85),
                        border: Border.all(
                          color: AppColors.auroraLilac.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.auroraLilac,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Nothing planned yet',
              style: AppTypography.cormorantBold.copyWith(
                fontSize: 22,
                color: AppColors.petalWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your next date night is waiting\nto be dreamed up.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 12,
                height: 1.5,
                color: AppColors.petalWhite.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openAddEvent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.roseGoldGradient,
                  borderRadius: AppRadius.radiusFull,
                  border: Border.all(
                    color: AppColors.petalWhite.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 17,
                      color: AppColors.petalWhite,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Plan the next date',
                      style: AppTypography.outfitBold.copyWith(
                        fontSize: 13,
                        color: AppColors.petalWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Featured spotlight for the very next date — a little countdown hero
/// so Clair always sees what's coming first, big and warm.
class _NextDateHero extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _NextDateHero({required this.event, required this.onTap});

  @override
  State<_NextDateHero> createState() => _NextDateHeroState();
}

class _NextDateHeroState extends State<_NextDateHero> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final info = calendarEventTypeInfo[event.type] ?? ('gift', '');
    final hue = calendarEventHue(event.type);
    final dayDiff = event.date.difference(DateTime.now()).inDays;
    final countdown = dayDiff <= 0
        ? 'Today!'
        : dayDiff == 1
        ? 'Tomorrow!'
        : '$dayDiff';
    final countdownLabel = dayDiff <= 1 ? 'is the day' : 'days to go';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  hue.withValues(alpha: 0.28),
                  AppColors.plum.withValues(alpha: 0.65),
                  AppColors.inkDeep.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: AppRadius.radiusX2,
              border: Border.all(
                color: _hovered
                    ? hue.withValues(alpha: 0.65)
                    : hue.withValues(alpha: 0.38),
              ),
              boxShadow: [
                BoxShadow(
                  color: hue.withValues(alpha: _hovered ? 0.25 : 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -12,
                  right: -8,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 92,
                      color: hue.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.roseGoldGradient,
                            borderRadius: AppRadius.radiusFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 10,
                                color: AppColors.petalWhite,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'NEXT DATE',
                                style: AppTypography.outfitBold.copyWith(
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                  color: AppColors.petalWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          info.$2.toUpperCase(),
                          style: AppTypography.outfitBold.copyWith(
                            fontSize: 9.5,
                            letterSpacing: 1.0,
                            color: hue.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${info.$1}  ${event.title}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cormorantBold.copyWith(
                                  fontSize: 23,
                                  height: 1.1,
                                  color: AppColors.petalWhite,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: hue.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      DateFormat(
                                        'EEEE, MMM d',
                                      ).format(event.date),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.outfitBold.copyWith(
                                        fontSize: 12,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (event.location != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.place_rounded,
                                      size: 12,
                                      color: AppColors.auroraTeal,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        event.location!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.outfitWhite
                                            .copyWith(
                                              fontSize: 11.5,
                                              color: AppColors.auroraTeal,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inkDeep.withValues(alpha: 0.55),
                            borderRadius: AppRadius.radiusLg,
                            border: Border.all(
                              color: hue.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                countdown,
                                style: AppTypography.cormorantBold.copyWith(
                                  fontSize: 30,
                                  height: 1.0,
                                  color: hue,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                countdownLabel,
                                style: AppTypography.outfitBold.copyWith(
                                  fontSize: 9,
                                  letterSpacing: 0.6,
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingEventCard extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _UpcomingEventCard({required this.event, required this.onTap});

  @override
  State<_UpcomingEventCard> createState() => _UpcomingEventCardState();
}

class _UpcomingEventCardState extends State<_UpcomingEventCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final info = calendarEventTypeInfo[event.type] ?? ('gift', '');
    final hue = calendarEventHue(event.type);
    final dayDiff = event.date.difference(DateTime.now()).inDays;
    final timeLabel = dayDiff == 0
        ? 'Today'
        : dayDiff == 1
        ? 'Tomorrow'
        : 'In $dayDiff days';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hovered ? -2.0 : 0.0, 0.0, 1.0),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  hue.withValues(alpha: 0.12),
                  AppColors.silk.withValues(alpha: 0.55),
                  AppColors.inkDeep.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: _hovered
                    ? hue.withValues(alpha: 0.55)
                    : hue.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.inkDeep.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                if (_hovered)
                  BoxShadow(
                    color: hue.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Row(
              children: [
                _EventEmojiChip(emoji: info.$1, hue: hue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.outfitWhite.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.petalWhite,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: hue.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('EEE, MMM d').format(event.date),
                            style: AppTypography.outfitWhite.copyWith(
                              fontSize: 10.5,
                              color: AppColors.petalWhite.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hue.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              info.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfitBold.copyWith(
                                fontSize: 10,
                                letterSpacing: 0.3,
                                color: hue.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (event.location != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              size: 10,
                              color: AppColors.auroraTeal,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.location!,
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 10,
                                color: AppColors.auroraTeal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _TimePill(label: timeLabel, hue: hue),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hue.withValues(alpha: 0.10),
                    border: Border.all(color: hue.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: hue,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventEmojiChip extends StatelessWidget {
  final String emoji;
  final Color hue;

  const _EventEmojiChip({required this.emoji, required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hue.withValues(alpha: 0.26), hue.withValues(alpha: 0.08)],
        ),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: hue.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: hue.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final Color hue;

  const _TimePill({required this.label, required this.hue});

  @override
  Widget build(BuildContext context) {
    final isToday = label == 'Today';

    if (isToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.auroraRose, AppColors.deepRose],
          ),
          borderRadius: AppRadius.radiusFull,
          boxShadow: [
            BoxShadow(
              color: AppColors.deepRose.withValues(alpha: 0.45),
              blurRadius: 12,
            ),
          ],
        ),
        child: Text(
          'Today ♥',
          style: AppTypography.outfitBold.copyWith(
            fontSize: 10.5,
            letterSpacing: 0.2,
            color: AppColors.petalWhite,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.14),
        borderRadius: AppRadius.radiusFull,
        border: Border.all(color: hue.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.outfitBold.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.2,
          color: hue,
        ),
      ),
    );
  }
}

class _CalendarRefreshButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _CalendarRefreshButton({required this.onPressed});

  @override
  State<_CalendarRefreshButton> createState() => _CalendarRefreshButtonState();
}

class _CalendarRefreshButtonState extends State<_CalendarRefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: AppMotion.orZero(AppMotion.fast),
            curve: AppMotion.easeOutStrong,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.moonlight.withValues(
                alpha: _hovered ? 0.16 : 0.08,
              ),
              border: Border.all(
                color: _hovered
                    ? AppColors.blushGold.withValues(alpha: 0.5)
                    : AppColors.moonlight.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: AppColors.blushGold,
              size: 18,
            ),
          ),
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
      message: 'Add',
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
