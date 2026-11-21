import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

export interface GlobalChatMessage {
  id: string;
  senderUid: string;
  senderName: string;
  text: string;
  createdAt: Date;
}

const now = Date.now();
let demoMessages: GlobalChatMessage[] = [
  {
    id: 'gc_1',
    senderUid: 'demo_khent',
    senderName: 'khentsgdz',
    text: 'Welcome to Everglow Global Chat! Drop movie recs or start a Watch Party anytime.',
    createdAt: new Date(now - 35 * 60_000),
  },
  {
    id: 'gc_2',
    senderUid: 'demo_octagram',
    senderName: 'octagram',
    text: 'Anyone up for an anime watch party later tonight?',
    createdAt: new Date(now - 18 * 60_000),
  },
  {
    id: 'gc_3',
    senderUid: 'demo_breyan',
    senderName: 'breyan',
    text: 'Count me in! Let us pick something on the Everglow server.',
    createdAt: new Date(now - 7 * 60_000),
  },
];

const demoChanges = new Changes<GlobalChatMessage[]>(() => [...demoMessages]);

export function watchGlobalChat(max = 100): Source<GlobalChatMessage[]> {
  if (AgentMode.demo) {
    return demoChanges.source;
  }
  const q = query(collection(db, 'global_chat_messages'), orderBy('createdAt', 'desc'), limit(max));
  return withFirestoreTimeout(
    snapshots<QuerySnapshot<DocumentData>, GlobalChatMessage[]>(
      (next, error) => onSnapshot(q, next, error),
      (snap) =>
        snap.docs
          .map((d) => {
            const data = d.data();
            const ts = data.createdAt as Timestamp | undefined;
            return {
              id: d.id,
              senderUid: String(data.senderUid ?? ''),
              senderName: String(data.senderName ?? 'member'),
              text: String(data.text ?? ''),
              createdAt: ts && typeof ts.toDate === 'function' ? ts.toDate() : new Date(),
            };
          })
          .reverse(),
    ),
    { label: 'global-chat' },
  );
}

export async function sendGlobalChatMessage(opts: {
  senderUid: string;
  senderName: string;
  text: string;
}): Promise<void> {
  const clean = opts.text.trim();
  if (!clean || !opts.senderUid || !opts.senderName) return;
  if (clean.length > 2000) {
    throw new Error('Message is too long (max 2000 characters).');
  }
  if (AgentMode.demo) {
    demoMessages = [
      ...demoMessages,
      {
        id: `gc_${Date.now()}`,
        senderUid: opts.senderUid,
        senderName: opts.senderName,
        text: clean,
        createdAt: new Date(),
      },
    ];
    demoChanges.emit();
    return;
  }
  await addDoc(collection(db, 'global_chat_messages'), {
    senderUid: opts.senderUid,
    senderName: opts.senderName,
    text: clean,
    createdAt: serverTimestamp(),
  });
}

export async function deleteGlobalChatMessage(messageId: string): Promise<void> {
  if (!messageId) return;
  if (AgentMode.demo) {
    demoMessages = demoMessages.filter((m) => m.id !== messageId);
    demoChanges.emit();
    return;
  }
  await deleteDoc(doc(db, 'global_chat_messages', messageId));
}
