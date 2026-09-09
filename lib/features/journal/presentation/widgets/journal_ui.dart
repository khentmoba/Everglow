import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/journal_entry.dart';

/// Shared look-and-feel helpers for the journal.
///
/// One place for category colors, author hues, and friendly date labels
/// so the list, cards, and reading sheet always agree.
Color journalCategoryColor(JournalCategory c) {
  switch (c) {
    case JournalCategory.daily:
      return AppColors.softLavender;
    case JournalCategory.gratitude:
      return AppColors.blushGold;
    case JournalCategory.memory:
      return AppColors.auroraTeal;
    case JournalCategory.letter:
      return AppColors.deepRose;
    case JournalCategory.dream:
      return AppColors.auroraLilac;
    case JournalCategory.idea:
      return AppColors.warmAmber;
  }
}

/// Avatar hue per author — teal for Khent, rose for Clair.
Color journalAuthorHue(String author) {
  switch (author.toLowerCase()) {
    case 'khentsgdz':
      return AppColors.auroraTeal;
    case 'clairjassen':
      return AppColors.auroraRose;
    default:
      return AppColors.softLavender;
  }
}

/// Display name per author — "Khent" / "Clair" instead of usernames.
String journalAuthorName(String author) {
  switch (author.toLowerCase()) {
    case 'khentsgdz':
      return 'Khent';
    case 'clairjassen':
      return 'Clair';
    default:
      if (author.isEmpty) return 'Us';
      return author[0].toUpperCase() + author.substring(1);
  }
}

String journalAuthorInitial(String author) {
  final name = journalAuthorName(author);
  return name.isEmpty ? '♥' : name[0].toUpperCase();
}

/// "Today" / "Yesterday" / "3d ago" / "Jun 12, 2026".
String journalRelativeDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '${diff}d ago';
  return DateFormat.yMMMd().format(d);
}

/// "a quick note" / "1 min read" / "4 min read".
String journalReadingTime(int words) {
  if (words <= 0) return 'a quick note';
  final mins = (words / 200).ceil().clamp(1, 999);
  return '$mins min read';
}

/// "July 2026" — month chapter headers.
String journalMonthLabel(DateTime d) => DateFormat.yMMMM().format(d);

/// Short day key (yyyy-MM-dd) for activity dots.
String journalDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
