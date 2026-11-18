// Port of the chat half of lib/features/ai/data/services/ai_service.dart, plus
// ai_conversation_repo.dart and sse_streamer_web.dart.
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  type DocumentSnapshot,
} from 'firebase/firestore';
import { useSyncExternalStore } from 'react';
import { auth, db } from '../../core/services/firebase';
import { Logger } from '../../core/system/logger';
import { ValueNotifier } from '../../core/system/store';
import { AI_PROXY_URL } from './aiService';
import {
  aiMessage,
  conversation,
  conversationFromJson,
  conversationToJson,
  detailsEmpty,
  detailsFromResults,
  detailsSummary,
  emptyDetails,
  messageToApiPayload,
  messageFromJson,
  messageToJson,
  shouldAutoThink,
  visibleText,
  type AIConversation,
  type AIMessage,
  type AISession,
  type Json,
  type ReplyDetails,
} from './motchiDomain';
import { motchiWantsArtifact } from './studyArtifact';

const HISTORY_LIMIT = 20;
const GUARDIAN_HISTORY_LIMIT = 12;

const uid = () => auth.currentUser?.uid ?? '';
const idToken = async () => (await auth.currentUser?.getIdToken()) ?? '';
const sessionsRef = () => collection(doc(db, 'ai_memories', 'shared'), 'sessions');

function generateSessionId(): string {
  return `sess_${Date.now()}_${Math.floor(Math.random() * 900000) + 100000}`;
}

export function trimHistoryForRequest(payloads: Json[], max = HISTORY_LIMIT): Json[] {
  return payloads.length <= max ? payloads : payloads.slice(payloads.length - max);
}

export function stripStaleImages(payloads: Json[], keepLast = 2): Json[] {
  let seen = 0;
  let changed = false;
  const out: Json[] = [];
  for (let i = payloads.length - 1; i >= 0; i--) {
    const payload = payloads[i];
    const blocks = Array.isArray(payload.content) ? (payload.content as Json[]) : [];
    if (!blocks.some((b) => b && b.type === 'image_url')) {
      out.push(payload);
      continue;
    }
    seen++;
    if (seen <= keepLast) {
      out.push(payload);
      continue;
    }
    const text = blocks
      .filter((b) => b && b.type === 'text' && typeof b.text === 'string')
      .map((b) => b.text as string)
      .join('\n');
    changed = true;
    out.push({ role: payload.role, content: text });
  }
  return changed ? out.reverse() : payloads;
}

const hostOf = (url: string) => {
  try {
    return new URL(url).host.replace('www.', '');
  } catch {
    return '';
  }
};

export function webSourcesFromToolResults(results: Json[]): Record<string, string>[] {
  const seen = new Set<string>();
  const out: Record<string, string>[] = [];
  const add = (title: string, url: string, site: string) => {
    const u = url.trim();
    if (u === '' || !u.startsWith('http') || seen.has(u)) return;
    seen.add(u);
    if (out.length >= 5) return;
    out.push({ title: title.trim(), url: u, site: site.trim() });
  };
  const s = (v: unknown) => `${v ?? ''}`;
  for (const r of results) {
    if (r.tool === 'web_search' && Array.isArray(r.results)) {
      for (const x of r.results as Json[]) if (x && typeof x === 'object') add(s(x.title), s(x.url), s(x.site));
    } else if (r.tool === 'read_web_page' && Array.isArray(r.pages)) {
      for (const p of r.pages as Json[]) if (p && typeof p === 'object') add(s(p.title), s(p.url), hostOf(s(p.url)));
    } else if (r.tool === 'browse_web' && r.status === 'COMPLETED') {
      add(s(r.title), s(r.url), hostOf(s(r.url)));
    }
  }
  return out;
}

export function isToolActionStatus(status: string): boolean {
  if (status === '' || status.includes(':')) return false;
  if (['generating', 'thinking', 'executing', 'repairing', 'done'].includes(status)) return false;
  return !status.startsWith('round_');
}

type SseHandlers = {
  onChunk: (chunk: string) => void;
  onReasoning?: (chunk: string) => void;
  onToolStatus?: (status: string) => void;
  onToolResult?: (result: Json) => void;
  onError?: (error: string) => void;
};

class TimeoutError extends Error {}

/** `streamSseResponse` from sse_streamer_web.dart: reads `data:` lines and drains up to 4 per frame. */
async function streamSse(body: string, timeoutMs: number, signal: AbortController, h: SseHandlers): Promise<string> {
  let full = '';
  let lineBuffer = '';
  const pending: string[] = [];
  let drainScheduled = false;
  let streamDone = false;
  let paintedFirstToken = false;
  let settle: { resolve: (v: string) => void; reject: (e: unknown) => void } | null = null;
  const done = new Promise<string>((resolve, reject) => (settle = { resolve, reject }));
  let finished = false;
  const complete = () => {
    if (finished) return;
    finished = true;
    document.removeEventListener('visibilitychange', onVisible);
    settle!.resolve(full);
  };
  const fail = (e: unknown) => {
    if (finished) return;
    finished = true;
    document.removeEventListener('visibilitychange', onVisible);
    settle!.reject(e);
  };

  const process = (data: string) => {
    if (data === '[DONE]') return;
    try {
      const parsed = JSON.parse(data) as Json;
      const reasoning = typeof parsed.reasoning === 'string' ? parsed.reasoning : '';
      if (reasoning !== '') h.onReasoning?.(reasoning);
      const content = typeof parsed.content === 'string' ? parsed.content : '';
      if (content !== '') {
        full += content;
        h.onChunk(content);
      }
      const toolStatus = typeof parsed.tool_status === 'string' ? parsed.tool_status : '';
      if (toolStatus !== '') h.onToolStatus?.(toolStatus);
      const toolResult = parsed.tool_result;
      if (toolResult && typeof toolResult === 'object' && !Array.isArray(toolResult))
        h.onToolResult?.({ ...(toolResult as Json) });
      const error = typeof parsed.error === 'string' ? parsed.error : '';
      if (error !== '') h.onError?.(error);
    } catch {
      // Skip malformed JSON chunks.
    }
  };
  const payloadHasText = (data: string, key: string) => {
    const i = data.indexOf(`"${key}":"`);
    if (i < 0) return false;
    const v = i + key.length + 4;
    return v < data.length && data[v] !== '"';
  };
  const pendingHasVisibleToken = () => pending.some((d) => payloadHasText(d, 'content') || payloadHasText(d, 'reasoning'));
  const drainAll = () => {
    while (pending.length > 0) process(pending.shift()!);
  };
  const drain = () => {
    let budget = 4;
    while (pending.length > 0 && budget-- > 0) process(pending.shift()!);
    if (pending.length === 0 && streamDone) complete();
  };
  const startDrain = (): void => {
    if (document.hidden) {
      drainScheduled = false;
      drainAll();
      if (streamDone) complete();
      return;
    }
    if (drainScheduled) return;
    if (!paintedFirstToken && pendingHasVisibleToken()) {
      drain();
      paintedFirstToken = !pendingHasVisibleToken();
      if (pending.length > 0) startDrain();
      return;
    }
    drainScheduled = true;
    requestAnimationFrame(() => {
      drainScheduled = false;
      drain();
      if (pending.length > 0) startDrain();
    });
  };
  function onVisible() {
    if (!document.hidden && pending.length > 0) startDrain();
  }
  document.addEventListener('visibilitychange', onVisible);
  const processText = (text: string) => {
    lineBuffer += text;
    const lines = lineBuffer.split('\n');
    lineBuffer = lines.pop()!;
    for (const line of lines) {
      const trimmed = line.trimEnd();
      if (trimmed.startsWith('data: ')) pending.push(trimmed.slice(6).trim());
    }
    startDrain();
  };
  const finish = () => {
    streamDone = true;
    const trimmed = lineBuffer.trimEnd();
    if (trimmed.startsWith('data: ')) pending.push(trimmed.slice(6).trim());
    lineBuffer = '';
    if (pending.length === 0 || document.hidden) {
      drainAll();
      complete();
    } else {
      startDrain();
    }
  };

  const timer = setTimeout(() => {
    signal.abort();
    fail(new TimeoutError('AI request timed out'));
  }, timeoutMs);
  signal.signal.addEventListener('abort', () => {
    pending.length = 0;
    fail(new Error('Reply stopped'));
  });
  try {
    const response = await fetch(AI_PROXY_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${await idToken()}` },
      body,
      signal: signal.signal,
    });
    if (!response.ok) {
      const errText = await response.text();
      let message: string;
      try {
        message = (JSON.parse(errText) as Json).error as string;
        if (typeof message !== 'string') message = 'Unknown error';
      } catch {
        message = `AI service returned ${response.status}`;
      }
      throw new Error(message);
    }
    const reader = response.body!.getReader();
    const decoder = new TextDecoder();
    for (;;) {
      const chunk = await reader.read();
      if (chunk.value) processText(decoder.decode(chunk.value, { stream: true }));
      if (chunk.done) break;
    }
    processText(decoder.decode());
    finish();
  } catch (e) {
    fail(e);
  }
  try {
    return await done;
  } finally {
    clearTimeout(timer);
  }
}

class ConversationRepository {
  assistant: AIConversation | null = null;
  private byFeature = new Map<string, AIConversation | null>();

  get(feature: string): AIConversation | null {
    return feature === 'assistant' ? this.assistant : (this.byFeature.get(feature) ?? null);
  }
  set(feature: string, conv: AIConversation | null) {
    if (feature === 'assistant') this.assistant = conv;
    else this.byFeature.set(feature, conv);
  }

  async getOrCreate(feature: string): Promise<AIConversation> {
    const cached = this.get(feature);
    if (cached) return cached;
    const id = uid();
    if (id === '') {
      const conv = conversation(`local_${feature}_${Date.now()}`, feature);
      this.set(feature, conv);
      return conv;
    }
    try {
      const snap = await getDoc(doc(db, 'users', id, 'ai_conversations', feature));
      if (snap.exists() && snap.data()) {
        const conv = conversationFromJson(snap.data() as Json);
        this.set(feature, conv);
        return conv;
      }
    } catch (e) {
      Logger.d(`[AIConversationRepository] Failed to load conversation from Firestore: ${e}`);
    }
    const conv = conversation(feature, feature);
    this.set(feature, conv);
    return conv;
  }

  async save(conv: AIConversation): Promise<void> {
    const id = uid();
    if (id === '') return;
    try {
      const payload = conversationToJson(conv);
      payload.updatedAt = conversationToJson({ ...conv, updatedAt: new Date() }).updatedAt;
      await setDoc(doc(db, 'users', id, 'ai_conversations', conv.feature), payload);
    } catch (e) {
      Logger.d(`Failed to save AI conversation: ${e}`);
    }
  }

  async archiveSession(conv: AIConversation): Promise<void> {
    try {
      const messagesJson = conv.messages.map(messageToJson);
      await addDoc(sessionsRef(), {
        feature: conv.feature,
        messages: messagesJson,
        messageCount: messagesJson.length,
        hasSummary: false,
        createdAt: serverTimestamp(),
      });
      void this.trimFullSessions();
    } catch (e) {
      Logger.d(`Failed to archive session: ${e}`);
    }
  }

  private async trimFullSessions(): Promise<void> {
    try {
      const snapshot = await getDocs(query(sessionsRef(), where('hasSummary', '==', false), orderBy('createdAt', 'desc')));
      if (snapshot.docs.length <= 8) return;
      for (const d of snapshot.docs.slice(8)) {
        const messages = (d.data().messages as Json[] | undefined) ?? [];
        const summary = await this.buildLLMSummary(messages);
        await updateDoc(d.ref, { hasSummary: true, summary, messages: [] });
      }
      await this.compressOldSessions();
    } catch (e) {
      Logger.d(`Failed to trim sessions: ${e}`);
    }
  }

  private async summarize(systemPrompt: string, content: string): Promise<string> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 30000);
    try {
      const response = await fetch(AI_PROXY_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${await idToken()}` },
        body: JSON.stringify({ systemPrompt, messages: [{ role: 'user', content }] }),
        signal: controller.signal,
      });
      if (response.status !== 200) return '';
      const data = (await response.json()) as Json;
      return (typeof data.reply === 'string' ? data.reply : '').trim();
    } finally {
      clearTimeout(timer);
    }
  }

  private async buildLLMSummary(messages: Json[]): Promise<string> {
    if (messages.length === 0) return 'Empty session';
    const userMessages = messages
      .filter((m) => m.role === 'user')
      .map((m) => (typeof m.content === 'string' ? m.content : ''))
      .filter((c) => c !== '')
      .join('\n');
    if (userMessages.trim().length < 20) return buildLocalSummary(messages);
    try {
      const summary = await this.summarize(
        'Summarize this conversation in 2-3 sentences. Focus on key topics, decisions, and notable moments. Be concise.',
        userMessages,
      );
      if (summary !== '') return summary;
    } catch (e) {
      Logger.d(`[AIConversationRepository] Summary API call failed, falling back to local: ${e}`);
    }
    return buildLocalSummary(messages);
  }

  private async compressOldSessions(): Promise<void> {
    try {
      const snapshot = await getDocs(query(sessionsRef(), where('hasSummary', '==', true), orderBy('createdAt'), limit(40)));
      if (snapshot.docs.length <= 20) return;
      const toMerge = snapshot.docs.slice(0, snapshot.docs.length - 8);
      const summaries = toMerge
        .map((d) => (typeof d.data().summary === 'string' ? (d.data().summary as string) : ''))
        .filter((s) => s !== '')
        .join('\n');
      if (summaries === '') return;
      let merged: string;
      try {
        merged =
          (await this.summarize(
            'Merge these session summaries into one concise paragraph preserving key information.',
            summaries,
          )) || summaries;
      } catch (e) {
        Logger.e('AIConversationRepo: summary merge call failed, keeping raw summaries', e);
        merged = summaries;
      }
      await addDoc(sessionsRef(), {
        summary: merged,
        hasSummary: true,
        messages: [],
        feature: 'assistant',
        messageCount: 0,
        createdAt: serverTimestamp(),
      });
      for (const d of toMerge) await deleteDoc(d.ref);
    } catch (e) {
      Logger.d(`Failed to compress sessions: ${e}`);
    }
  }

  async clear(feature: string, archive = true): Promise<void> {
    const conv = this.get(feature);
    const toArchive = archive && conv && conv.messages.length >= 2 ? conv : null;
    this.set(feature, conversation(feature, feature));
    if (toArchive) await this.archiveSession(toArchive);
    const id = uid();
    if (id === '') return;
    try {
      await deleteDoc(doc(db, 'users', id, 'ai_conversations', feature));
    } catch (e) {
      Logger.d(`[AIConversationRepository] Failed to delete conversation: ${e}`);
    }
  }

  async loadAssistant(): Promise<void> {
    if (this.assistant) return;
    await this.getOrCreate('assistant');
  }

  startFresh() {
    this.assistant = null;
    this.byFeature.clear();
  }

  private sessionsQuery(max = 50) {
    return query(sessionsRef(), where('feature', '==', 'assistant'), orderBy('createdAt', 'desc'), limit(max));
  }

  async listSessions(max = 50): Promise<AISession[]> {
    const snap = await getDocs(this.sessionsQuery(max));
    return snap.docs.map(sessionFromDoc);
  }

  watchSessions(max: number, onData: (s: AISession[]) => void, onError: (e: unknown) => void): () => void {
    return onSnapshot(
      this.sessionsQuery(max),
      (snap) => onData(snap.docs.map(sessionFromDoc)),
      (e) => {
        Logger.e('Failed to watch sessions', e);
        onError(e);
      },
    );
  }

  async loadSession(sessionId: string): Promise<void> {
    try {
      const snap = await getDoc(doc(sessionsRef(), sessionId));
      if (!snap.exists() || !snap.data()) throw new Error('Requested AI session does not exist');
      const data = snap.data() as Json;
      const messages = Array.isArray(data.messages) ? (data.messages as Json[]) : [];
      const summary = typeof data.summary === 'string' ? data.summary : null;
      const parsed = messages.map((m) => messageFromJson(m));
      if (parsed.length === 0 && summary) parsed.push(aiMessage({ role: 'assistant', content: `Summary: ${summary}` }));
      const previous = this.assistant;
      this.assistant = {
        id: previous?.id ?? 'assistant',
        feature: 'assistant',
        messages: parsed,
        createdAt: previous?.createdAt ?? new Date(),
        updatedAt: previous?.updatedAt ?? new Date(),
      };
    } catch (e) {
      Logger.e('Failed to load session', e);
      throw e;
    }
  }

  async deleteSession(sessionId: string): Promise<void> {
    try {
      await deleteDoc(doc(sessionsRef(), sessionId));
    } catch (e) {
      Logger.d(`Failed to delete session: ${e}`);
    }
  }
}

function buildLocalSummary(messages: Json[]): string {
  if (messages.length === 0) return 'Empty session';
  const seen = new Set<string>();
  const topics: string[] = [];
  let exchangeCount = 0;
  for (const m of messages) {
    const content = (typeof m.content === 'string' ? m.content : '').trim();
    if (content === '') continue;
    if (m.role === 'user') {
      exchangeCount++;
      const first = content.split(/[.?!\n]/)[0].trim();
      if (first.length >= 8) {
        const gist = first.length > 80 ? `${first.slice(0, 80)}…` : first;
        const key = gist.slice(0, Math.min(20, gist.length)).toLowerCase();
        if (!seen.has(key) && topics.length < 8) {
          seen.add(key);
          topics.push(gist);
        } else seen.add(key);
      }
    }
  }
  if (topics.length === 0) return `${exchangeCount} exchanges (no clear topics)`;
  return `${exchangeCount} topics — ${topics.join(' • ')}`;
}

function sessionFromDoc(d: DocumentSnapshot): AISession {
  const data = (d.data() ?? {}) as Json;
  const messages = Array.isArray(data.messages) ? (data.messages as Json[]) : [];
  const hasSummary = typeof data.hasSummary === 'boolean' ? data.hasSummary : true;
  const summary = typeof data.summary === 'string' ? data.summary : null;
  const createdAt = data.createdAt instanceof Timestamp ? data.createdAt.toDate() : new Date();
  let title = 'New conversation';
  if (hasSummary && summary) {
    title = summary.length > 60 ? `${summary.slice(0, 60)}…` : summary;
  } else if (messages.length > 0) {
    const first = messages.find((m) => m.role === 'user');
    if (first) {
      const content = typeof first.content === 'string' ? first.content : '';
      title = content.length > 60 ? `${content.slice(0, 60)}…` : content;
    }
  }
  return {
    id: d.id,
    feature: typeof data.feature === 'string' ? data.feature : 'assistant',
    messageCount: typeof data.messageCount === 'number' ? data.messageCount : messages.length,
    hasSummary,
    summary,
    createdAt,
    title,
  };
}

type SendOptions = {
  feature: string;
  message: string;
  contextOverride?: string;
  stream?: boolean;
  enableThinking?: boolean;
  callerName?: string | null;
  imageUrls?: string[];
  canvasEnabled?: boolean;
  actionScopeId?: string | null;
};

/** The chat side of `AIService`: one shared instance, like the app-wide Provider. */
export class AIChatService {
  private repo = new ConversationRepository();
  private listeners = new Set<() => void>();
  private version = 0;

  private currentSession: string | null = null;
  private activeRequest = 0;
  private actionScope: string | null = null;
  private cancellation: AbortController | null = null;

  isLoading = false;
  isNavigating = false;
  lastError: string | null = null;
  draftResponse = '';
  draftReasoning = '';
  activeTools: string[] = [];
  toolResults: Json[] = [];

  readonly draftRevision = new ValueNotifier(0);
  readonly toolResultsNotifier = new ValueNotifier<Json[]>([]);

  get assistantConversation(): AIConversation | null {
    return this.repo.assistant;
  }
  get currentActionScopeId(): string | null {
    return this.actionScope;
  }
  get currentSessionId(): string {
    return (this.currentSession ??= generateSessionId());
  }

  subscribe = (l: () => void) => {
    this.listeners.add(l);
    return () => this.listeners.delete(l);
  };
  getVersion = () => this.version;
  private notify() {
    this.version++;
    for (const l of this.listeners) l();
  }
  private bumpDraft() {
    this.draftRevision.value = this.draftRevision.value + 1;
  }

  private trackToolStarted(status: string) {
    if (!isToolActionStatus(status)) {
      if (status === 'done' && this.activeTools.length > 0) this.activeTools = [];
      return;
    }
    if (this.activeTools.includes(status)) return;
    this.activeTools = [...this.activeTools, status];
  }
  private trackToolFinished(tool: string) {
    if (!this.activeTools.includes(tool)) return;
    this.activeTools = this.activeTools.filter((t) => t !== tool);
  }
  private resetDraftState() {
    this.draftResponse = '';
    this.draftReasoning = '';
    this.activeTools = [];
    this.toolResults = [];
    this.toolResultsNotifier.value = [];
    this.bumpDraft();
  }

  private streamHandlers(isCurrent: () => boolean): SseHandlers {
    return {
      onChunk: (chunk) => {
        if (!isCurrent()) return;
        this.draftResponse += chunk;
        this.bumpDraft();
      },
      onReasoning: (r) => {
        if (!isCurrent()) return;
        this.draftReasoning += r;
        this.bumpDraft();
      },
      onToolStatus: (status) => {
        if (!isCurrent()) return;
        this.trackToolStarted(status);
        this.bumpDraft();
      },
      onToolResult: (result) => {
        if (!isCurrent()) return;
        this.toolResults.push(result);
        if (typeof result.tool === 'string' && result.tool !== '') this.trackToolFinished(result.tool);
        this.toolResultsNotifier.value = [...this.toolResults];
        this.bumpDraft();
      },
      onError: (error) => {
        if (!isCurrent()) return;
        this.lastError = error;
        this.notify();
      },
    };
  }

  private async callStream(
    messages: Json[],
    feature: string,
    caller: string,
    handlers: SseHandlers,
    opts: {
      enableThinking: boolean;
      canvasEnabled: boolean;
      artifactExpected: boolean;
      sessionIdOverride?: string;
      temporary?: boolean;
      context?: string;
    },
  ): Promise<string> {
    const maxRetries = 2;
    let receivedEvent = false;
    const wrapped: SseHandlers = {
      onChunk: (c) => ((receivedEvent = true), handlers.onChunk(c)),
      onReasoning: (c) => ((receivedEvent = true), handlers.onReasoning?.(c)),
      onToolStatus: (c) => ((receivedEvent = true), handlers.onToolStatus?.(c)),
      onToolResult: (c) => ((receivedEvent = true), handlers.onToolResult?.(c)),
      onError: handlers.onError,
    };
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) this.lastError = null;
        const body = JSON.stringify({
          messages,
          context: opts.context ?? '',
          feature,
          caller,
          sessionId: opts.sessionIdOverride ?? this.currentSessionId,
          ...(!opts.temporary && this.actionScope != null ? { actionScopeId: this.actionScope } : {}),
          ...(opts.temporary ? { temporary: true } : {}),
          stream: true,
          enableThinking: opts.enableThinking,
          canvas: opts.canvasEnabled,
        });
        const controller = new AbortController();
        this.cancellation = controller;
        const timeout = opts.artifactExpected ? 285000 : opts.enableThinking ? 185000 : 95000;
        return await streamSse(body, timeout, controller, wrapped);
      } catch (e) {
        const text = String(e);
        const transient = e instanceof TimeoutError || e instanceof TypeError || /50[23]|429/.test(text);
        if (attempt < maxRetries && transient && !receivedEvent && feature !== 'assistant') {
          await new Promise((r) => setTimeout(r, 1000 << attempt));
          continue;
        }
        throw e;
      }
    }
    throw new Error('Retry exhausted');
  }

  async sendMessage(o: SendOptions): Promise<string> {
    if (this.isNavigating) throw new Error('Wait for the conversation to finish opening.');
    this.isLoading = true;
    this.activeRequest++;
    const previous = this.repo.assistant?.messages.at(-1);
    this.actionScope =
      o.actionScopeId ??
      (/^(yes|yep|okay|ok|sure|continue|finish|retry|try again)[.!?\s]*$/i.test(o.message.trim())
        ? previous?.actionScopeId
        : null) ??
      generateSessionId();
    const myRequest = this.activeRequest;
    const isCurrent = () => myRequest === this.activeRequest;
    this.lastError = null;
    this.resetDraftState();
    const imageUrls = o.imageUrls ?? [];
    let conv: AIConversation | null = null;
    const caller = o.callerName ?? (uid() || 'unknown');
    try {
      conv = await this.repo.getOrCreate(o.feature);
      conv.messages.push(aiMessage({ role: 'user', content: o.message, imageUrls, actionScopeId: this.actionScope }));
      this.repo.set(o.feature, { ...conv });
      conv = this.repo.get(o.feature)!;
      this.notify();

      const isGuardian = o.feature === 'guardian';
      const recent = stripStaleImages(
        trimHistoryForRequest(conv.messages.map(messageToApiPayload), isGuardian ? GUARDIAN_HISTORY_LIMIT : HISTORY_LIMIT),
      );
      const shouldThink = o.enableThinking ?? shouldAutoThink(o.message);
      let reply: string;
      let webSources: Record<string, string>[] = [];
      let details: ReplyDetails = emptyDetails();
      reply = await this.callStream(recent, o.feature, caller, this.streamHandlers(isCurrent), {
        enableThinking: shouldThink,
        canvasEnabled: o.canvasEnabled ?? true,
        artifactExpected: motchiWantsArtifact(o.message),
        context: o.contextOverride ?? '',
      });
      if (!isCurrent()) return reply;
      webSources = webSourcesFromToolResults(this.toolResults);
      details = detailsFromResults(this.toolResults);

      if (reply.trim() === '' && !detailsEmpty(details)) reply = detailsSummary(details);
      if (reply.trim() === '') throw new Error('Motchi got distracted and lost her train of thought. Try asking again?');
      const cleaned = visibleText(reply).trimStart();
      conv.messages.push(
        aiMessage({ role: 'assistant', content: cleaned, sources: webSources, details, actionScopeId: this.actionScope }),
      );
      this.isLoading = false;
      this.lastError = null;
      this.resetDraftState();
      this.repo.set(o.feature, { ...conv });
      conv = this.repo.get(o.feature)!;
      this.notify();
      if (conv.messages.length > 50) conv.messages.splice(0, conv.messages.length - 50);
      await this.repo.save(conv);
      if (conv.messages.length >= 4 && conv.messages.length % 20 <= 1) {
        try {
          await this.repo.archiveSession(conv);
        } catch (e) {
          Logger.d(`[AIService] Session archive failed: ${e}`);
        }
      }
      return cleaned;
    } catch (e) {
      if (!isCurrent()) return '';
      this.isLoading = false;
      const details = detailsFromResults(this.toolResults, true, this.activeTools);
      if (conv && (details.steps.length > 0 || this.draftResponse !== '')) {
        const partial = visibleText(this.draftResponse);
        conv.messages.push(
          aiMessage({
            role: 'assistant',
            content: partial.trim() === '' ? detailsSummary(details) : partial,
            details,
            actionScopeId: this.actionScope,
          }),
        );
        this.repo.set(o.feature, { ...conv });
        conv = this.repo.get(o.feature)!;
        void this.repo.save(conv);
      }
      this.resetDraftState();
      this.lastError = e instanceof Error ? `Exception: ${e.message}` : String(e);
      const last = conv?.messages.at(-1);
      if (conv && last && last.role === 'user' && last.content === o.message && last.imageUrls.length === imageUrls.length) {
        conv.messages.pop();
        this.repo.set(o.feature, { ...conv });
      }
      this.notify();
      throw e;
    }
  }

  /** `sendTemporaryMessage`: a reply that never touches the saved Motchi conversation (the Anime sidebar). */
  async sendTemporaryMessage(o: {
    message: string;
    history: AIMessage[];
    callerName?: string | null;
    enableThinking?: boolean;
    canvasEnabled?: boolean;
    imageUrls?: string[];
    sessionId?: string;
    contextOverride?: string;
  }): Promise<AIMessage> {
    this.isLoading = true;
    this.activeRequest++;
    const myRequest = this.activeRequest;
    const isCurrent = () => myRequest === this.activeRequest;
    this.lastError = null;
    this.resetDraftState();
    this.notify();
    const caller = o.callerName ?? (uid() || 'unknown');
    try {
      const userMessage = aiMessage({ role: 'user', content: o.message, imageUrls: o.imageUrls ?? [] });
      const recent = stripStaleImages(trimHistoryForRequest([...o.history, userMessage].map(messageToApiPayload), HISTORY_LIMIT));
      let reply = await this.callStream(recent, 'assistant', caller, this.streamHandlers(isCurrent), {
        enableThinking: o.enableThinking ?? shouldAutoThink(o.message),
        canvasEnabled: o.canvasEnabled ?? true,
        artifactExpected: motchiWantsArtifact(o.message),
        sessionIdOverride: o.sessionId ?? `temp_anime_${Date.now()}`,
        temporary: true,
        context: o.contextOverride ?? '',
      });
      if (!isCurrent()) return aiMessage({ role: 'assistant', content: visibleText(reply) });
      const sources = webSourcesFromToolResults(this.toolResults);
      const details = detailsFromResults(this.toolResults);
      if (reply.trim() === '' && !detailsEmpty(details)) reply = detailsSummary(details);
      if (reply.trim() === '') throw new Error('Motchi got distracted and lost her train of thought. Try asking again?');
      const cleaned = visibleText(reply).trimStart();
      this.isLoading = false;
      this.lastError = null;
      this.resetDraftState();
      this.notify();
      return aiMessage({ role: 'assistant', content: cleaned, sources, details });
    } catch (e) {
      if (!isCurrent()) return aiMessage({ role: 'assistant', content: '' });
      this.isLoading = false;
      this.lastError = e instanceof Error ? `Exception: ${e.message}` : String(e);
      this.resetDraftState();
      this.notify();
      throw e;
    }
  }

  cancelCurrentReply(): boolean {
    if (!this.isLoading || this.activeRequest === 0) return false;
    this.activeRequest++;
    this.cancellation?.abort();
    const conv = this.repo.assistant;
    const partial = visibleText(this.draftResponse).trimStart();
    const details = detailsFromResults(this.toolResults, true, this.activeTools);
    if (conv && (partial !== '' || details.steps.length > 0)) {
      const messages = [
        ...conv.messages,
        aiMessage({
          role: 'assistant',
          content: partial === '' ? detailsSummary(details) : partial,
          details,
          actionScopeId: this.actionScope,
        }),
      ];
      if (messages.length > 50) messages.splice(0, messages.length - 50);
      const next = { ...conv, messages };
      this.repo.set('assistant', next);
      void this.repo.save(next);
    }
    this.isLoading = false;
    this.lastError = null;
    this.resetDraftState();
    this.notify();
    return true;
  }

  /** `streamStudyReply`: streams a Study answer without touching the Motchi conversation. */
  async streamStudyReply(o: {
    history: { role: string; content: string }[];
    sourcesBlock: string;
    question: string;
    callerName?: string | null;
    enableThinking?: boolean;
    canvasEnabled?: boolean;
  }): Promise<string> {
    this.isLoading = true;
    this.lastError = null;
    this.resetDraftState();
    this.notify();
    const caller = o.callerName ?? (uid() || 'unknown');
    try {
      const messages: Json[] = [
        ...o.history.map((t) => ({ role: t.role, content: t.content })),
        { role: 'user', content: `${o.sourcesBlock}\n\n${o.question}` },
      ];
      const reply = await this.callStream(
        messages,
        'study',
        caller,
        this.streamHandlers(() => true),
        {
          enableThinking: o.enableThinking ?? true,
          canvasEnabled: o.canvasEnabled ?? true,
          artifactExpected: motchiWantsArtifact(o.question),
        },
      );
      this.isLoading = false;
      this.resetDraftState();
      this.notify();
      return reply;
    } catch (e) {
      this.isLoading = false;
      this.lastError = String(e);
      this.resetDraftState();
      this.notify();
      throw e;
    }
  }

  async clearConversation(feature: string, archive = true): Promise<void> {
    if (this.isLoading || this.isNavigating) throw new Error('Wait for the current chat action to finish.');
    this.isNavigating = true;
    this.notify();
    try {
      await this.repo.clear(feature, archive);
      this.currentSession = null;
    } finally {
      this.isNavigating = false;
      this.notify();
    }
  }

  async loadAssistantConversation(): Promise<void> {
    await this.repo.loadAssistant();
    this.notify();
  }

  startFreshSession() {
    this.currentSession = null;
    this.repo.startFresh();
    this.notify();
  }

  watchSessions(max: number, onData: (s: AISession[]) => void, onError: (e: unknown) => void): () => void {
    return this.repo.watchSessions(max, onData, onError);
  }

  listSessions(max = 50): Promise<AISession[]> {
    return this.repo.listSessions(max);
  }

  async switchSession(sessionId: string): Promise<void> {
    if (this.isLoading || this.isNavigating) throw new Error('Wait for the current chat action to finish.');
    this.isNavigating = true;
    this.notify();
    try {
      await this.repo.loadSession(sessionId);
      this.currentSession = sessionId;
      const conv = this.repo.assistant;
      if (conv) await this.repo.save(conv);
    } finally {
      this.isNavigating = false;
      this.notify();
    }
  }

  async deleteSession(sessionId: string): Promise<void> {
    await this.repo.deleteSession(sessionId);
    this.notify();
  }

  async archiveCurrentSession(): Promise<void> {
    const conv = this.repo.assistant;
    if (conv && conv.messages.length >= 2) await this.repo.archiveSession(conv);
  }
}

export const aiChat = new AIChatService();

/** Re-renders when the chat service notifies (`context.watch<AIService>()`). */
export function useAIChat(): AIChatService {
  useSyncExternalStore(aiChat.subscribe, aiChat.getVersion);
  return aiChat;
}

export type { AIMessage };
