import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_button.dart';
import '../../../../shared/widgets/everglow/everglow_icon_button.dart';
import '../../data/services/calendar_service.dart';
import '../../domain/models/calendar_event.dart';
import 'add_event_dialog.dart';
import 'calendar_event_style.dart';

class DayDetailSheet extends StatefulWidget {
  final DateTime day;
  final VoidCallback onEventAdded;
  final CalendarService? calendarService;
  final Stream<List<CalendarEvent>>? eventsStream;

  const DayDetailSheet({
    super.key,
    required this.day,
    required this.onEventAdded,
    this.calendarService,
    this.eventsStream,
  });

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  late final CalendarService _calendarService =
      widget.calendarService ?? CalendarService();

  Future<void> _openAddEvent(
    BuildContext context, [
    CalendarEventType initialType = CalendarEventType.custom,
  ]) async {
    Navigator.pop(context);
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => AddEventDialog(
        selectedDay: widget.day,
        initialType: initialType,
      ),
    );
    if (result == true) widget.onEventAdded();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final diffInDays = targetDay.difference(today).inDays;
    final isToday = diffInDays == 0;

    String relativeTag;
    if (diffInDays == 0) {
      relativeTag = 'Today';
    } else if (diffInDays == 1) {
      relativeTag = 'Tomorrow';
    } else if (diffInDays == -1) {
      relativeTag = 'Yesterday';
    } else if (diffInDays > 1 && diffInDays <= 7) {
      relativeTag = 'In $diffInDays days';
    } else {
      relativeTag = DateFormat('EEEE').format(widget.day);
    }

    final formattedDate = DateFormat('MMMM d, y').format(widget.day);

    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.38,
      maxChildSize: 0.88,
      expand: false,
      builder: (context, scrollController) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.velvet, AppColors.inkDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.x3),
                ),
                border: Border.all(
                  color: AppColors.blushGold.withValues(alpha: 0.28),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.inkDeep.withValues(alpha: 0.85),
                    blurRadius: 32,
                    offset: const Offset(0, -6),
                  ),
                  BoxShadow(
                    color: AppColors.deepRose.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Column(
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 6),
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppColors.petalWhite.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? AppColors.deepRose.withValues(
                                                alpha: 0.22,
                                              )
                                            : AppColors.moonlight.withValues(
                                                alpha: 0.08,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.full,
                                        ),
                                        border: Border.all(
                                          color: isToday
                                              ? AppColors.deepRose.withValues(
                                                  alpha: 0.5,
                                                )
                                              : AppColors.blushGold.withValues(
                                                  alpha: 0.22,
                                                ),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isToday) ...[
                                            const Icon(
                                              Icons.auto_awesome,
                                              size: 11,
                                              color: AppColors.auroraRose,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            relativeTag,
                                            style: AppTypography.outfitWhite
                                                .copyWith(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isToday
                                                      ? AppColors.roseQuartz
                                                      : AppColors.blushGold,
                                                  letterSpacing: 0.6,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE').format(widget.day),
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 12,
                                        color: AppColors.petalWhite.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: AppTypography.cormorantBoldWhite
                                      .copyWith(
                                        fontSize: 22,
                                        letterSpacing: 0.3,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              EverglowIconButton(
                                icon: Icons.add_rounded,
                                size: 40,
                                semanticLabel: 'Add event to this day',
                                tooltip: 'Add event',
                                backgroundColor: AppColors.deepRose.withValues(
                                  alpha: 0.75,
                                ),
                                borderColor: AppColors.roseQuartz.withValues(
                                  alpha: 0.35,
                                ),
                                iconColor: AppColors.petalWhite,
                                onPressed: () => _openAddEvent(context),
                              ),
                              const SizedBox(width: 8),
                              EverglowIconButton.close(
                                size: 36,
                                backgroundColor: AppColors.surfaceGlass,
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0x1AFFF5F5),
                    ),

                    // Events list or enhanced empty state
                    Expanded(
                      child: StreamBuilder<List<CalendarEvent>>(
                        stream: widget.eventsStream ??
                            _calendarService.getEventsForMonth(widget.day),
                        builder: (context, snapshot) {
                          final allEvents = snapshot.data ?? [];
                          final dayEvents = allEvents
                              .where(
                                (e) =>
                                    e.date.year == widget.day.year &&
                                    e.date.month == widget.day.month &&
                                    e.date.day == widget.day.day,
                              )
                              .toList();

                          if (dayEvents.isEmpty) {
                            return _EmptyDayView(
                              isToday: isToday,
                              scrollController: scrollController,
                              onAdd: () => _openAddEvent(context),
                              onAddType: (type) => _openAddEvent(context, type),
                            );
                          }

                          return ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: dayEvents.length,
                            itemBuilder: (context, index) {
                              return _EventTile(
                                event: dayEvents[index],
                                onDelete: () async {
                                  await _calendarService.deleteEvent(
                                    dayEvents[index].id,
                                  );
                                  widget.onEventAdded();
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyDayView extends StatelessWidget {
  final bool isToday;
  final ScrollController scrollController;
  final VoidCallback onAdd;
  final ValueChanged<CalendarEventType> onAddType;

  const _EmptyDayView({
    required this.isToday,
    required this.scrollController,
    required this.onAdd,
    required this.onAddType,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Layered glowing icon medallion
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.plum.withValues(alpha: 0.7),
                      AppColors.velvet,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.blushGold.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepRose.withValues(alpha: 0.22),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 32,
                    color: AppColors.blushGold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isToday ? "A quiet day together" : "No plans set for this day",
                style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Make it special with a romantic date, a sweet reminder, or an adventure to look forward to.",
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 13,
                  color: AppColors.petalWhite.withValues(alpha: 0.65),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              EverglowButton(
                label: 'Plan Something Special',
                icon: Icons.add_rounded,
                onPressed: onAdd,
              ),
              const SizedBox(height: AppSpacing.xl),
              // Quick suggestions
              Text(
                'QUICK ADD',
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.petalWhite.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _QuickTypeChip(
                    emoji: '🌹',
                    label: 'Date Night',
                    hue: AppColors.auroraRose,
                    onTap: () => onAddType(CalendarEventType.dateNight),
                  ),
                  _QuickTypeChip(
                    emoji: '🥂',
                    label: 'Anniversary',
                    hue: AppColors.blushGold,
                    onTap: () => onAddType(CalendarEventType.anniversary),
                  ),
                  _QuickTypeChip(
                    emoji: '⏰',
                    label: 'Reminder',
                    hue: AppColors.auroraLilac,
                    onTap: () => onAddType(CalendarEventType.reminder),
                  ),
                  _QuickTypeChip(
                    emoji: '✨',
                    label: 'Custom',
                    hue: AppColors.softLavender,
                    onTap: () => onAddType(CalendarEventType.custom),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTypeChip extends StatefulWidget {
  final String emoji;
  final String label;
  final Color hue;
  final VoidCallback onTap;

  const _QuickTypeChip({
    required this.emoji,
    required this.label,
    required this.hue,
    required this.onTap,
  });

  @override
  State<_QuickTypeChip> createState() => _QuickTypeChipState();
}

class _QuickTypeChipState extends State<_QuickTypeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.orZero(AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.hue.withValues(alpha: 0.22)
                : AppColors.twilight.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: _hovered
                  ? widget.hue.withValues(alpha: 0.6)
                  : widget.hue.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTypography.outfitWhite.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.hue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onDelete;

  const _EventTile({required this.event, required this.onDelete});

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.x2),
          side: BorderSide(
            color: AppColors.blushGold.withValues(alpha: 0.25),
          ),
        ),
        title: Text(
          'Delete Event',
          style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to remove "${event.title}" from your calendar?',
          style: AppTypography.outfitWhite.copyWith(
            fontSize: 13,
            color: AppColors.petalWhite.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.outfitWhite.copyWith(
                color: AppColors.petalWhite.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppTypography.outfitBold.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = calendarEventTypeInfo[event.type] ?? ('✨', event.type.name);
    final hue = calendarEventHue(event.type);

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.velvet,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.x2),
              side: BorderSide(
                color: AppColors.blushGold.withValues(alpha: 0.25),
              ),
            ),
            title: Text(
              'Delete Event',
              style: AppTypography.cormorantBoldWhite.copyWith(fontSize: 20),
            ),
            content: Text(
              'Are you sure you want to remove "${event.title}"?',
              style: AppTypography.outfitWhite.copyWith(
                fontSize: 13,
                color: AppColors.petalWhite.withValues(alpha: 0.8),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: AppTypography.outfitWhite.copyWith(
                    color: AppColors.petalWhite.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Delete',
                  style: AppTypography.outfitBold.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.deepRose.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.petalWhite,
          size: 24,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.twilight.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: hue.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: hue.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    hue.withValues(alpha: 0.25),
                    hue.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: hue.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  info.$1,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.outfitBold.copyWith(
                      fontSize: 15,
                      color: AppColors.petalWhite,
                    ),
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.outfitWhite.copyWith(
                        fontSize: 12,
                        color: AppColors.petalWhite.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.moonlight.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color:
                                  AppColors.petalWhite.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              event.isAllDay
                                  ? 'All day'
                                  : DateFormat.jm().format(event.date),
                              style: AppTypography.outfitWhite.copyWith(
                                fontSize: 10.5,
                                color: AppColors.petalWhite.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (event.location != null &&
                          event.location!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.auroraTeal.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 11,
                                color: AppColors.auroraTeal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                event.location!,
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.auroraTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (event.attendees.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blushGold.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_alt_rounded,
                                size: 11,
                                color: AppColors.blushGold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                event.attendees.join(', '),
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.blushGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (event.recurring != 'none')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softLavender.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.repeat_rounded,
                                size: 11,
                                color: AppColors.softLavender,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                event.recurring == 'yearly'
                                    ? 'Yearly'
                                    : 'Monthly',
                                style: AppTypography.outfitWhite.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.softLavender,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EverglowIconButton(
              icon: Icons.delete_outline_rounded,
              size: 34,
              semanticLabel: 'Delete event',
              tooltip: 'Delete',
              backgroundColor: Colors.transparent,
              borderColor: Colors.transparent,
              iconColor: AppColors.petalWhite.withValues(alpha: 0.45),
              onPressed: () => _handleDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}
