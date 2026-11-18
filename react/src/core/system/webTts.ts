// Port of lib/features/books/data/services/web_tts_service_web.dart.
let current: SpeechSynthesisUtterance | null = null;
let watchdog: number | null = null;
let rate = 1.0;

const supported = () => typeof window !== 'undefined' && 'speechSynthesis' in window;

export const WebTts = {
  get isSupported() {
    return supported();
  },
  get isSpeaking() {
    return supported() && window.speechSynthesis.speaking;
  },
  get rate() {
    return rate;
  },

  speak(text: string, { rate: r = 1.0, onComplete }: { rate?: number; onComplete?: () => void } = {}) {
    if (!supported() || text.trim() === '') return;
    const synthesis = window.speechSynthesis;
    synthesis.cancel();
    if (watchdog != null) clearInterval(watchdog);
    rate = r;
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = r;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;
    current = utterance;
    synthesis.speak(utterance);
    watchdog = window.setInterval(() => {
      if (!window.speechSynthesis.speaking) {
        if (watchdog != null) clearInterval(watchdog);
        watchdog = null;
        current = null;
        onComplete?.();
      }
    }, 350);
  },

  setRate(r: number) {
    rate = r;
    if (current) current.rate = r;
  },

  stop() {
    if (watchdog != null) clearInterval(watchdog);
    watchdog = null;
    if (supported()) window.speechSynthesis.cancel();
    current = null;
  },
};
