// Port of lib/features/chat/data/services/chat_service.dart + domain/models/chat_message.dart.
import {
  addDoc,
  collection,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
  where,
} from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { AgentFixtures, type ChatMessageFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { just, snapshots, withFirestoreTimeout, withGetTimeout, type Source } from '../../core/utils/liveSource';

export type ChatMessage = ChatMessageFixture & {
  isOptimistic?: boolean;
  isFailed?: boolean;
};

function parseTimestamp(v: unknown): Date {
  if (v && typeof (v as Timestamp).toDate === 'function') return (v as Timestamp).toDate();
  if (typeof v === 'number') return new Date(v);
  if (typeof v === 'string') {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d;
  }
  return new Date();
}

function monthDay(d: Date): string {
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${m}-${day}`;
}

function fromDoc(id: string, data: DocumentData): ChatMessage {
  return {
    id,
    sender: String(data.sender ?? ''),
    senderUid: String(data.senderUid ?? ''),
    text: String(data.text ?? ''),
    timestamp: parseTimestamp(data.timestamp),
  };
}

class ChatService {
  /** getMessagesStream: the newest 50, oldest first. Agent mode shows the demo chat. */
  watchMessages(): Source<ChatMessage[]> {
    if (AgentMode.demo) return just(AgentFixtures.demoChatMessages());
    const q = query(collection(db, 'sanctuary_messages'), orderBy('timestamp', 'desc'), limit(50));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, ChatMessage[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) => {
          const messages: ChatMessage[] = [];
          for (const d of s.docs) {
            try {
              messages.push(fromDoc(d.id, d.data()));
            } catch (e) {
              Logger.e(`Error parsing message document ${d.id}`, e);
            }
          }
          return messages.reverse();
        },
      ),
      { label: 'sanctuary-chat' },
    );
  }

  async sendMessage(text: string, sender: string, senderUid: string): Promise<void> {
    if (text.trim() === '') return;
    if (AgentMode.demo) {
      Logger.i(`Agent session simulated chat send: ${text}`);
      return;
    }
    await addDoc(collection(db, 'sanctuary_messages'), {
      sender,
      senderUid,
      text: text.trim(),
      timestamp: serverTimestamp(),
      monthDay: monthDay(new Date()),
    });
  }

  /** Messages sent on today's date in earlier years (On This Day). */
  async getMessagesFromThisDay(): Promise<ChatMessage[]> {
    if (AgentMode.demo) return [];
    const now = new Date();
    try {
      const col = collection(db, 'sanctuary_messages');
      let snap = await withGetTimeout(
        getDocs(query(col, where('monthDay', '==', monthDay(now)), limit(100))),
        'chat on-this-day',
      );
      if (snap.empty) {
        snap = await withGetTimeout(getDocs(query(col, orderBy('timestamp', 'desc'), limit(200))), 'chat on-this-day fallback');
      }
      return snap.docs
        .map((d) => fromDoc(d.id, d.data()))
        .filter(
          (m) =>
            m.timestamp.getMonth() === now.getMonth() &&
            m.timestamp.getDate() === now.getDate() &&
            m.timestamp.getFullYear() !== now.getFullYear(),
        );
    } catch (e) {
      Logger.e('Error getting on-this-day messages', e);
      return [];
    }
  }
}

export const chatService = new ChatService();
