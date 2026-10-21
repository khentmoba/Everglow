import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/logger.dart';
import '../../data/services/journal_service.dart';
import 'add_journal_entry_dialog.dart';
import 'journal_detail_sheet.dart';

Future<void> openSharedMemory(
  BuildContext context, {
  required String title,
  required DateTime date,
  String? bucketItemId,
  String? calendarEventId,
  String? photoId,
}) async {
  final username = context.read<AuthService>().currentUser;
  if (username == null || !{'khentsgdz', 'clairjassen'}.contains(username)) {
    return;
  }
  try {
    final entry = await JournalService().memoryForSource(
      title: title,
      author: username,
      date: date,
      bucketItemId: bucketItemId,
      calendarEventId: calendarEventId,
      photoId: photoId,
    );
    if (!context.mounted) return;
    await showJournalDetailSheet(
      context: context,
      entry: entry,
      onEdit: () async {
        Navigator.pop(context);
        await showDialog<void>(
          context: context,
          builder: (_) =>
              AddJournalEntryDialog(author: username, existing: entry),
        );
      },
    );
  } catch (e) {
    Logger.e('Could not open shared memory', error: e);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this memory. Please try again.'),
        ),
      );
    }
  }
}
