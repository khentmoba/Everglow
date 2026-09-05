import 'package:flutter/material.dart';
import '../../../../../shared/widgets/app_network_image.dart';
import 'package:provider/provider.dart';

import '../../../data/models/animex_models.dart';
import '../../../data/services/anilist_service.dart';
import '../../../data/services/animex_stores.dart';

import 'animex_badges.dart';
import 'animex_controller.dart';
import 'animex_footer.dart';
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

/// Weekly airing schedule: day tabs plus the day's episode list with
/// airing times and per-title notification bells.
class AnimeXSchedulePage extends StatefulWidget {
  final AnimeXController controller;

  const AnimeXSchedulePage({super.key, required this.controller});

  @override
  State<AnimeXSchedulePage> createState() => _AnimeXSchedulePageState();
}

class _AnimeXSchedulePageState extends State<AnimeXSchedulePage> {
  final AniListService _aniList = AniListService();
  int _day = DateTime.now().weekday - 1;
  List<AnimexScheduleEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final entries = await _aniList.fetchAiringSchedule(weekday: _day);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[AnimeXSchedule] fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _entries = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          "See what's airing this week — all 7 days",
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        const SizedBox(height: 20),
        _buildDayTabs(),
        const SizedBox(height: 24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AnimeXTokens.accent,
                ),
              ),
            ),
          )
        else if (_entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'Nothing airing on this day',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 13,
                  color: AnimeXTokens.textSecondary,
                ),
              ),
            ),
          )
        else
          ..._entries.map(
            (e) => _ScheduleRow(
              entry: e,
              onTap: () => widget.controller.openWatch(e.media),
            ),
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
            child: GestureDetector(
              onTap: () {
                _day = i;
                _fetch();
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == _day
                            ? AnimeXTokens.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _days[i].$1,
                        style: dmSansStyle(
                          size: 12.5,
                          color: i == _day
                              ? AnimeXTokens.textPrimary
                              : AnimeXTokens.textSecondary,
                          weight: i == _day ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _days[i].$2,
                        style: dmSansStyle(
                          size: 9.5,
                          color: i == _day
                              ? AnimeXTokens.accent
                              : AnimeXTokens.textMuted,
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

class _ScheduleRow extends StatelessWidget {
  final AnimexScheduleEntry entry;
  final VoidCallback onTap;

  const _ScheduleRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final media = entry.media;
    final time =
        '${entry.airingAt.hour.toString().padLeft(2, '0')}:${entry.airingAt.minute.toString().padLeft(2, '0')}';
    final alertKey =
        'schedule-${media.anilistId ?? media.tmdbId}-${entry.episode}';
    final alert = context.select<AnimexStores, bool>(
      (stores) => stores.isAlertEnabled(alertKey),
    );

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AnimeXTokens.radiusLg),
            border: Border.all(color: AnimeXTokens.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AnimeXTokens.radiusMd),
                child: SizedBox(
                  width: 56,
                  height: 80,
                  child: media.posterUrl.isEmpty
                      ? Container(color: AnimeXTokens.surfaceRaised)
                      : AppNetworkImage(
                          imageUrl: media.posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 150,
                          errorWidget: Container(
                            color: AnimeXTokens.surfaceRaised,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
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
                        color: AnimeXTokens.textPrimary,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        AnimeXBadge(
                          label: 'EP ${entry.episode}',
                          kind: AnimeXBadgeKind.episodes,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AnimeXTokens.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AnimeXTokens.radiusSm,
                            ),
                          ),
                          child: Text(
                            time,
                            style: dmSansStyle(
                              size: 11,
                              color: AnimeXTokens.accent,
                              weight: FontWeight.w700,
                              letterSpacing: 0.04,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: alert ? 'Remove notification' : 'Notify me',
                child: GestureDetector(
                  onTap: () =>
                      context.read<AnimexStores>().toggleAlert(alertKey),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: alert
                          ? AnimeXTokens.accent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: alert
                            ? AnimeXTokens.accent.withValues(alpha: 0.4)
                            : AnimeXTokens.border,
                      ),
                    ),
                    child: Icon(
                      alert
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      size: 17,
                      color: alert
                          ? AnimeXTokens.accent
                          : AnimeXTokens.textSecondary,
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
