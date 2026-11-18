// Port of lib/features/ai/data/services/ai_service.dart.
import { AgentMode } from '../../core/agent/agentMode';
import { auth } from '../../core/services/firebase';

/** `_cloudFunctionUrl` on web: the proxyAI v2 helper. */
export const AI_PROXY_URL = 'https://proxyaiv2-6pr4gqobxa-uc.a.run.app';

export type CompanionState = {
  preferences: CompanionPreferences;
  feedback: Record<string, unknown>[];
};
export type CompanionPreferences = { nudges: string; digests: boolean; quietStart: number; quietEnd: number };

const demoCompanions = new Map<string, CompanionState>();

async function token(): Promise<string> {
  return (await auth.currentUser?.getIdToken()) ?? '';
}

async function postWithTimeout(body: unknown, ms: number): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(AI_PROXY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${await token()}` },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
}

/** Loads or saves Motchi's companion settings (`load`, `preferences`, `feedback`). */
export async function companionOperation(operation: string, value?: Record<string, unknown>): Promise<CompanionState> {
  if (AgentMode.isActive.value) {
    const profile = AgentMode.activeProfile.value;
    let demo = demoCompanions.get(profile);
    if (!demo) {
      demo = { preferences: { nudges: 'daily', digests: true, quietStart: 22, quietEnd: 8 }, feedback: [] };
      demoCompanions.set(profile, demo);
    }
    if (operation === 'preferences') demo.preferences = value as CompanionPreferences;
    if (operation === 'feedback') {
      demo.feedback.push({ ...value });
      if (demo.feedback.length > 20) demo.feedback.shift();
    }
    return demo;
  }
  const response = await postWithTimeout({ companionOperation: operation, ...(value ? { value } : {}) }, 20000);
  if (response.status !== 200) throw new Error('Could not save your Motchi preferences. Try again.');
  return (await response.json()) as CompanionState;
}

export async function quickAsk(message: string, systemPrompt?: string): Promise<string> {
  if (AgentMode.isActive.value) return '';
  const response = await postWithTimeout(
    {
      ...(systemPrompt ? { systemPrompt } : {}),
      messages: [{ role: 'user', content: message }],
    },
    30000,
  );
  if (response.status !== 200) return '';
  const data = (await response.json()) as { reply?: unknown };
  return typeof data.reply === 'string' ? data.reply.trim() : '';
}
