import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../cinema/data/models/media_item.dart';
import '../../../data/models/animex_models.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
import 'animex_schedule_list.dart';
import 'animex_tokens.dart';

const _days = <(String, String)>[
  ('Mon', 'Monday'),
  ('Tue', 'Tuesday'),
  ('Wed', 'Wednesday'),
  ('Thu', 'Thursday'),
  ('Fri', 'Friday'),
  ('Sat', 'Saturday'),
  ('Sun', 'Sunday'),
];

/// This week's broadcast dates with a personal My List view. No notification
/// promise: the former bell only persisted a device-local preference.
class AnimeXSchedulePage extends StatefulWidget {
  final AnimeXController controller;
  final AnimexScheduleLoader? loadSchedule;
  final DateTime Function()? now;

  const AnimeXSchedulePage({
    super.key,
    required this.controller,
    this.loadSchedule,
    this.now,
  });

  @override
  State<AnimeXSchedulePage> createState() => _AnimeXSchedulePageState();
}

class _AnimeXSchedulePageState extends State<AnimeXSchedulePage> {
  late int _day;
  List<AnimexScheduleEntry> _dayEntries = const [];
  // Null follows My List: it opens on My List while Clair has titles there
  // and on All anime when the list is empty. A tap on a chip makes it explicit.
  bool? _filterChoice;

  bool get _onlyMyList =>
      _filterChoice ??
      (widget.controller.libraryLoading ||
          widget.controller.library.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _day = (widget.now?.call() ?? DateTime.now()).toLocal().weekday - 1;
    widget.controller.addListener(_onLibraryChanged);
  }

  @override
  void didUpdateWidget(AnimeXSchedulePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onLibraryChanged);
      widget.controller.addListener(_onLibraryChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) setState(() {});
  }

  DateTime _clock() => (widget.now?.call() ?? DateTime.now()).toLocal();

  void _onEntries(List<AnimexScheduleEntry> entries) {
    if (!mounted) return;
    setState(() => _dayEntries = entries);
  }

  /// The next episode from the selected day that still has to air, honoring
  /// the current filter. Null when nothing is left on that day.
  AnimexScheduleEntry? get _nextUp {
    final library = widget.controller.library;
    final now = _clock();
    AnimexScheduleEntry? best;
    for (final entry in _dayEntries) {
      // The TMDB backup week carries dates only (airingAt is local
      // midnight), so it cannot promise a time or a countdown.
      if (!entry.hasExactTime) continue;
      if (_onlyMyList && !animexScheduleIsInLibrary(entry.media, library)) {
        continue;
      }
      if (!entry.airingAt.isAfter(now)) continue;
      if (best == null || entry.airingAt.isBefore(best.airingAt)) best = entry;
    }
    return best;
  }

  bool _isSaved(MediaItem media) =>
      animexScheduleIsInLibrary(media, widget.controller.library);

  /// One tap to save a show straight from the schedule, through the same
  /// optimistic path the rest of the anime section uses.
  Future<void> _toggleSaved(MediaItem media) async {
    // Pin the current view first: saving from this card must not flip the
    // whole page to My List under Clair's finger.
    _filterChoice ??= _onlyMyList;
    final userName = context.read<AuthService?>()?.currentUser ?? '';
    if (userName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save titles to My List.')),
      );
      return;
    }
    if (_isSaved(media)) {
      await widget.controller.optimisticRemoveFromLibrary(media, userName);
    } else {
      await widget.controller.optimisticAddToLibrary(media, userName);
    }
  }

  /// Date under each day tab, from the same week as the clock. Calendar
  /// arithmetic keeps local midnights across DST changes.
  DateTime _dateForDay(int index) {
    final now = _clock();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1) + index);
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextUp;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
      children: [
        Text(
          'Airing Schedule',
          style: bebasStyle(size: 32, color: AnimeXTokens.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          "This week's anime broadcasts",
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        if (next != null) ...[
          const SizedBox(height: 16),
          _NextUpCard(
            entry: next,
            clock: _clock,
            // Tick only against the real clock: a fixed clock (tests) renders
            // a static countdown and schedules no timers.
            live: widget.now == null,
            saved: _isSaved(next.media),
            onToggleSaved: () => _toggleSaved(next.media),
            onExpired: () {
              // The episode just aired: let the page pick the next one
              // instead of freezing this card on "Airing now".
              if (mounted) setState(() {});
            },
            onTap: () => widget.controller.openWatch(next.media),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('My List'),
              selected: _onlyMyList,
              onSelected: (_) => setState(() => _filterChoice = true),
            ),
            ChoiceChip(
              label: const Text('All anime'),
              selected: !_onlyMyList,
              onSelected: (_) => setState(() => _filterChoice = false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDayTabs(),
        const SizedBox(height: 24),
        AnimeXScheduleList(
          // Stable key: the NEXT UP card above appears and disappears, which
          // shifts this child's slot. Without a key Flutter rebuilds the list
          // from scratch and refetches the day.
          key: const ValueKey('animex-schedule-list'),
          controller: widget.controller,
          weekday: _day,
          onlyMyList: _onlyMyList,
          loadSchedule: widget.loadSchedule,
          now: widget.now,
          onEntries: _onEntries,
        ),
        const SizedBox(height: 24),
        AnimeXFooter(controller: widget.controller),
      ],
    );
  }

  Widget _buildDayTabs() {
    return Row(
      children: [
        for (var i = 0; i < _days.length; i++)
          Expanded(
            child: Semantics(
              selected: i == _day,
              child: Tooltip(
                message: _days[i].$2,
                child: TextButton(
                  onPressed: () => setState(() {
                    // Re-tapping the selected day must not clear the card:
                    // the day never changes, so the list never refetches.
                    if (i == _day) return;
                    _day = i;
                    // Never show the previous day's "next up" while the new
                    // day loads.
                    _dayEntries = const [];
                  }),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    padding: EdgeInsets.zero,
                    foregroundColor: i == _day
                        ? AnimeXTokens.accent
                        : AnimeXTokens.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AnimeXTokens.radiusMd,
                      ),
                      side: BorderSide(
                        color: i == _day
                            ? AnimeXTokens.accent
                            : AnimeXTokens.border,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _days[i].$1,
                        style: dmSansStyle(
                          size: 12,
                          color: i == _day
                              ? AnimeXTokens.textPrimary
                              : AnimeXTokens.textSecondary,
                          weight: i == _day ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_dateForDay(i).day}',
                        style: dmSansStyle(
                          size: 10,
                          color: i == _day
                              ? AnimeXTokens.accentWarm
                              : AnimeXTokens.textSecondary,
                          weight: i == _day ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Next up" summary for the selected day: poster, episode, local time and a
/// countdown. Ticks only when [live], so a fixed clock in tests renders a
/// static countdown and schedules no timers.
class _NextUpCard extends StatefulWidget {
  final AnimexScheduleEntry entry;
  final DateTime Function() clock;
  final bool live;
  final bool saved;
  final VoidCallback onToggleSaved;

  /// The countdown reached zero. The page decides what follows.
  final VoidCallback onExpired;
  final VoidCallback onTap;

  const _NextUpCard({
    required this.entry,
    required this.clock,
    required this.live,
    required this.saved,
    required this.onToggleSaved,
    required this.onExpired,
    required this.onTap,
  });

  @override
  State<_NextUpCard> createState() => _NextUpCardState();
}

class _NextUpCardState extends State<_NextUpCard> {
  Timer? _timer;
  String? _lastText;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_NextUpCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reused card with a new entry must tick again: the previous timer
    // cancelled itself when its own countdown hit zero.
    if (oldWidget.entry != widget.entry || oldWidget.live != widget.live) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    _lastText = null;
    if (!widget.live) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = widget.entry.airingAt.difference(widget.clock());
      if (remaining <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
        widget.onExpired();
        return;
      }
      // The text changes per minute above a minute, so an idle card must
      // not rebuild every second.
      final text = formatRemaining(remaining);
      if (text == _lastText) return;
      _lastText = text;
      setState(() {});
    });
  }

  /// Plain words instead of a raw clock: "in 3h 12m", "in 44m", "Airing now".
  static String formatRemaining(Duration d) {
    if (d <= Duration.zero) return 'Airing now';
    if (d.inDays >= 1) return 'in ${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return 'in ${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes >= 1) return 'in ${d.inMinutes}m';
    return 'in ${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final media = entry.media;
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(entry.airingAt.toLocal()));
    final remaining = formatRemaining(
      entry.airingAt.difference(widget.clock()),
    );
    final episode = entry.episode;
    return Material(
      color: AnimeXTokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
        side: BorderSide(color: AnimeXTokens.accent.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                child: SizedBox(
                  width: 52,
                  height: 72,
                  child: media.posterUrl.isEmpty
                      ? const ColoredBox(color: AnimeXTokens.surfaceRaised)
                      : AppNetworkImage(
                          imageUrl: media.posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                          errorWidget: const ColoredBox(
                            color: AnimeXTokens.surfaceRaised,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NEXT UP',
                      style: dmSansStyle(
                        size: 10,
                        color: AnimeXTokens.accent,
                        weight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dmSansStyle(size: 15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (episode != null) 'Episode $episode',
                        time,
                      ].join(' · '),
                      style: dmSansStyle(
                        size: 12,
                        color: AnimeXTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      remaining,
                      style: dmSansStyle(
                        size: 13,
                        color: AnimeXTokens.accentWarm,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: widget.saved ? 'In My List' : 'Add to My List',
                child: Semantics(
                  button: true,
                  label: widget.saved ? 'In My List' : 'Add to My List',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onToggleSaved,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          widget.saved
                              ? Icons.bookmark_added_rounded
                              : Icons.bookmark_add_outlined,
                          color: widget.saved
                              ? AnimeXTokens.accent
                              : AnimeXTokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
