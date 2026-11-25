export type HlsInstance = {
  loadSource(url: string): void;
  attachMedia(video: HTMLVideoElement): void;
  on(event: string, cb: (_ev: unknown, data?: { fatal?: boolean; type?: string }) => void): void;
  startLoad?(): void;
  recoverMediaError?(): void;
  swapAudioCodec?(): void;
  destroy(): void;
};

export type HlsConstructor = {
  new (opts?: Record<string, unknown>): HlsInstance;
  isSupported(): boolean;
  Events: { ERROR: string };
  ErrorTypes?: { NETWORK_ERROR?: string; MEDIA_ERROR?: string };
};

const HLS_SCRIPT_SRC = 'https://cdn.jsdelivr.net/npm/hls.js@1.5.17/dist/hls.min.js';
const HLS_LOAD_TIMEOUT_MS = 12_000;

let hlsLoadPromise: Promise<HlsConstructor | null> | null = null;

export function loadHlsConstructor(timeoutMs = HLS_LOAD_TIMEOUT_MS): Promise<HlsConstructor | null> {
  if (typeof window === 'undefined') return Promise.resolve(null);
  const w = window as unknown as { Hls?: HlsConstructor };
  if (w.Hls) return Promise.resolve(w.Hls);
  if (hlsLoadPromise) return hlsLoadPromise;
  hlsLoadPromise = new Promise((resolve) => {
    let settled = false;
    const existing = document.getElementById('everglow-hlsjs') as HTMLScriptElement | null;
    const script = existing ?? document.createElement('script');
    const finish = (ctor: HlsConstructor | null, removeScript: boolean) => {
      if (settled) return;
      settled = true;
      window.clearTimeout(timer);
      script.removeEventListener('load', onLoad);
      script.removeEventListener('error', onError);
      if (removeScript && script.parentNode) script.parentNode.removeChild(script);
      if (!ctor) hlsLoadPromise = null;
      resolve(ctor);
    };
    const onLoad = () => finish(w.Hls ?? null, !w.Hls);
    const onError = () => finish(null, true);
    const timer = window.setTimeout(() => finish(null, true), timeoutMs);
    script.addEventListener('load', onLoad, { once: true });
    script.addEventListener('error', onError, { once: true });
    if (!existing) {
      script.id = 'everglow-hlsjs';
      script.crossOrigin = 'anonymous';
      script.src = HLS_SCRIPT_SRC;
      document.head.appendChild(script);
    }
  });
  return hlsLoadPromise;
}
