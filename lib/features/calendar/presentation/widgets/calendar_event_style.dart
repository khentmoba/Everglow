import 'package:flutter/material.dart';

import 'package:everglow/core/theme/app_colors.dart';

import '../../domain/models/calendar_event.dart';

/// Accent hue used across calendar surfaces, keyed by event type.
Color calendarEventHue(CalendarEventType type) {
  switch (type) {
    case CalendarEventType.dateNight:
      return AppColors.auroraRose;
    case CalendarEventType.anniversary:
      return AppColors.blushGold;
    case CalendarEventType.reminder:
      return AppColors.auroraLilac;
    case CalendarEventType.custom:
      return AppColors.softLavender;
  }
}
