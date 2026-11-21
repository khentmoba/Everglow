// Port of lib/features/watch_party/data/services/temporary_chat_service.dart.
import {
  addDoc,
  collection,
  doc,
  getDocs,
  limit,
  limitToLast,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  writeBatch,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { snapshots, withGetTimeout, type Source } from '../../core/utils/liveSource';

export interface TemporaryChatMessage {
  id: string;
  sender: string;
  senderUid: string;
  text: string;
  timestamp: Date;
}

const COLLECTION = 'temporary_chats';

/** `WatchPartyRoom.buildRoomId`: the two uids sorted and joined. */
export function buildCoupleRoomId(a: string, b: string): string {
  const sorted = [a, b].sort();
  return `${sorted[0]}_${sorted[1]}`;
}

export async function ensureTemporaryChatRoom(roomId: string, myUid: string, partnerUid: string): Promise<void> {
  if (!roomId || !myUid || !partnerUid || AgentMode.demo) return;
  try {
    await setDoc(doc(db, COLLECTION, roomId), { hostUid: myUid, partnerUid, updatedAt: serverTimestamp() }, { merge: true });
  } catch (e) {
    Logger.w(`TemporaryChatService.ensureRoom failed: ${e}`);
  }
}

/**
 * Oldest first, the last 200. Agent mode has no temporary chat: Flutter's read is
 * refused there, so the panel shows its "unavailable" state.
 */
export function temporaryChatStream(roomId: string): Source<TemporaryChatMessage[]> {
  if (!roomId) {
    return (l) => {
      queueMicrotask(() => l.data([]));
      return () => {};
    };
  }
  if (AgentMode.demo) {
    return (l) => {
      queueMicrotask(() => l.error?.(new Error('permission-denied')));
      return () => {};
    };
  }
  const q = query(collection(db, COLLECTION, roomId, 'messages'), orderBy('timestamp'), limitToLast(200));
  return snapshots<QuerySnapshot<DocumentData>, TemporaryChatMessage[]>(
    (next, error) =>
      onSnapshot(q, next, (e) => {
        Logger.w(`TemporaryChatService stream error: ${e}`);
        error(e);
      }),
    (s) =>
      s.docs.map((d) => {
        const data = d.data();
        const ts = data.timestamp as Timestamp | null | undefined;
        return {
          id: d.id,
          sender: typeof data.sender === 'string' ? data.sender : '',
          senderUid: typeof data.senderUid === 'string' ? data.senderUid : '',
          text: typeof data.text === 'string' ? data.text : '',
          timestamp: ts && typeof ts.toDate === 'function' ? ts.toDate() : new Date(),
        };
      }),
  );
}

export async function sendTemporaryChatMessage(roomId: string, text: string, sender: string, senderUid: string) {
  if (!roomId) throw new Error('TemporaryChatService.sendMessage: empty roomId');
  const trimmed = text.trim();
  if (!trimmed) return;
  const now = new Date();
  await addDoc(collection(db, COLLECTION, roomId, 'messages'), {
    sender,
    senderUid,
    text: trimmed,
    timestamp: serverTimestamp(),
    monthDay: `${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`,
  });
}

export async function clearTemporaryChat(roomId: string): Promise<void> {
  if (!roomId) return;
  const messagesCol = collection(db, COLLECTION, roomId, 'messages');
  while (true) {
    const snap = await withGetTimeout(getDocs(query(messagesCol, limit(450))), 'temporary chat clear scan');
    if (snap.empty) break;
    const batch = writeBatch(db);
    for (const d of snap.docs) batch.delete(d.ref);
    await batch.commit();
    if (snap.docs.length < 450) break;
  }
}
