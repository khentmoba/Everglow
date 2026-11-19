// Port of lib/features/books/data/services/web_tts_service_web.dart.
// Long chapters are split so mobile speechSynthesis keeps running, and each
// utterance drives the next through onend (with a watchdog for browsers that
// never fire it). Pause/resume and a per-character boundary callback let the
// reader show play/pause state and follow the narration.
type SpeakOptions = {
  rate?: number;
  onBoundary?: (charIndex: number) => void;
  onComplete?: () => void;
};

const CHUNK_SIZE = 1600;

let chunks: string[] = [];
let chunkOffsets: number[] = [];
let chunkIdx = 0;
let current: SpeechSynthesisUtterance | null = null;
let session = 0;
let currentSession = 0;
let active = false;
let watchdog: number | null = null;
let idleTicks = 0;
let rate = 1.0;
let voiceURI = '';

const supported = () => typeof window !== 'undefined' && 'speechSynthesis' in window;

function chunkText(text: string): string[] {
  const normalized = text.replace(/\s+/g, ' ').trim();
  const out: string[] = [];
  let rest = normalized;
  while (rest.length > CHUNK_SIZE) {
    let cut = rest.lastIndexOf('. ', CHUNK_SIZE);
    if (cut < CHUNK_SIZE * 0.4) cut = rest.lastIndexOf(' ', CHUNK_SIZE);
    if (cut < CHUNK_SIZE * 0.4) cut = CHUNK_SIZE;
    out.push(rest.slice(0, cut + 1).trim());
    rest = rest.slice(cut + 1).trim();
  }
  if (rest) out.push(rest);
  return out;
}

function clearWatchdog() {
  if (watchdog != null) window.clearInterval(watchdog);
  watchdog = null;
}

function stopInternal() {
  active = false;
  session++;
  chunks = [];
  chunkOffsets = [];
  chunkIdx = 0;
  current = null;
  clearWatchdog();
  if (supported()) window.speechSynthesis.cancel();
}

function finishChunk(opts: SpeakOptions, token: number) {
  if (!active || token !== currentSession) return;
  chunkIdx++;
  if (chunkIdx < chunks.length) {
    speakCurrent(opts);
  } else {
    active = false;
    current = null;
    clearWatchdog();
    opts.onComplete?.();
  }
}

function speakCurrent(opts: SpeakOptions) {
  const token = ++session;
  currentSession = token;
  const text = chunks[chunkIdx] ?? '';
  const offset = chunkOffsets[chunkIdx] ?? 0;
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.rate = rate;
  utterance.pitch = 1;
  utterance.volume = 1;
  utterance.onend = () => finishChunk(opts, token);
  utterance.onerror = () => finishChunk(opts, token);
  utterance.onboundary = (e) => {
    if (token === currentSession) opts.onBoundary?.(offset + e.charIndex);
  };
  if (voiceURI) {
    const chosen = window.speechSynthesis.getVoices().find((v) => v.voiceURI === voiceURI);
    if (chosen) utterance.voice = chosen;
  }
  current = utterance;
  idleTicks = 0;
  window.speechSynthesis.speak(utterance);
}

function startWatchdog(opts: SpeakOptions) {
  clearWatchdog();
  watchdog = window.setInterval(() => {
    if (!active) {
      clearWatchdog();
      return;
    }
    if (window.speechSynthesis.speaking || window.speechSynthesis.paused) {
      idleTicks = 0;
      return;
    }
    idleTicks++;
    if (idleTicks >= 3) finishChunk(opts, currentSession);
  }, 500);
}

export const WebTts = {
  get isSupported() {
    return supported();
  },
  get isSpeaking() {
    return supported() && window.speechSynthesis.speaking;
  },
  get isPaused() {
    return supported() && window.speechSynthesis.paused;
  },
  get rate() {
    return rate;
  },
  get voices(): { uri: string; name: string; lang: string }[] {
    if (!supported()) return [];
    return window.speechSynthesis.getVoices().map((v) => ({ uri: v.voiceURI, name: v.name, lang: v.lang }));
  },
  setVoice(uri: string) {
    voiceURI = uri;
  },

  speak(text: string, opts: SpeakOptions = {}) {
    if (!supported() || text.trim() === '') return;
    stopInternal();
    rate = opts.rate ?? 1;
    chunks = chunkText(text);
    chunkOffsets = [];
    let total = 0;
    for (const chunk of chunks) {
      chunkOffsets.push(total);
      total += chunk.length + 1;
    }
    chunkIdx = 0;
    active = true;
    speakCurrent(opts);
    startWatchdog(opts);
  },

  pause() {
    if (supported() && window.speechSynthesis.speaking) window.speechSynthesis.pause();
  },

  resume() {
    if (supported() && window.speechSynthesis.paused) window.speechSynthesis.resume();
  },

  setRate(next: number) {
    rate = next;
    if (current) current.rate = next;
  },

  stop() {
    stopInternal();
  },
};
