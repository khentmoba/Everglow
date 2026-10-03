import 'package:flutter/material.dart';

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
  bool _onlyMyList = true;

  @override
  void initState() {
    super.initState();
    _day = (widget.now?.call() ?? DateTime.now()).toLocal().weekday - 1;
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
          "This week's broadcast dates in your local time",
          style: dmSansStyle(size: 13, color: AnimeXTokens.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('My List'),
              selected: _onlyMyList,
              onSelected: (_) => setState(() => _onlyMyList = true),
            ),
            ChoiceChip(
              label: const Text('All anime'),
              selected: !_onlyMyList,
              onSelected: (_) => setState(() => _onlyMyList = false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDayTabs(),
        const SizedBox(height: 24),
        AnimeXScheduleList(
          controller: widget.controller,
          weekday: _day,
          onlyMyList: _onlyMyList,
          loadSchedule: widget.loadSchedule,
          now: widget.now,
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
                  onPressed: () => setState(() => _day = i),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
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
                  child: Text(
                    _days[i].$1,
                    style: dmSansStyle(
                      size: 12,
                      color: i == _day
                          ? AnimeXTokens.textPrimary
                          : AnimeXTokens.textSecondary,
                      weight: i == _day ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
