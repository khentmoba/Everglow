// Ports of lib/features/ai/domain: motchi_reply_details.dart, models/ai_conversation.dart
// and motchi_quality.dart.

export type Json = Record<string, unknown>;

export type ReplyDetails = {
  memories: Json[];
  steps: Json[];
  interrupted: boolean;
  recommendations: Json[];
};

export const emptyDetails = (): ReplyDetails => ({ memories: [], steps: [], interrupted: false, recommendations: [] });

export const detailsEmpty = (d: ReplyDetails) =>
  d.memories.length === 0 && d.steps.length === 0 && d.recommendations.length === 0 && !d.interrupted;

const needsAction = (step: Json) => step.status !== 'done' && (step.write !== false || step.status === 'unknown');

export function detailsNeedAttention(d: ReplyDetails): boolean {
  if (d.steps.some(needsAction)) return true;
  if (!d.interrupted) return false;
  return d.steps.length === 0 || d.steps.some((s) => s.write !== false);
}

export function detailsSummary(d: ReplyDetails): string {
  if (d.interrupted) return 'Stopped before finishing — check the steps below.';
  if (d.steps.some((s) => s.status === 'unknown' && needsAction(s))) {
    return 'Some actions could not be confirmed. Check before trying again.';
  }
  if (d.steps.some((s) => needsAction(s) && (s.status === 'failed' || s.status === 'unscheduled'))) {
    return 'Some steps still need attention.';
  }
  if (d.steps.some((s) => s.status === 'waiting')) return 'Waiting for your choice or confirmation.';
  if (d.steps.length > 0 && !d.steps.some((s) => s.write === true)) return 'Information found — nothing saved yet.';
  return 'Here is what happened.';
}

export function detailsToJson(d: ReplyDetails): Json {
  return {
    memories: d.memories,
    steps: d.steps,
    interrupted: d.interrupted,
    ...(d.recommendations.length > 0 ? { recommendations: d.recommendations } : {}),
  };
}

const records = (value: unknown): Json[] =>
  Array.isArray(value) ? value.filter((v) => v && typeof v === 'object' && !Array.isArray(v)).map((v) => ({ ...v })) : [];

export function detailsFromJson(json: Json): ReplyDetails {
  return {
    memories: records(json.memories),
    steps: records(json.steps),
    interrupted: json.interrupted === true,
    recommendations: records(json.recommendations),
  };
}

export function detailsFromResults(results: Json[], interrupted = false, activeTools: string[] = []): ReplyDetails {
  const finalDetails = [...results].reverse().find((r) => r.tool === 'reply_details');
  const details = finalDetails ? detailsFromJson(finalDetails) : emptyDetails();
  const steps = [...details.steps];
  if (!finalDetails) {
    for (const result of results.filter((r) => r.step && typeof r.step === 'object')) {
      const step = { ...(result.step as Json) };
      const pending = steps.findIndex(
        (s) => s.status === 'waiting' && s.tool === step.tool && `${s.target ?? ''}` !== '' && s.target === step.target,
      );
      if (pending >= 0) steps[pending] = step;
      else steps.push(step);
    }
  }
  if (interrupted) for (const tool of activeTools) steps.push({ tool, status: 'unknown', title: '' });
  return {
    memories: details.memories,
    steps,
    interrupted: interrupted || details.interrupted,
    recommendations: details.recommendations,
  };
}

export function visibleText(text: string): string {
  const clean = text.replace(/\[\[memory:[^\]\r\n]*\]\]/g, '');
  const start = clean.lastIndexOf('[[');
  if (start < 0) return clean;
  const tail = clean.slice(start);
  if ('[[memory:'.startsWith(tail) || (tail.startsWith('[[memory:') && !tail.includes(']]') && !tail.includes('\n'))) {
    return clean.slice(0, start);
  }
  return clean;
}

export function memoryOwner(memory: Json): string {
  const subject = `${memory.subject ?? ''}`.trim().toLowerCase();
  if (subject === 'clair') return 'Clair';
  if (subject === 'khent') return 'Khent';
  if (subject === 'khent and clair' || subject === 'clair and khent') return 'Both of you';
  return 'Owner not specified';
}

export type AIMessage = {
  role: string;
  content: string;
  timestamp: Date;
  imageUrls: string[];
  sources: Record<string, string>[];
  details: ReplyDetails;
  actionScopeId: string | null;
};

export function aiMessage(m: Partial<AIMessage> & { role: string; content: string }): AIMessage {
  return {
    timestamp: new Date(),
    imageUrls: [],
    sources: [],
    details: emptyDetails(),
    actionScopeId: null,
    ...m,
  };
}

export function messageToJson(m: AIMessage): Json {
  return {
    role: m.role,
    content: m.content,
    timestamp: dartIso(m.timestamp),
    ...(m.imageUrls.length > 0 ? { imageUrls: m.imageUrls } : {}),
    ...(m.sources.length > 0 ? { sources: m.sources } : {}),
    ...(!detailsEmpty(m.details) ? { details: detailsToJson(m.details) } : {}),
    ...(m.actionScopeId != null ? { actionScopeId: m.actionScopeId } : {}),
  };
}

/** Dart `DateTime.toIso8601String()` for a local time: no zone suffix, microsecond field. */
export function dartIso(d: Date): string {
  const p = (n: number, w = 2) => String(n).padStart(w, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}.${p(d.getMilliseconds(), 3)}`;
}

const parseDate = (v: unknown) => {
  if (typeof v !== 'string') return new Date();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? new Date() : d;
};

export function messageFromJson(json: Json): AIMessage {
  return {
    role: typeof json.role === 'string' ? json.role : 'user',
    content: typeof json.content === 'string' ? json.content : '',
    actionScopeId: typeof json.actionScopeId === 'string' ? json.actionScopeId : null,
    timestamp: json.timestamp != null ? parseDate(json.timestamp) : new Date(),
    imageUrls: Array.isArray(json.imageUrls) ? json.imageUrls.map(String) : [],
    details: json.details && typeof json.details === 'object' ? detailsFromJson(json.details as Json) : emptyDetails(),
    sources: Array.isArray(json.sources)
      ? json.sources.map((s) => Object.fromEntries(Object.entries(s as Json).map(([k, v]) => [k, String(v)])))
      : [],
  };
}

export function messageToApiPayload(m: AIMessage): Json {
  if (m.imageUrls.length === 0) {
    const receipts =
      m.role === 'assistant' && m.details.steps.length > 0
        ? `\n[Previous action results: ${m.details.steps
            .map((s) => `${s.tool}: ${s.status} ${s.title ?? ''} (target: ${s.target ?? ''})`)
            .join('; ')}. Do not repeat completed actions. Check uncertain actions before resuming.]`
        : '';
    return { role: m.role, content: `${m.content}${receipts}` };
  }
  const blocks: Json[] = [];
  if (m.content !== '') blocks.push({ type: 'text', text: m.content });
  for (const url of m.imageUrls) blocks.push({ type: 'image_url', image_url: { url } });
  return { role: m.role, content: blocks };
}

export type AIConversation = { id: string; feature: string; messages: AIMessage[]; createdAt: Date; updatedAt: Date };

export function conversation(id: string, feature: string, messages: AIMessage[] = []): AIConversation {
  return { id, feature, messages, createdAt: new Date(), updatedAt: new Date() };
}

export function conversationToJson(c: AIConversation): Json {
  return {
    id: c.id,
    feature: c.feature,
    messages: c.messages.map(messageToJson),
    createdAt: dartIso(c.createdAt),
    updatedAt: dartIso(c.updatedAt),
  };
}

export function conversationFromJson(json: Json): AIConversation {
  return {
    id: typeof json.id === 'string' ? json.id : '',
    feature: typeof json.feature === 'string' ? json.feature : 'assistant',
    messages: Array.isArray(json.messages) ? json.messages.map((m) => messageFromJson(m as Json)) : [],
    createdAt: json.createdAt != null ? parseDate(json.createdAt) : new Date(),
    updatedAt: json.updatedAt != null ? parseDate(json.updatedAt) : new Date(),
  };
}

export type AISession = {
  id: string;
  feature: string;
  messageCount: number;
  hasSummary: boolean;
  summary: string | null;
  createdAt: Date;
  title: string;
};

const THINKING_TRIGGERS = [
  'plan',
  'planning',
  'itinerary',
  'decide',
  'decision',
  'help me decide',
  'help us decide',
  'compare',
  'comparison',
  'pros and cons',
  'analyze',
  'analysis',
  'deep dive',
  'anniversary',
  'surprise',
  'relationship',
  'why are we',
];

const escapeRegExp = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** `MotchiQuality.shouldAutoThink`. */
export function shouldAutoThink(message: string): boolean {
  const text = message.trim();
  if (text.length < 12) return false;
  if (text.length >= 240) return true;
  const lower = text.toLowerCase();
  if ((lower.match(/\?/g) ?? []).length >= 2) return true;
  // Dart's '.!?'.allMatches counts the literal three-character sequence.
  const sentenceCount = lower.split('.!?').length - 1;
  if (sentenceCount >= 2 && text.length >= 80 && THINKING_TRIGGERS.some((w) => lower.includes(w))) return true;
  if (text.length >= 15 && THINKING_TRIGGERS.some((w) => new RegExp(`\\b${escapeRegExp(w)}\\b`).test(lower))) return true;
  return false;
}

/** `motchiPetName` from lib/shared/utils/greeting_utils.dart. */
export function motchiPetName(username: string | null | undefined): string {
  if (username === 'khentsgdz') return 'Dada';
  if (username === 'clairjassen') return 'Mama';
  return '';
}
