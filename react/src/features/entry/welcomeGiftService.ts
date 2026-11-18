// Clair's one-time welcome gift: users/{uid}/progress/welcome_gift (docs/WELCOME_GIFT.md).
import { doc, getDocFromServer, serverTimestamp, updateDoc } from 'firebase/firestore';
import { AgentMode } from '../../core/agent/agentMode';
import { DEMO_WELCOME_GIFT } from '../../core/agent/fixtures';
import { db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { withGetTimeout } from '../../core/utils/liveSource';

const MAX_HTML = 500_000;
let demoReceived = false;

const giftRef = (uid: string) => doc(db, 'users', uid, 'progress', 'welcome_gift');

/** The uid whose gift may show: Clair's real signed-in session, or the `?agent=gift` preview. */
export function giftRecipient(auth: {
  currentUser: string | null;
  uid: string | null;
  user: unknown;
  isAgentSession: boolean;
}): string | null {
  if (auth.currentUser !== 'clairjassen') return null;
  if (auth.isAgentSession) return AgentMode.giftPreview ? auth.uid : null;
  return auth.user != null ? auth.uid : null;
}

export async function pendingGiftHtml(uid: string): Promise<string | null> {
  if (AgentMode.isActive.value) return AgentMode.giftPreview && !demoReceived ? DEMO_WELCOME_GIFT : null;
  try {
    const snap = await withGetTimeout(getDocFromServer(giftRef(uid)), 'welcome gift');
    const data = snap.data();
    if (!data || data.enabled !== true || data.completedAt != null) return null;
    const html = data.html;
    if (typeof html !== 'string' || html.trim() === '' || html.length > MAX_HTML) {
      Logger.w('Welcome gift has no usable HTML.');
      return null;
    }
    return html;
  } catch (e) {
    Logger.e('Could not load welcome gift', e);
    return null;
  }
}

export async function completeGift(uid: string): Promise<void> {
  if (AgentMode.isActive.value) {
    demoReceived = true;
    return;
  }
  await withGetTimeout(updateDoc(giftRef(uid), { completedAt: serverTimestamp() }), 'welcome gift receipt');
}
