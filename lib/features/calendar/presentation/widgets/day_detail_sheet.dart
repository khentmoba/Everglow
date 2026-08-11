import 'package:flutter/material.dart';import 'package:everglow/core/theme/app_theme.dart';
import '../../domain/models/calendar_event.dart';
import '../../data/services/calendar_service.dart';
import 'add_event_dialog.dart';
import 'package:everglow/core/theme/app_typography.dart';

class DayDetailSheet extends StatefulWidget {
  final DateTime day;
  final VoidCallback onEventAdded;

  const DayDetailSheet({
    super.key,
    required this.day,
    required this.onEventAdded,
  });

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  final CalendarService _calendarService = CalendarService();

  @override
  Widget build(BuildContext context) {
    final dayLabel =
        "${_monthNames[widget.day.month]} ${widget.day.day}, ${widget.day.year}";

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.velvet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: AppTheme.blushGold.withValues(alpha: 0.65),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.blushGold.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      dayLabel,
                      style: AppTypography.cormorantBold.copyWith(fontSize: 20),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await showDialog<bool>(
                          context: context,
                          barrierColor: Colors.transparent,
                          builder: (_) => AddEventDialog(
                            selectedDay: widget.day,
                          ),
                        );
                        if (result == true) widget.onEventAdded();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.deepRose.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppTheme.petalWhite,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Events list
              Expanded(
                child: StreamBuilder<List<CalendarEvent>>(
                  stream: _calendarService.getEventsForMonth(widget.day),
                  builder: (context, snapshot) {
                    final allEvents = snapshot.data ?? [];
                    final dayEvents = allEvents
                        .where((e) =>
                            e.date.year == widget.day.year &&
                            e.date.month == widget.day.month &&
                            e.date.day == widget.day.day)
                        .toList();

                    if (dayEvents.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 40,
                              color:
                                  AppTheme.blushGold.withValues(alpha: 0.65),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "No events this day",
                              style: AppTypography.outfitWhite.copyWith(fontSize: 14, color: AppTheme.petalWhite
                                    .withValues(alpha: 0.4)),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                final result = await showDialog<bool>(
                                  context: context,
                                  barrierColor: Colors.transparent,
                                  builder: (_) => AddEventDialog(
                                    selectedDay: widget.day,
                                  ),
                                );
                                if (result == true) widget.onEventAdded();
                              },
                              child: Text(
                                "Add one",
                                style: AppTypography.outfitWhite.copyWith(color: AppTheme.blushGold, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: dayEvents.length,
                      itemBuilder: (context, index) {
                        return _EventTile(
                          event: dayEvents[index],
                          onDelete: () async {
                            await _calendarService
                                .deleteEvent(dayEvents[index].id);
                            widget.onEventAdded(); // triggers refresh
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onDelete;

  const _EventTile({required this.event, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final info = calendarEventTypeInfo[event.type] ??
        ('📌', event.type.name);

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.deepRose.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.petalWhite,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.twilight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _eventColor(event.type).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _eventColor(event.type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  info.$1,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.outfitWhite.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.petalWhite),
                  ),
                  if (event.description.isNotEmpty)
                    Text(
                      event.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.7)),
                    ),
                ],
              ),
            ),
            if (event.recurring != 'none')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.softLavender.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.recurring == 'yearly' ? '🔄 Yearly' : '🔄 Monthly',
                  style: AppTypography.outfitWhite.copyWith(fontSize: 9, color: AppTheme.softLavender),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _eventColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.dateNight:
        return AppTheme.deepRose;
      case CalendarEventType.anniversary:
        return AppTheme.blushGold;
      case CalendarEventType.reminder:
        return AppTheme.softLavender;
      case CalendarEventType.custom:
        return AppTheme.roseQuartz;
    }
  }
}
