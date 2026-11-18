// Port of lib/features/ai/presentation/widgets/motchi_web_bridge_web.dart.
import { Logger } from '../../core/system/logger';

type SpeechRecognitionLike = {
  lang: string;
  interimResults: boolean;
  maxAlternatives: number;
  continuous: boolean;
  onresult: ((event: SpeechResultEvent) => void) | null;
  onerror: ((event: { error?: string }) => void) | null;
  onend: (() => void) | null;
  start(): void;
  stop(): void;
  abort(): void;
};

type SpeechResultEvent = {
  results: ArrayLike<ArrayLike<{ transcript?: string }>>;
};

type SpeechWindow = Window & {
  SpeechRecognition?: new () => SpeechRecognitionLike;
  webkitSpeechRecognition?: new () => SpeechRecognitionLike;
  webkitAudioContext?: typeof AudioContext;
};

/** Browser paste, speech-to-text, audio meter, and client-side image resizing for Motchi. */
export class MotchiWebBridge {
  private pasteListener: ((e: ClipboardEvent) => void) | null = null;
  private voiceVisibilityListener: (() => void) | null = null;
  private recognition: SpeechRecognitionLike | null = null;
  private speechResolve: ((v: string | null) => void) | null = null;
  private speechReject: ((e: unknown) => void) | null = null;
  private speechTimeout: number | null = null;
  private speechTranscript: string | null = null;
  private audioContext: AudioContext | null = null;
  private audioSource: MediaStreamAudioSourceNode | null = null;
  private meterStream: MediaStream | null = null;
  private meterTimer: number | null = null;

  get speechLanguage(): string {
    const languages = navigator.languages ?? [navigator.language || 'en-US'];
    return languages.find((l) => l.toLowerCase().startsWith('en-') || l === 'en') ?? 'en-US';
  }

  get isSpeechSupported(): boolean {
    const w = window as SpeechWindow;
    return Boolean(w.SpeechRecognition || w.webkitSpeechRecognition);
  }

  installPasteListener(onImageDataUri: (dataUri: string) => void): void {
    this.uninstallPasteListener();
    this.pasteListener = (event: ClipboardEvent) => {
      const items = event.clipboardData?.items;
      if (!items) return;
      for (const item of Array.from(items)) {
        if (!item.type.startsWith('image/')) continue;
        const file = item.getAsFile();
        if (!file) continue;
        void this.fileToDataUri(file)
          .then((uri) => {
            if (uri) onImageDataUri(uri);
          })
          .catch((e) => Logger.e('Paste image decode failed', e));
      }
    };
    window.addEventListener('paste', this.pasteListener);
  }

  uninstallPasteListener(): void {
    if (this.pasteListener) {
      window.removeEventListener('paste', this.pasteListener);
      this.pasteListener = null;
    }
  }

  async fileToDataUri(file: Blob, maxDim = 1280): Promise<string> {
    if (file.size <= 300 * 1024) {
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : '');
        reader.onerror = () => reject(reader.error ?? new Error('Failed to read image'));
        reader.readAsDataURL(file);
      });
    }
    return this.resizeBlobToDataUri(file, maxDim);
  }

  resizeBlobToDataUri(blob: Blob, maxDim = 1280): Promise<string> {
    const objectUrl = URL.createObjectURL(blob);
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        try {
          const maxSide = Math.max(img.naturalWidth, img.naturalHeight) || 1;
          const scale = Math.min(1, maxDim / maxSide);
          const w = Math.max(1, Math.min(4096, Math.round(img.naturalWidth * scale)));
          const h = Math.max(1, Math.min(4096, Math.round(img.naturalHeight * scale)));
          const canvas = document.createElement('canvas');
          canvas.width = w;
          canvas.height = h;
          const ctx = canvas.getContext('2d');
          if (!ctx) throw new Error('Canvas 2D context unavailable');
          ctx.imageSmoothingEnabled = true;
          ctx.imageSmoothingQuality = 'medium';
          ctx.drawImage(img, 0, 0, w, h);
          const isPng = blob.type === 'image/png';
          resolve(canvas.toDataURL(isPng ? 'image/png' : 'image/jpeg', isPng ? undefined : 0.82));
        } catch (e) {
          reject(e);
        } finally {
          URL.revokeObjectURL(objectUrl);
        }
      };
      img.onerror = () => {
        URL.revokeObjectURL(objectUrl);
        reject(new Error('Image could not be loaded'));
      };
      img.src = objectUrl;
    });
  }

  private async startAudioMeter(rec: SpeechRecognitionLike, onLevel: (level: number) => void): Promise<void> {
    try {
      const devices = navigator.mediaDevices;
      const w = window as SpeechWindow;
      const Ctor = window.AudioContext ?? w.webkitAudioContext;
      if (!devices || !Ctor) return;
      const ctx = new Ctor();
      this.audioContext = ctx;
      void ctx.resume().catch((e) => Logger.e('Motchi audio resume failed', e));
      const stream = await devices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
        video: false,
      });
      if (this.recognition !== rec || this.audioContext !== ctx) {
        for (const track of stream.getTracks()) track.stop();
        return;
      }
      this.meterStream = stream;
      const source = ctx.createMediaStreamSource(stream);
      this.audioSource = source;
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 256;
      source.connect(analyser);
      const samples = new Uint8Array(256);
      this.meterTimer = window.setInterval(() => {
        analyser.getByteTimeDomainData(samples);
        let energy = 0;
        for (let i = 0; i < samples.length; i++) {
          const amp = (samples[i] - 128) / 128;
          energy += amp * amp;
        }
        onLevel(Math.min(1, Math.max(0, Math.sqrt(energy / samples.length) * 4)));
      }, 80);
    } catch (e) {
      Logger.e('Motchi voice meter unavailable', e);
      if (this.recognition === rec) this.stopAudioMeter();
    }
  }

  private stopAudioMeter(): void {
    if (this.meterTimer != null) {
      clearInterval(this.meterTimer);
      this.meterTimer = null;
    }
    try {
      this.audioSource?.disconnect();
    } catch {
      // ignore disconnect errors
    }
    this.audioSource = null;
    for (const track of this.meterStream?.getTracks() ?? []) track.stop();
    this.meterStream = null;
    const ctx = this.audioContext;
    this.audioContext = null;
    if (ctx) void ctx.close().catch((e) => Logger.e('Motchi audio close failed', e));
  }

  private finishSpeech(transcript: string | null, opts: { error?: unknown; abort?: boolean } = {}): void {
    if (this.speechTimeout != null) {
      clearTimeout(this.speechTimeout);
      this.speechTimeout = null;
    }
    if (this.voiceVisibilityListener) {
      document.removeEventListener('visibilitychange', this.voiceVisibilityListener);
      this.voiceVisibilityListener = null;
    }
    const rec = this.recognition;
    this.recognition = null;
    if (rec) {
      rec.onresult = null;
      rec.onerror = null;
      rec.onend = null;
      if (opts.abort) {
        try {
          rec.abort();
        } catch {
          // ignore
        }
      }
    }
    this.stopAudioMeter();
    this.speechTranscript = null;
    const resolve = this.speechResolve;
    const reject = this.speechReject;
    this.speechResolve = null;
    this.speechReject = null;
    if (opts.error != null) reject?.(opts.error);
    else resolve?.(transcript);
  }

  stopRecognition(): void {
    const rec = this.recognition;
    if (rec) {
      try {
        rec.stop();
      } catch (e) {
        Logger.e('Motchi microphone could not stop', e);
        this.finishSpeech(this.speechTranscript, { abort: true });
      }
    } else {
      this.finishSpeech(this.speechTranscript);
    }
  }

  cancelRecognition(): void {
    const rec = this.recognition;
    this.finishSpeech(null);
    if (rec) {
      try {
        rec.abort();
      } catch (e) {
        Logger.e('Motchi microphone could not abort', e);
      }
    }
  }

  recognizeOnce({
    lang,
    onTranscript,
    onAudioLevel,
  }: {
    lang?: string;
    onTranscript?: (words: string) => void;
    onAudioLevel?: (level: number) => void;
  } = {}): Promise<string | null> {
    this.cancelRecognition();
    const w = window as SpeechWindow;
    const Ctor = w.SpeechRecognition ?? w.webkitSpeechRecognition;
    if (!Ctor) return Promise.resolve(null);

    const rec = new Ctor();
    this.recognition = rec;
    this.speechTranscript = null;

    return new Promise((resolve, reject) => {
      this.speechResolve = resolve;
      this.speechReject = reject;

      this.voiceVisibilityListener = () => {
        if (document.visibilityState === 'hidden') this.cancelRecognition();
      };
      document.addEventListener('visibilitychange', this.voiceVisibilityListener);

      rec.lang = lang ?? this.speechLanguage;
      rec.interimResults = true;
      rec.maxAlternatives = 1;
      rec.continuous = true;
      rec.onresult = (event) => {
        if (this.recognition !== rec) return;
        try {
          const words: string[] = [];
          for (let i = 0; i < event.results.length; i++) {
            const alt = event.results[i]?.[0];
            const text = alt?.transcript?.trim();
            if (text) words.push(text);
          }
          this.speechTranscript = words.length === 0 ? null : words.join(' ');
          onTranscript?.(this.speechTranscript ?? '');
        } catch (e) {
          this.finishSpeech(null, { error: e });
        }
      };
      rec.onerror = (event) => {
        if (this.recognition !== rec) return;
        const code = event.error ?? 'unknown';
        if (code === 'no-speech') this.finishSpeech(this.speechTranscript, { abort: true });
        else this.finishSpeech(null, { error: new Error(code) });
      };
      rec.onend = () => {
        if (this.recognition === rec) this.finishSpeech(this.speechTranscript);
      };

      try {
        rec.start();
        this.speechTimeout = window.setTimeout(() => this.stopRecognition(), 120000);
        if (onAudioLevel) void this.startAudioMeter(rec, onAudioLevel);
      } catch (e) {
        this.finishSpeech(null, { error: e });
      }
    });
  }
}
