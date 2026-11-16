// Port of lib/features/chat/data/services/chat_service.dart + domain/models/chat_message.dart.
import {
  addDoc,
  collection,
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
import { AgentFixtures, type ChatMessageFixture } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Changes, snapshots, withFirestoreTimeout, type Source } from '../../core/utils/liveSource';

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

class ChatService {
  private demoMessages: ChatMessage[] | null = null;
  private demoChanges = new Changes(() => [...(this.demoMessages ?? AgentFixtures.demoChatMessages())]);

  watchMessages(max = 100): Source<ChatMessage[]> {
    if (AgentMode.demo) {
      if (!this.demoMessages) {
        this.demoMessages = AgentFixtures.demoChatMessages();
      }
      return this.demoChanges.source;
    }
    const q = query(collection(db, 'sanctuary_messages'), orderBy('timestamp', 'desc'), limit(max));
    return withFirestoreTimeout(
      snapshots<QuerySnapshot<DocumentData>, ChatMessage[]>(
        (next, error) => onSnapshot(q, next, error),
        (s) =>
          s.docs
            .map((d) => {
              const data = d.data();
              return {
                id: d.id,
                sender: String(data.sender ?? ''),
                senderUid: String(data.senderUid ?? ''),
                text: String(data.text ?? ''),
                timestamp: parseTimestamp(data.timestamp),
              };
            })
            .reverse(),
      ),
      { label: 'sanctuary-messages' },
    );
  }

  async sendMessage(text: string, sender: string, senderUid: string): Promise<void> {
    if (!text.trim()) return;
    if (AgentMode.demo) {
      const current = this.demoMessages ?? AgentFixtures.demoChatMessages();
      this.demoMessages = [
        ...current,
        {
          id: `demo_msg_${Date.now()}`,
          sender,
          senderUid,
          text,
          timestamp: new Date(),
        },
      ];
      this.demoChanges.emit();
      return;
    }
    const now = new Date();
    await addDoc(collection(db, 'sanctuary_messages'), {
      sender,
      senderUid,
      text,
      timestamp: serverTimestamp(),
      monthDay: monthDay(now),
    });
  }
}

export const chatService = new ChatService();
