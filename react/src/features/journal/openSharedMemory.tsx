// Port of lib/features/journal/presentation/widgets/open_shared_memory.dart.
import { authService } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { showAddJournalEntryDialog } from './AddJournalEntryDialog';
import { showJournalDetailSheet } from './JournalDetailSheet';
import { journalService } from './journalService';

export const COUPLE_USERS = new Set(['khentsgdz', 'clairjassen']);

export async function openSharedMemory(source: {
  title: string;
  date: Date;
  bucketItemId?: string;
  calendarEventId?: string;
  photoId?: string;
}): Promise<void> {
  const username = authService.currentUser;
  if (username == null || !COUPLE_USERS.has(username)) return;
  try {
    const entry = await journalService.memoryForSource({ ...source, author: username });
    await showJournalDetailSheet({
      entry,
      onEdit: (close) => {
        close();
        void showAddJournalEntryDialog(username, entry);
      },
    });
  } catch (e) {
    Logger.e('Could not open shared memory', e);
    showSnackBar('Could not open this memory. Please try again.');
  }
}
