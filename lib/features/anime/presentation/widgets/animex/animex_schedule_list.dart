import 'package:flutter/material.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import '../../../../cinema/data/models/media_item.dart';
import '../../../data/models/animex_models.dart';
import '../../../data/services/anilist_service.dart';
import 'animex_badges.dart';
import 'animex_controller.dart';
import 'animex_tokens.dart';

/// Weekday is 0 = Monday .. 6 = Sunday, as in AniListService.
typedef AnimexScheduleLoader =
    Future<List<AnimexScheduleEntry>> Function(int weekday);

/// AniList IDs take precedence. Only Jikan-sourced tmdbId values are MAL IDs;
/// a TMDB number must never accidentally match a MAL or AniList number.
bool animexScheduleIsInLibrary(MediaItem media, Iterable<MediaItem> library) {
  return library.any((item) {
    final id = media.anilistId;
    final otherId = item.anilistId;
    if (id != null && id > 0 && otherId != null && otherId > 0) {
      return id == otherId;
    }
    return media.source == 'jikan' &&
        item.source == 'jikan' &&
        media.tmdbId > 0 &&
        media.tmdbId == item.tmdbId;
  });
}

/// Broadcast status only — never a claim that a server can play the episode.
String animexAiringLabel(DateTime airingAt, DateTime now) {
  final local = airingAt.toLocal();
  final today = now.toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  if (!airingAt.isAfter(now)) return sameDay ? 'Aired today' : 'Aired';
  if (!sameDay) return 'Airs';
  return local.hour >= 18 ? 'Airs tonight' : 'Airs today';
}

/// Shared by the schedule page and a small home teaser. Reads My List live
/// from the controller, including removals and profile switches; never caches
/// personal matches. The optional loader/clock keep widget tests offline.
class AnimeXScheduleList extends StatefulWidget {
  final AnimeXController controller;
  final int weekday;
  final bool onlyMyList;
  final int? maxEntries;
  final AnimexScheduleLoader? loadSchedule;
  final DateTime Function()? now;

  const AnimeXScheduleList({
    super.key,
    required this.controller,
    required this.weekday,
    this.onlyMyList = true,
    this.maxEntries,
    this.loadSchedule,
    this.now,
  }) : assert(weekday >= 0 && weekday < 7),
       assert(maxEntries == null || maxEntries > 0);

  @override
  State<AnimeXScheduleList> createState() => _AnimeXScheduleListState();
}

class _AnimeXScheduleListState extends State<AnimeXScheduleList> {
  List<AnimexScheduleEntry> _entries = [];
  bool _loading = true;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(AnimeXScheduleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekday != widget.weekday ||
        oldWidget.loadSchedule != widget.loadSchedule) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
      _entries = [];
    });
    try {
      final entries =
          await (widget.loadSchedule?.call(widget.weekday) ??
              AniListService().fetchAiringSchedule(weekday: widget.weekday));
      if (!mounted || request != _request) return;
      setState(() {
        _entries = [...entries]
          ..sort((a, b) => a.airingAt.compareTo(b.airingAt));
        _loading = false;
      });
    } catch (e, stack) {
      if (!mounted || request != _request) return;
      Logger.e('[AnimeXSchedule] fetch failed', error: e, stackTrace: stack);
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final library = widget.controller.library;
        final entries = _entries.where(
          (entry) =>
              !widget.onlyMyList ||
              animexScheduleIsInLibrary(entry.media, library),
        );
        final visible = widget.maxEntries == null
            ? entries
            : entries.take(widget.maxEntries!);
        final now = widget.now?.call() ?? DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.onlyMyList ? 'New episodes from your list' : 'All anime',
              style: dmSansStyle(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Broadcast times only — aired does not mean playable.',
              style: dmSansStyle(size: 12, color: AnimeXTokens.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_loading ||
                (!_failed &&
                    _entries.isNotEmpty &&
                    widget.onlyMyList &&
                    widget.controller.libraryLoading))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AnimeXTokens.accent,
                  ),
                ),
              )
            else if (_failed)
              _message('Could not load the airing schedule.', retry: true)
            // The service throws on failure (see _failed above), so an empty
            // response means no entries for the day — none scheduled, or
            // AniList has no data for it.
            else if (_entries.isEmpty)
              _message(
                'No schedule data for this day. It may be unavailable.',
                retry: true,
              )
            else if (visible.isEmpty)
              _message(
                library.isEmpty
                    ? 'Add anime to My List to see their broadcast dates here.'
                    : 'No airings from your list in this day’s schedule.',
              )
            else
              for (final entry in visible)
                _ScheduleRow(
                  entry: entry,
                  inMyList: animexScheduleIsInLibrary(entry.media, library),
                  now: now,
                  // Open details, not a promised playable episode.
                  onTap: () => widget.controller.openWatch(entry.media),
                ),
          ],
        );
      },
    );
  }

  Widget _message(String message, {bool retry = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
          ),
          if (retry)
            TextButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AnimeXTokens.accent),
            ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final AnimexScheduleEntry entry;
  final bool inMyList;
  final DateTime now;
  final VoidCallback onTap;

  const _ScheduleRow({
    required this.entry,
    required this.inMyList,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    final local = entry.airingAt.toLocal();
    final l10n = MaterialLocalizations.of(context);
    final date = l10n.formatMediumDate(local);
    final time = l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AnimeXTokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
          side: BorderSide(
            color: inMyList ? AnimeXTokens.accent : AnimeXTokens.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                  child: SizedBox(
                    width: 56,
                    height: 80,
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
                    children: [
                      Text(
                        media.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: dmSansStyle(
                          size: 13.5,
                          weight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          AnimeXBadge(
                            label: 'EP ${entry.episode}',
                            kind: AnimeXBadgeKind.episodes,
                          ),
                          if (inMyList)
                            const AnimeXBadge(
                              label: 'My List',
                              kind: AnimeXBadgeKind.newBadge,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${animexAiringLabel(entry.airingAt, now)} · $date',
                        style: dmSansStyle(
                          size: 12,
                          color: AnimeXTokens.accent,
                        ),
                      ),
                      Text(
                        '$time local time',
                        style: dmSansStyle(
                          size: 11,
                          color: AnimeXTokens.textSecondary,
                        ),
                      ),
                    ],
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
