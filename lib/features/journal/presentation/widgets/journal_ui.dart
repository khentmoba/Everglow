import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/journal_entry.dart';

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

String journalReadingTime(int words) {
  if (words <= 0) return 'a quick note';
  final mins = (words / 200).ceil().clamp(1, 999);
  return '$mins min read';
}

String journalMonthLabel(DateTime d) => DateFormat.yMMMM().format(d);

String journalNumberFormat(int n) => NumberFormat('#,###').format(n);

String journalDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
