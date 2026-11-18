// Custom player controls overlaid on an HTMLVideoElement (offline or direct
// playback) so saved episodes match the Everglow streaming shell.
import { useCallback, useEffect, useId, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { isEditableTarget, resolveEverglowPlayerKey } from './everglowPlayerKeys';
import { Icon } from './Icon';

const SPEEDS = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0] as const;
const SETTINGS_SPEEDS = [0.75, 1.0, 1.25, 1.5, 2.0] as const;
const BRIGHTNESS_STEPS = [0.5, 0.75, 1.0, 1.25] as const;
const SEEK_STEPS = [5, 10] as const;
const SCREEN_LABELS = ['Fit', 'Fill', 'Zoom'] as const;
const SUB_SIZE_LABELS = ['Small', 'Medium', 'Large'] as const;
const SUB_STYLE_LABELS = ['Outline', 'Pill', 'Box'] as const;
const SUB_COLOR_LABELS = ['White', 'Warm', 'Yellow'] as const;
const SUB_POS_LABELS = ['Low', 'Mid', 'High', 'Top'] as const;

const SHORTCUTS: ReadonlyArray<readonly [string, string]> = [
  ['Space / K', 'Play / Pause'],
  ['J / L', 'Seek step'],
  ['← / →', 'Seek step'],
  ['↑ / ↓', 'Volume'],
  ['M', 'Mute'],
  ['F', 'Fullscreen'],
  ['C', 'Captions'],
  ['G / H', 'Sub delay'],
  ['[ / ]', 'Speed'],
  ['Z', 'Screen fit'],
  ['I', 'Stream stats'],
  [', / .', 'Frame step'],
  ['0–9', 'Jump %'],
];

const white = (a: number) => `rgba(255, 255, 255, ${a})`;
const black = (a: number) => `rgba(0, 0, 0, ${a})`;

function formatTime(seconds: number): string {
  const total = Number.isFinite(seconds) && seconds >= 0 ? Math.floor(seconds) : 0;
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const mm = h > 0 ? String(m).padStart(2, '0') : String(m);
  const ss = String(s).padStart(2, '0');
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
}

export interface OfflineVideoHudProps {
  video: HTMLVideoElement;
  host: HTMLElement | null;
  title?: string;
  nextLabel?: string;
  onNextEpisode?: () => void;
  onShowEpisodes?: () => void;
  accentColor?: string;
}

interface SavedStyles {
  objectFit: string;
  transform: string;
  filter: string;
}

/**
 * Renders the custom Everglow playback HUD over a direct/offline `<video>`.
 */
export function OfflineVideoHud({
  video,
  host,
  title = '',
  nextLabel,
  onNextEpisode,
  onShowEpisodes,
  accentColor = AppColors.deepRose,
}: OfflineVideoHudProps) {
  const uid = useId().replace(/[^a-zA-Z0-9_-]/g, '');
  const scopeClass = `eg-off-${uid}`;

  const rootRef = useRef<HTMLDivElement>(null);
  const scrubRef = useRef<HTMLDivElement>(null);

  const [isCompact, setIsCompact] = useState(false);
  const [hudVisible, setHudVisible] = useState(true);
  const [locked, setLocked] = useState(false);
  const [showRemaining, setShowRemaining] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [ccOpen, setCcOpen] = useState(false);
  const [keysOpen, setKeysOpen] = useState(false);
  const [statsOn, setStatsOn] = useState(false);
  const [ccQuery, setCcQuery] = useState('');
  const [selectedTrack, setSelectedTrack] = useState(-1);
  const [aspectMode, setAspectMode] = useState(0);
  const [seekStep, setSeekStep] = useState<number>(10);
  const [subSize, setSubSize] = useState(1);
  const [subStyle, setSubStyle] = useState(0);
  const [subColor, setSubColor] = useState(0);
  const [subPos, setSubPos] = useState(0);
  const [subDelay, setSubDelay] = useState(0);
  const [brightness, setBrightness] = useState(1.0);
  const [hoverFraction, setHoverFraction] = useState<number | null>(null);
  const [scrubSeconds, setScrubSeconds] = useState<number | null>(null);
  const [seekFlash, setSeekFlash] = useState<string | null>(null);
  const [, bump] = useState(0);

  const hideTimer = useRef<number | null>(null);
  const flashTimer = useRef<number | null>(null);
  const chainTimer = useRef<number | null>(null);
  const seekChainDelta = useRef(0);
  const lastPointerType = useRef<string>('mouse');
  const origCueTimes = useRef(new WeakMap<TextTrack, Array<[number, number]>>());
  const cueStyleEl = useRef<HTMLStyleElement | null>(null);

  const lockedRef = useRef(locked);
  lockedRef.current = locked;
  const openMenuRef = useRef(false);
  openMenuRef.current = settingsOpen || ccOpen || keysOpen;

  const duration = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : 0;
  const position = Number.isFinite(video.currentTime) && video.currentTime >= 0 ? video.currentTime : 0;
  const trackCount = video.textTracks?.length ?? 0;
  const hasTracks = trackCount > 0;
  const ccEnabled = selectedTrack >= 0 && hasTracks;

  const clearTimer = (ref: { current: number | null }) => {
    if (ref.current != null) {
      window.clearTimeout(ref.current);
      ref.current = null;
    }
  };

  const scheduleHide = useCallback(() => {
    clearTimer(hideTimer);
    if (video.paused || lockedRef.current || openMenuRef.current) return;
    hideTimer.current = window.setTimeout(() => {
      if (!video.paused && !openMenuRef.current) setHudVisible(false);
    }, 3000);
  }, [video]);

  const revealHud = useCallback(() => {
    setHudVisible(true);
    scheduleHide();
  }, [scheduleHide]);

  const flashMessage = useCallback((label: string) => {
    clearTimer(flashTimer);
    setSeekFlash(label);
    flashTimer.current = window.setTimeout(() => setSeekFlash(null), 750);
  }, []);

  useEffect(() => {
    const el = rootRef.current;
    if (!el || typeof ResizeObserver === 'undefined') return;
    setIsCompact(el.clientWidth < 520);
    const ro = new ResizeObserver((entries) => {
      const w = entries[0]?.contentRect.width ?? el.clientWidth;
      setIsCompact(w < 520);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const saved: SavedStyles = {
      objectFit: video.style.objectFit,
      transform: video.style.transform,
      filter: video.style.filter,
    };

    let active = -1;
    for (let i = 0; i < (video.textTracks?.length ?? 0); i++) {
      if (video.textTracks[i]?.mode === 'showing') {
        active = i;
        break;
      }
    }
    setSelectedTrack(active);

    const refresh = () => bump((n) => n + 1);
    const onPlay = () => {
      refresh();
      scheduleHide();
    };
    const onPause = () => {
      clearTimer(hideTimer);
      setHudVisible(true);
      refresh();
    };

    video.addEventListener('play', onPlay);
    video.addEventListener('pause', onPause);
    video.addEventListener('timeupdate', refresh);
    video.addEventListener('volumechange', refresh);
    video.addEventListener('ratechange', refresh);
    video.addEventListener('loadedmetadata', refresh);
    const onTracksChanged = () => {
      let cur = -1;
      for (let i = 0; i < (video.textTracks?.length ?? 0); i++) {
        if (video.textTracks[i]?.mode === 'showing') {
          cur = i;
          break;
        }
      }
      setSelectedTrack(cur);
      refresh();
    };
    video.textTracks?.addEventListener?.('addtrack', onTracksChanged);
    video.textTracks?.addEventListener?.('removetrack', onTracksChanged);
    video.textTracks?.addEventListener?.('change', onTracksChanged);

    scheduleHide();

    return () => {
      video.removeEventListener('play', onPlay);
      video.removeEventListener('pause', onPause);
      video.removeEventListener('timeupdate', refresh);
      video.removeEventListener('volumechange', refresh);
      video.removeEventListener('ratechange', refresh);
      video.removeEventListener('loadedmetadata', refresh);
      video.textTracks?.removeEventListener?.('addtrack', onTracksChanged);
      video.textTracks?.removeEventListener?.('removetrack', onTracksChanged);
      video.textTracks?.removeEventListener?.('change', onTracksChanged);
      video.classList.remove(scopeClass);
      video.style.objectFit = saved.objectFit;
      video.style.transform = saved.transform;
      video.style.filter = saved.filter;
    };
  }, [video, scopeClass, scheduleHide]);

  useEffect(() => {
    return () => {
      clearTimer(hideTimer);
      clearTimer(flashTimer);
      clearTimer(chainTimer);
      cueStyleEl.current?.remove();
      cueStyleEl.current = null;
    };
  }, []);

  const syncCueStyle = useCallback(
    (nextSize: number, nextStyle: number, nextColor: number, nextPos: number) => {
      video.classList.add(scopeClass);
      let styleEl = cueStyleEl.current;
      if (!styleEl) {
        styleEl = document.createElement('style');
        document.head?.appendChild(styleEl);
        cueStyleEl.current = styleEl;
      }
      const fontSizes = ['15px', '19px', '24px'];
      const colors = ['rgb(255, 255, 255)', 'rgb(255, 241, 208)', 'rgb(255, 230, 102)'];
      const bgs = ['transparent', 'rgba(10, 6, 14, 0.74)', 'rgba(0, 0, 0, 0.92)'];
      const lineHeights = ['1.35', '2.1', '3.0', '4.2'];
      const shadow =
        nextStyle === 2
          ? 'none'
          : '-1.5px -1.5px 0 rgba(0,0,0,0.94), 1.5px -1.5px 0 rgba(0,0,0,0.94), -1.5px 1.5px 0 rgba(0,0,0,0.94), 1.5px 1.5px 0 rgba(0,0,0,0.94), 0 2px 6px rgba(0,0,0,0.95)';
      styleEl.textContent =
        `video.${scopeClass}::cue{` +
        `font-size:${fontSizes[nextSize]};` +
        `color:${colors[nextColor]};` +
        `background-color:${bgs[nextStyle]};` +
        `text-shadow:${shadow};` +
        `line-height:${lineHeights[Math.min(Math.max(nextPos, 0), lineHeights.length - 1)]};` +
        'font-weight:800;}';
    },
    [video, scopeClass],
  );

  const togglePlay = useCallback(() => {
    if (video.paused) void video.play().catch(() => undefined);
    else video.pause();
    revealHud();
  }, [video, revealHud]);

  const seekBy = useCallback(
    (deltaSeconds: number) => {
      const dur = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : Infinity;
      const cur = Number.isFinite(video.currentTime) && video.currentTime >= 0 ? video.currentTime : 0;
      video.currentTime = Math.min(Math.max(cur + deltaSeconds, 0), dur);
      clearTimer(chainTimer);
      clearTimer(flashTimer);
      seekChainDelta.current += deltaSeconds;
      const d = seekChainDelta.current;
      setSeekFlash(d > 0 ? `+${d}s` : `${d}s`);
      chainTimer.current = window.setTimeout(() => {
        seekChainDelta.current = 0;
      }, 850);
      flashTimer.current = window.setTimeout(() => setSeekFlash(null), 700);
      scheduleHide();
    },
    [video, scheduleHide],
  );

  const toggleMute = useCallback(() => {
    video.muted = !video.muted;
    revealHud();
  }, [video, revealHud]);

  const trackLabel = useCallback(
    (index: number) => {
      const t = video.textTracks[index];
      const lbl = t?.label?.trim();
      if (lbl) return lbl;
      const lang = t?.language?.trim();
      return lang ? lang.toUpperCase() : `Track ${index + 1}`;
    },
    [video],
  );

  const selectTrack = useCallback(
    (index: number) => {
      const tracks = video.textTracks;
      if (!tracks || tracks.length === 0) return;
      const target = index >= 0 && index < tracks.length ? index : -1;
      for (let i = 0; i < tracks.length; i++) {
        tracks[i]!.mode = i === target ? 'showing' : 'disabled';
      }
      setSelectedTrack(target);
      flashMessage(target >= 0 ? `Captions: ${trackLabel(target)}` : 'Captions: Off');
      revealHud();
    },
    [video, flashMessage, trackLabel, revealHud],
  );

  const toggleCc = useCallback(() => {
    const tracks = video.textTracks;
    if (!tracks || tracks.length === 0) return;
    const next = selectedTrack + 1 >= tracks.length ? -1 : selectedTrack + 1;
    selectTrack(next);
  }, [video, selectedTrack, selectTrack]);

  const adjustSubDelay = useCallback(
    (delta: number) => {
      const next = Math.round(Math.min(Math.max(subDelay + delta, -10), 10) * 10) / 10;
      setSubDelay(next);
      const tracks = video.textTracks;
      for (let i = 0; i < (tracks?.length ?? 0); i++) {
        const track = tracks[i]!;
        const cues = track.cues;
        if (!cues) continue;
        let orig = origCueTimes.current.get(track);
        if (!orig || orig.length !== cues.length) {
          orig = [];
          for (let j = 0; j < cues.length; j++) {
            orig.push([cues[j]!.startTime, cues[j]!.endTime]);
          }
          origCueTimes.current.set(track, orig);
        }
        for (let j = 0; j < cues.length; j++) {
          const [baseS, baseE] = orig[j]!;
          const s = Math.max(baseS + next, 0);
          const e = Math.max(baseE + next, s + 0.05);
          cues[j]!.startTime = s;
          cues[j]!.endTime = e;
        }
      }
      const lbl = next === 0 ? '0.0s' : `${next > 0 ? '+' : ''}${next.toFixed(1)}s`;
      flashMessage(`Sub delay: ${lbl}`);
      revealHud();
    },
    [video, subDelay, flashMessage, revealHud],
  );

  const setSpeed = useCallback(
    (speed: number) => {
      video.playbackRate = speed;
      flashMessage(`Speed ${speed === 1 ? '1x' : `${speed}x`}`);
      revealHud();
    },
    [video, flashMessage, revealHud],
  );

  const currentSpeedIndex = useCallback(() => {
    const cur = video.playbackRate;
    const idx = SPEEDS.findIndex((s) => Math.abs(s - cur) < 0.05);
    return idx >= 0 ? idx : 3;
  }, [video]);

  const stepSpeed = useCallback(
    (delta: number) => {
      const idx = currentSpeedIndex();
      const next = SPEEDS[Math.min(Math.max(idx + delta, 0), SPEEDS.length - 1)]!;
      setSpeed(next);
    },
    [currentSpeedIndex, setSpeed],
  );

  const cycleSpeed = useCallback(() => {
    const idx = currentSpeedIndex();
    const next = SPEEDS[(idx + 1) % SPEEDS.length]!;
    setSpeed(next);
  }, [currentSpeedIndex, setSpeed]);

  const applyScreenMode = useCallback(
    (mode: number) => {
      const m = ((mode % 3) + 3) % 3;
      setAspectMode(m);
      video.style.objectFit = m === 0 ? 'contain' : 'cover';
      video.style.transform = m === 2 ? 'scale(1.18)' : '';
      flashMessage(`Screen: ${SCREEN_LABELS[m]}`);
      revealHud();
    },
    [video, flashMessage, revealHud],
  );

  const toggleFill = useCallback(() => applyScreenMode((aspectMode + 1) % 3), [aspectMode, applyScreenMode]);

  const setBrightnessValue = useCallback(
    (value: number) => {
      const clamped = Math.min(Math.max(value, 0.4), 1.25);
      setBrightness(clamped);
      video.style.filter = Math.abs(clamped - 1.0) < 0.02 ? '' : `brightness(${clamped.toFixed(2)})`;
    },
    [video],
  );

  const cycleBrightness = useCallback(() => {
    const idx = BRIGHTNESS_STEPS.findIndex((b) => Math.abs(b - brightness) < 0.06);
    const next = BRIGHTNESS_STEPS[(idx + 1) % BRIGHTNESS_STEPS.length]!;
    setBrightnessValue(next);
    flashMessage(`Brightness ${Math.round(next * 100)}%`);
    revealHud();
  }, [brightness, setBrightnessValue, flashMessage, revealHud]);

  const toggleStats = useCallback(() => {
    setStatsOn((v) => {
      const next = !v;
      flashMessage(next ? 'Stats: On' : 'Stats: Off');
      return next;
    });
    revealHud();
  }, [flashMessage, revealHud]);

  const toggleFullscreen = useCallback(() => {
    if (document.fullscreenElement != null) {
      void document.exitFullscreen().catch(() => undefined);
    } else {
      void (host ?? video).requestFullscreen?.().catch(() => undefined);
    }
    revealHud();
  }, [host, video, revealHud]);

  const togglePip = useCallback(() => {
    try {
      if (document.pictureInPictureElement != null) {
        void document.exitPictureInPicture().catch(() => undefined);
      } else if (document.pictureInPictureEnabled) {
        void video.requestPictureInPicture?.().catch(() => undefined);
      }
    } catch {
      // Picture-in-Picture may be unsupported on some browsers.
    }
    revealHud();
  }, [video, revealHud]);

  const toggleHud = useCallback(() => {
    if (settingsOpen || ccOpen || keysOpen) {
      setSettingsOpen(false);
      setCcOpen(false);
      setKeysOpen(false);
      scheduleHide();
      return;
    }
    setHudVisible((v) => {
      const next = !v;
      if (next) scheduleHide();
      return next;
    });
  }, [settingsOpen, ccOpen, keysOpen, scheduleHide]);

  // Document-level keyboard shortcuts mirroring the online player shell.
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.ctrlKey || event.metaKey || event.altKey) return;
      if (isEditableTarget(event.target)) return;
      const key = resolveEverglowPlayerKey(event.key) ?? event.key;
      if (lockedRef.current) {
        if (key === ' ' || key === 'k' || key === 'K' || key === 'Escape') {
          revealHud();
          event.preventDefault();
        }
        return;
      }
      const dur = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : 0;
      const pos = Number.isFinite(video.currentTime) && video.currentTime >= 0 ? video.currentTime : 0;
      switch (key) {
        case ' ':
        case 'k':
        case 'K':
          togglePlay();
          event.preventDefault();
          return;
        case 'ArrowLeft':
        case 'j':
        case 'J':
          seekBy(-seekStep);
          event.preventDefault();
          return;
        case 'ArrowRight':
        case 'l':
        case 'L':
          seekBy(seekStep);
          event.preventDefault();
          return;
        case 'ArrowUp': {
          const upVol = Math.min(Math.max(video.volume + 0.1, 0), 1);
          video.volume = upVol;
          video.muted = false;
          flashMessage(`Vol ${Math.round(upVol * 100)}%`);
          revealHud();
          event.preventDefault();
          return;
        }
        case 'ArrowDown': {
          const dnVol = Math.min(Math.max(video.volume - 0.1, 0), 1);
          video.volume = dnVol;
          video.muted = dnVol === 0;
          flashMessage(dnVol === 0 ? 'Muted' : `Vol ${Math.round(dnVol * 100)}%`);
          revealHud();
          event.preventDefault();
          return;
        }
        case 'Home':
          if (dur > 0) {
            video.currentTime = 0;
            revealHud();
          }
          event.preventDefault();
          return;
        case 'End':
          if (dur > 0) {
            video.currentTime = dur;
            revealHud();
          }
          event.preventDefault();
          return;
        case 'n':
        case 'N':
          if (onNextEpisode) {
            onNextEpisode();
            event.preventDefault();
          }
          return;
        case 'm':
        case 'M':
          toggleMute();
          event.preventDefault();
          return;
        case 'f':
        case 'F':
          toggleFullscreen();
          event.preventDefault();
          return;
        case 'z':
        case 'Z':
          toggleFill();
          event.preventDefault();
          return;
        case 'c':
        case 'C':
          if (hasTracks) toggleCc();
          event.preventDefault();
          return;
        case 'g':
        case 'G':
          if (hasTracks) adjustSubDelay(-0.1);
          event.preventDefault();
          return;
        case 'h':
        case 'H':
          if (hasTracks) adjustSubDelay(0.1);
          event.preventDefault();
          return;
        case '[':
        case '<':
          stepSpeed(-1);
          event.preventDefault();
          return;
        case ']':
        case '>':
          stepSpeed(1);
          event.preventDefault();
          return;
        case 'i':
        case 'I':
          toggleStats();
          event.preventDefault();
          return;
        case ',':
        case '.':
          if (video.paused && dur > 0) {
            const step = key === '.' ? 1 / 24 : -1 / 24;
            video.currentTime = Math.min(Math.max(pos + step, 0), dur);
            flashMessage(key === '.' ? 'Frame +1' : 'Frame -1');
          }
          event.preventDefault();
          return;
        case '?':
          clearTimer(hideTimer);
          setKeysOpen((v) => !v);
          setSettingsOpen(false);
          setCcOpen(false);
          event.preventDefault();
          return;
        case 'Escape':
          if (keysOpen || settingsOpen || ccOpen) {
            setKeysOpen(false);
            setSettingsOpen(false);
            setCcOpen(false);
            scheduleHide();
            event.preventDefault();
          }
          return;
        default:
          if (key.length === 1 && key >= '0' && key <= '9' && dur > 0) {
            const pct = Number(key) / 10;
            video.currentTime = dur * pct;
            flashMessage(`${Math.round(pct * 100)}%`);
            revealHud();
            event.preventDefault();
          }
      }
    };
    document.addEventListener('keydown', onKeyDown);
    return () => document.removeEventListener('keydown', onKeyDown);
  }, [
    video,
    seekStep,
    hasTracks,
    keysOpen,
    settingsOpen,
    ccOpen,
    onNextEpisode,
    revealHud,
    togglePlay,
    seekBy,
    flashMessage,
    toggleMute,
    toggleFullscreen,
    toggleFill,
    toggleCc,
    adjustSubDelay,
    stepSpeed,
    toggleStats,
    scheduleHide,
  ]);

  const paused = video.paused;
  const muted = video.muted || video.volume === 0;
  const rate = video.playbackRate || 1;
  const speedLabel = `${rate}x`;
  const pos = Math.min(Math.max(scrubSeconds ?? position, 0), duration > 0 ? duration : 1);
  const remaining = duration > 0 ? Math.max(duration - pos, 0) : 0;
  const showNext = onNextEpisode != null && duration > 0 && remaining <= 120;
  const cleanTitle = title.trim();

  const statsLabel = (() => {
    const w = video.videoWidth;
    const h = video.videoHeight;
    const res = w > 0 && h > 0 ? `${w}x${h}` : 'Direct';
    let bufSec = 0;
    const buffered = video.buffered;
    for (let i = 0; i < (buffered?.length ?? 0); i++) {
      const start = buffered.start(i);
      const end = buffered.end(i);
      if (position >= start - 0.5 && end - position > bufSec) bufSec = end - position;
    }
    const speedLbl = rate === 1 ? '1x' : `${rate}x`;
    return `${res} · Buffer ${bufSec.toFixed(1)}s · Speed ${speedLbl}`;
  })();

  const handleScrubPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    if (duration <= 0) return;
    e.stopPropagation();
    const el = scrubRef.current;
    if (!el) return;
    el.setPointerCapture(e.pointerId);
    clearTimer(hideTimer);
    const updateFromClientX = (clientX: number) => {
      const r = el.getBoundingClientRect();
      const frac = r.width > 0 ? Math.min(Math.max((clientX - r.left) / r.width, 0), 1) : 0;
      setScrubSeconds(frac * duration);
      return frac * duration;
    };
    let lastSec = updateFromClientX(e.clientX);
    const onMove = (ev: PointerEvent) => {
      lastSec = updateFromClientX(ev.clientX);
    };
    const onUp = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('pointercancel', onUp);
      video.currentTime = lastSec;
      setScrubSeconds(null);
      scheduleHide();
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointercancel', onUp);
  };

  return (
    <div
      ref={rootRef}
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 4,
        pointerEvents: 'auto',
        userSelect: 'none',
      }}
    >
      {/* Left/Right gesture zones */}
      <div style={{ position: 'absolute', inset: 0, display: 'flex' }}>
        <GestureZone
          isRight={false}
          locked={locked}
          duration={duration}
          position={position}
          video={video}
          brightness={brightness}
          seekStep={seekStep}
          lastPointerType={lastPointerType}
          onReveal={revealHud}
          onToggleHud={toggleHud}
          onTogglePlay={togglePlay}
          onToggleFullscreen={toggleFullscreen}
          onSeekBy={seekBy}
          onSeekTo={(sec) => {
            video.currentTime = sec;
          }}
          onSetBrightness={setBrightnessValue}
          onFlash={flashMessage}
          onClearFlash={() => setSeekFlash(null)}
        />
        <GestureZone
          isRight={true}
          locked={locked}
          duration={duration}
          position={position}
          video={video}
          brightness={brightness}
          seekStep={seekStep}
          lastPointerType={lastPointerType}
          onReveal={revealHud}
          onToggleHud={toggleHud}
          onTogglePlay={togglePlay}
          onToggleFullscreen={toggleFullscreen}
          onSeekBy={seekBy}
          onSeekTo={(sec) => {
            video.currentTime = sec;
          }}
          onSetBrightness={setBrightnessValue}
          onFlash={flashMessage}
          onClearFlash={() => setSeekFlash(null)}
        />
      </div>

      {/* Transient seek / speed / volume / brightness feedback badge */}
      {seekFlash != null && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            pointerEvents: 'none',
          }}
        >
          <PillBadge label={seekFlash} background={withAlpha(AppColors.inkDeep, 0.85)} />
        </div>
      )}

      {/* Lock overlay */}
      {locked && hudVisible && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 18,
            display: 'flex',
            justifyContent: 'center',
          }}
        >
          <HudChipButton
            icon="lock_open"
            label="Tap to unlock"
            onTap={() => {
              setLocked(false);
              scheduleHide();
            }}
          />
        </div>
      )}

      {/* Main unlocked HUD */}
      {!locked && (hudVisible || paused) && (
        <>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              pointerEvents: 'none',
              background: `linear-gradient(to bottom, ${black(0.65)} 0%, transparent 25%, transparent 62%, ${black(0.78)} 100%)`,
            }}
          />

          {/* Top bar */}
          <div
            style={{
              position: 'absolute',
              top: isCompact ? 8 : 12,
              left: isCompact ? 10 : 14,
              right: isCompact ? 10 : 14,
              display: 'flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            {cleanTitle && <PillBadge label={cleanTitle} background={withAlpha(AppColors.inkDeep, 0.72)} maxWidth="60%" />}
            <div style={{ flex: 1 }} />
            <HudIconButton
              icon="brightness_6"
              tooltip={`Brightness (${Math.round(brightness * 100)}%)`}
              active={Math.abs(brightness - 1.0) > 0.05}
              accent={accentColor}
              onTap={cycleBrightness}
            />
            <HudIconButton
              icon="aspect_ratio"
              tooltip={SCREEN_LABELS[aspectMode] ?? 'Fit'}
              active={aspectMode !== 0}
              accent={accentColor}
              onTap={toggleFill}
            />
            <HudIconButton
              icon="lock_outline"
              tooltip="Lock screen"
              onTap={() => {
                clearTimer(hideTimer);
                setLocked(true);
                setSettingsOpen(false);
                setCcOpen(false);
                setKeysOpen(false);
                setHudVisible(true);
              }}
            />
          </div>

          {/* Center transport */}
          <div
            style={{
              position: 'absolute',
              top: '50%',
              left: '50%',
              transform: 'translate(-50%, -50%)',
              display: 'flex',
              alignItems: 'center',
              gap: isCompact ? 14 : 18,
              pointerEvents: 'none',
            }}
          >
            <div style={{ pointerEvents: 'auto' }}>
              <HudIconButton
                icon={seekStep === 5 ? 'replay_5' : 'replay_10'}
                tooltip={`Back ${seekStep}s`}
                size={isCompact ? 20 : 22}
                padding={isCompact ? 8 : 10}
                onTap={() => seekBy(-seekStep)}
              />
            </div>
            <div style={{ pointerEvents: 'auto' }}>
              <HudIconButton
                icon={paused ? 'play_arrow' : 'pause'}
                tooltip={paused ? 'Play' : 'Pause'}
                size={isCompact ? 28 : 32}
                padding={isCompact ? 10 : 12}
                background={withAlpha(accentColor, 0.92)}
                onTap={togglePlay}
              />
            </div>
            <div style={{ pointerEvents: 'auto' }}>
              <HudIconButton
                icon={seekStep === 5 ? 'forward_5' : 'forward_10'}
                tooltip={`Forward ${seekStep}s`}
                size={isCompact ? 20 : 22}
                padding={isCompact ? 8 : 10}
                onTap={() => seekBy(seekStep)}
              />
            </div>
          </div>

          {/* Bottom bar */}
          <div
            style={{
              position: 'absolute',
              left: isCompact ? 10 : 14,
              right: isCompact ? 10 : 14,
              bottom: isCompact ? 6 : 10,
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            {showNext && onNextEpisode && (
              <div style={{ display: 'flex', justifyContent: 'flex-end', paddingBottom: 8 }}>
                <HudChipButton
                  icon="skip_next"
                  label={nextLabel ?? 'Next episode'}
                  background={accentColor}
                  onTap={onNextEpisode}
                />
              </div>
            )}

            {/* Scrub bar */}
            <div
              ref={scrubRef}
              role="slider"
              tabIndex={0}
              aria-label="Seek"
              aria-valuemin={0}
              aria-valuemax={Math.round(duration)}
              aria-valuenow={Math.round(pos)}
              aria-valuetext={`${formatTime(pos)} of ${formatTime(duration)}`}
              className="player-focusable"
              onPointerDown={handleScrubPointerDown}
              onPointerMove={(e) => {
                if (duration <= 0) return;
                const el = scrubRef.current;
                if (!el) return;
                const r = el.getBoundingClientRect();
                if (r.width > 0) setHoverFraction(Math.min(Math.max((e.clientX - r.left) / r.width, 0), 1));
              }}
              onPointerLeave={() => setHoverFraction(null)}
              onKeyDown={(e) => {
                if (e.key === 'ArrowLeft') {
                  e.stopPropagation();
                  e.preventDefault();
                  seekBy(-seekStep);
                } else if (e.key === 'ArrowRight') {
                  e.stopPropagation();
                  e.preventDefault();
                  seekBy(seekStep);
                }
              }}
              style={{
                position: 'relative',
                height: 22,
                display: 'flex',
                alignItems: 'center',
                cursor: duration > 0 ? 'pointer' : 'default',
                touchAction: 'none',
              }}
            >
              <div
                style={{
                  position: 'relative',
                  width: '100%',
                  height: 3.5,
                  borderRadius: AppRadius.full,
                  background: white(0.25),
                }}
              >
                <div
                  style={{
                    height: '100%',
                    width: `${duration > 0 ? (pos / duration) * 100 : 0}%`,
                    borderRadius: AppRadius.full,
                    background: accentColor,
                  }}
                />
                {duration > 0 && (
                  <div
                    style={{
                      position: 'absolute',
                      top: '50%',
                      left: `${(pos / duration) * 100}%`,
                      transform: 'translate(-50%, -50%)',
                      width: 13,
                      height: 13,
                      borderRadius: '50%',
                      background: '#fff',
                      boxShadow: `0 1px 4px ${black(0.45)}`,
                    }}
                  />
                )}
              </div>
              {hoverFraction != null && duration > 0 && (
                <div
                  style={{
                    position: 'absolute',
                    left: `clamp(0px, calc(${hoverFraction * 100}% - 26px), calc(100% - 52px))`,
                    top: -24,
                    pointerEvents: 'none',
                  }}
                >
                  <PillBadge label={formatTime(hoverFraction * duration)} background={withAlpha(AppColors.inkDeep, 0.9)} />
                </div>
              )}
            </div>

            {/* Bottom transport controls */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <HudIconButton icon={paused ? 'play_arrow' : 'pause'} tooltip={paused ? 'Play' : 'Pause'} onTap={togglePlay} />
              <HudIconButton icon={muted ? 'volume_off' : 'volume_up'} tooltip={muted ? 'Unmute' : 'Mute'} onTap={toggleMute} />
              <button
                type="button"
                className="bare-button player-focusable"
                aria-label="Toggle elapsed or remaining time"
                onClick={() => setShowRemaining((v) => !v)}
                style={{
                  padding: '3px 7px',
                  borderRadius: AppRadius.sm,
                  background: white(0.08),
                  ...AppTypography.outfitWhite,
                  fontSize: 12,
                  lineHeight: lineHeight(12),
                  fontVariantNumeric: 'tabular-nums',
                }}
              >
                {showRemaining && duration > 0
                  ? `-${formatTime(remaining)} / ${formatTime(duration)}`
                  : `${formatTime(pos)} / ${formatTime(duration)}`}
              </button>
              <div style={{ flex: 1 }} />
              {onShowEpisodes && <HudIconButton icon="playlist_play" tooltip="Episodes" onTap={onShowEpisodes} />}
              {hasTracks && (
                <HudIconButton
                  icon={ccEnabled ? 'closed_caption' : 'closed_caption_off'}
                  tooltip="Subtitles"
                  active={ccOpen || ccEnabled}
                  accent={accentColor}
                  onTap={() => {
                    const next = !ccOpen;
                    setCcOpen(next);
                    setSettingsOpen(false);
                    setKeysOpen(false);
                    if (next) clearTimer(hideTimer);
                    else scheduleHide();
                  }}
                />
              )}
              <HudChipButton label={speedLabel} onTap={cycleSpeed} />
              <HudIconButton icon="aspect_ratio" tooltip="Screen: Fit / Fill / Zoom" onTap={toggleFill} />
              <HudIconButton
                icon="settings"
                tooltip="Settings"
                active={settingsOpen}
                accent={accentColor}
                onTap={() => {
                  const next = !settingsOpen;
                  setSettingsOpen(next);
                  setCcOpen(false);
                  setKeysOpen(false);
                  if (next) clearTimer(hideTimer);
                  else scheduleHide();
                }}
              />
              {typeof document !== 'undefined' && document.pictureInPictureEnabled && (
                <HudIconButton icon="picture_in_picture_alt" tooltip="Picture-in-Picture" onTap={togglePip} />
              )}
              <HudIconButton
                icon={typeof document !== 'undefined' && document.fullscreenElement != null ? 'fullscreen_exit' : 'fullscreen'}
                tooltip="Fullscreen"
                onTap={toggleFullscreen}
              />
            </div>
          </div>
        </>
      )}

      {/* Stream stats badge */}
      {statsOn && !locked && (
        <div
          style={{
            position: 'absolute',
            top: isCompact ? 46 : 54,
            left: isCompact ? 10 : 14,
            pointerEvents: 'none',
          }}
        >
          <PillBadge label={statsLabel} background={withAlpha(AppColors.inkDeep, 0.86)} />
        </div>
      )}

      {/* Player Settings Popover */}
      {settingsOpen && !locked && (
        <SheetShell
          title="Player settings"
          isCompact={isCompact}
          accent={accentColor}
          onClose={() => {
            setSettingsOpen(false);
            scheduleHide();
          }}
          leftColumn={
            <>
              <SettingsGroup title="SPEED">
                {SETTINGS_SPEEDS.map((s) => (
                  <SettingsChip
                    key={s}
                    label={s === 1 ? '1x' : `${s}x`}
                    active={Math.abs(rate - s) < 0.05}
                    accent={accentColor}
                    onTap={() => setSpeed(s)}
                  />
                ))}
              </SettingsGroup>
              <SettingsGroup title="SKIP INTERVAL">
                {SEEK_STEPS.map((step) => (
                  <SettingsChip
                    key={step}
                    label={`${step}s`}
                    active={seekStep === step}
                    accent={accentColor}
                    onTap={() => {
                      setSeekStep(step);
                      flashMessage(`Skip interval: ${step}s`);
                      revealHud();
                    }}
                  />
                ))}
              </SettingsGroup>
              <SettingsGroup title="SCREEN">
                {SCREEN_LABELS.map((lbl, i) => (
                  <SettingsChip
                    key={lbl}
                    label={lbl}
                    active={aspectMode === i}
                    accent={accentColor}
                    onTap={() => applyScreenMode(i)}
                  />
                ))}
              </SettingsGroup>
            </>
          }
          rightColumn={
            <>
              <SettingsGroup title="BRIGHTNESS">
                {BRIGHTNESS_STEPS.map((b) => (
                  <SettingsChip
                    key={b}
                    label={`${Math.round(b * 100)}%`}
                    active={Math.abs(brightness - b) < 0.06}
                    accent={accentColor}
                    onTap={() => {
                      setBrightnessValue(b);
                      flashMessage(`Brightness ${Math.round(b * 100)}%`);
                      revealHud();
                    }}
                  />
                ))}
              </SettingsGroup>
              <SettingsGroup title="AUDIO">
                <SettingsChip
                  label="On"
                  active={!muted}
                  accent={accentColor}
                  onTap={() => {
                    video.muted = false;
                    flashMessage('Audio On');
                    revealHud();
                  }}
                />
                <SettingsChip
                  label="Mute"
                  active={muted}
                  accent={accentColor}
                  onTap={() => {
                    video.muted = true;
                    flashMessage('Muted');
                    revealHud();
                  }}
                />
              </SettingsGroup>
              <SettingsGroup title="TOOLS">
                <SettingsChip
                  label="Shortcuts (?)"
                  active={false}
                  accent={accentColor}
                  onTap={() => {
                    setSettingsOpen(false);
                    setKeysOpen(true);
                    clearTimer(hideTimer);
                  }}
                />
                <SettingsChip label={statsOn ? 'Stats: On' : 'Stats: Off'} active={statsOn} accent={accentColor} onTap={toggleStats} />
              </SettingsGroup>
            </>
          }
        />
      )}

      {/* Subtitles Popover */}
      {ccOpen && !locked && (
        <SheetShell
          title="Subtitles"
          isCompact={isCompact}
          accent={accentColor}
          onClose={() => {
            setCcOpen(false);
            scheduleHide();
          }}
          leftColumn={
            <>
              <SettingsGroup title="CAPTIONS">
                <SettingsChip label="Off" active={!ccEnabled} accent={accentColor} onTap={() => selectTrack(-1)} />
                <SettingsChip
                  label="On"
                  active={ccEnabled}
                  accent={accentColor}
                  onTap={() => selectTrack(selectedTrack >= 0 ? selectedTrack : 0)}
                />
              </SettingsGroup>
              {trackCount > 6 && (
                <input
                  type="search"
                  value={ccQuery}
                  onChange={(e) => setCcQuery(e.target.value)}
                  placeholder="Filter languages…"
                  aria-label="Filter languages"
                  style={{
                    width: '100%',
                    padding: '6px 8px',
                    borderRadius: AppRadius.xs,
                    border: 'none',
                    background: white(0.08),
                    color: '#fff',
                    fontSize: 11,
                    outline: 'none',
                  }}
                />
              )}
              <SettingsGroup title="LANGUAGE">
                {Array.from({ length: trackCount }, (_, i) => {
                  const lbl = trackLabel(i);
                  const q = ccQuery.trim().toLowerCase();
                  if (q && !lbl.toLowerCase().includes(q)) return null;
                  return (
                    <SettingsChip
                      key={i}
                      label={lbl}
                      active={selectedTrack === i}
                      accent={accentColor}
                      onTap={() => selectTrack(i)}
                    />
                  );
                })}
              </SettingsGroup>
            </>
          }
          rightColumn={
            <>
              <SettingsGroup title="SUBTITLE DELAY">
                <SettingsChip label="-" active={false} accent={accentColor} onTap={() => adjustSubDelay(-0.1)} />
                <SettingsChip
                  label={subDelay === 0 ? '0.0s' : `${subDelay > 0 ? '+' : ''}${subDelay.toFixed(1)}s`}
                  active={subDelay !== 0}
                  accent={accentColor}
                  onTap={() => adjustSubDelay(-subDelay)}
                />
                <SettingsChip label="+" active={false} accent={accentColor} onTap={() => adjustSubDelay(0.1)} />
              </SettingsGroup>
              <SettingsGroup title="TEXT SIZE">
                {SUB_SIZE_LABELS.map((lbl, i) => (
                  <SettingsChip
                    key={lbl}
                    label={lbl}
                    active={subSize === i}
                    accent={accentColor}
                    onTap={() => {
                      setSubSize(i);
                      syncCueStyle(i, subStyle, subColor, subPos);
                      revealHud();
                    }}
                  />
                ))}
              </SettingsGroup>
              <SettingsGroup title="CAPTION STYLE">
                {SUB_STYLE_LABELS.map((lbl, i) => (
                  <SettingsChip
                    key={lbl}
                    label={lbl}
                    active={subStyle === i}
                    accent={accentColor}
                    onTap={() => {
                      setSubStyle(i);
                      syncCueStyle(subSize, i, subColor, subPos);
                      revealHud();
                    }}
                  />
                ))}
              </SettingsGroup>
              <SettingsGroup title="CAPTION COLOR">
                {SUB_COLOR_LABELS.map((lbl, i) => (
                  <SettingsChip
                    key={lbl}
                    label={lbl}
                    active={subColor === i}
                    accent={accentColor}
                    onTap={() => {
                      setSubColor(i);
                      syncCueStyle(subSize, subStyle, i, subPos);
                      revealHud();
                    }}
                  />
                ))}
              </SettingsGroup>
              <SettingsGroup title="POSITION">
                {SUB_POS_LABELS.map((lbl, i) => (
                  <SettingsChip
                    key={lbl}
                    label={lbl}
                    active={subPos === i}
                    accent={accentColor}
                    onTap={() => {
                      setSubPos(i);
                      syncCueStyle(subSize, subStyle, subColor, i);
                      revealHud();
                    }}
                  />
                ))}
              </SettingsGroup>
            </>
          }
        />
      )}

      {/* Keyboard Shortcuts Dialog */}
      {keysOpen && !locked && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10 }}>
          <div
            onClick={() => {
              setKeysOpen(false);
              scheduleHide();
            }}
            style={{ position: 'absolute', inset: 0, background: black(0.45) }}
          />
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Keyboard shortcuts"
            style={{
              position: 'relative',
              width: '92%',
              maxWidth: isCompact ? 340 : 380,
              maxHeight: isCompact ? 220 : 340,
              overflowY: 'auto',
              background: withAlpha(AppColors.inkDeep, 0.96),
              borderRadius: AppRadius.md,
              border: `1px solid ${withAlpha(accentColor, 0.4)}`,
              padding: '10px 14px 12px',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8 }}>
              <span style={{ ...AppTypography.outfitWhite, fontSize: 13, fontWeight: 700, lineHeight: lineHeight(13) }}>
                Keyboard shortcuts
              </span>
              <div style={{ flex: 1 }} />
              <button
                type="button"
                className="bare-button player-focusable"
                aria-label="Close shortcuts"
                onClick={() => {
                  setKeysOpen(false);
                  scheduleHide();
                }}
                style={{ width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 6 }}
              >
                <Icon name="close" size={18} color="#fff" />
              </button>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px 12px' }}>
              {SHORTCUTS.map(([keys, desc]) => (
                <div
                  key={keys}
                  style={{ width: 156, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 6 }}
                >
                  <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: white(0.8), lineHeight: lineHeight(11) }}>
                    {desc}
                  </span>
                  <span
                    style={{
                      padding: '2px 6px',
                      background: white(0.09),
                      borderRadius: 5,
                      border: `1px solid ${white(0.16)}`,
                      ...AppTypography.outfitWhite,
                      fontSize: 10,
                      fontWeight: 700,
                      lineHeight: lineHeight(10),
                    }}
                  >
                    {keys}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function GestureZone({
  isRight,
  locked,
  duration,
  position,
  video,
  brightness,
  seekStep,
  lastPointerType,
  onReveal,
  onToggleHud,
  onTogglePlay,
  onToggleFullscreen,
  onSeekBy,
  onSeekTo,
  onSetBrightness,
  onFlash,
  onClearFlash,
}: {
  isRight: boolean;
  locked: boolean;
  duration: number;
  position: number;
  video: HTMLVideoElement;
  brightness: number;
  seekStep: number;
  lastPointerType: { current: string };
  onReveal: () => void;
  onToggleHud: () => void;
  onTogglePlay: () => void;
  onToggleFullscreen: () => void;
  onSeekBy: (delta: number) => void;
  onSeekTo: (sec: number) => void;
  onSetBrightness: (v: number) => void;
  onFlash: (label: string) => void;
  onClearFlash: () => void;
}) {
  const zoneRef = useRef<HTMLDivElement>(null);
  const tapTimer = useRef<number | null>(null);
  const lastTapAt = useRef(0);
  const gesture = useRef<{
    pointerId: number;
    startX: number;
    startY: number;
    lastY: number;
    mode: 'idle' | 'h' | 'v';
    seekStart: number;
    seekTarget: number;
    longPressTimer: number | null;
    preRate: number | null;
  } | null>(null);

  useEffect(() => {
    return () => {
      if (tapTimer.current != null) window.clearTimeout(tapTimer.current);
      if (gesture.current?.longPressTimer != null) window.clearTimeout(gesture.current.longPressTimer);
    };
  }, []);

  const onPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    lastPointerType.current = e.pointerType || 'mouse';
    if (e.button !== 0 && e.pointerType === 'mouse') return;

    const state: NonNullable<typeof gesture.current> = {
      pointerId: e.pointerId,
      startX: e.clientX,
      startY: e.clientY,
      lastY: e.clientY,
      mode: 'idle',
      seekStart: position,
      seekTarget: position,
      longPressTimer: null,
      preRate: null,
    };

    if (!locked && e.pointerType !== 'mouse' && !video.paused) {
      state.longPressTimer = window.setTimeout(() => {
        if (gesture.current !== state || locked || video.paused) return;
        state.preRate = video.playbackRate;
        video.playbackRate = 2.0;
        onFlash('2× Speed >>');
      }, 480);
    }

    gesture.current = state;
  };

  const onPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const g = gesture.current;
    if (!g || g.pointerId !== e.pointerId || locked || lastPointerType.current === 'mouse') return;

    const dx = e.clientX - g.startX;
    const dy = e.clientY - g.startY;

    if (g.mode === 'idle' && (Math.abs(dx) > 12 || Math.abs(dy) > 12)) {
      if (g.longPressTimer != null) {
        window.clearTimeout(g.longPressTimer);
        g.longPressTimer = null;
      }
      if (Math.abs(dx) >= Math.abs(dy)) {
        if (duration <= 0) return;
        g.mode = 'h';
      } else {
        g.mode = 'v';
      }
    }

    if (g.mode === 'h' && duration > 0) {
      const deltaSec = Math.round(dx * 0.25);
      const target = Math.min(Math.max(g.seekStart + deltaSec, 0), duration);
      g.seekTarget = target;
      const sign = deltaSec >= 0 ? '+' : '';
      onFlash(`${sign}${deltaSec}s · ${formatTime(target)}`);
    } else if (g.mode === 'v') {
      const stepY = e.clientY - g.lastY;
      g.lastY = e.clientY;
      const h = zoneRef.current?.clientHeight || 240;
      if (isRight) {
        const next = Math.min(Math.max(video.volume - stepY / h, 0), 1);
        video.volume = next;
        video.muted = next === 0;
        onFlash(`Vol ${Math.round(next * 100)}%`);
      } else {
        const next = Math.min(Math.max(brightness - stepY / h, 0.4), 1.25);
        onSetBrightness(next);
        onFlash(`Bright ${Math.round(next * 100)}%`);
      }
    }
  };

  const finishGesture = (e: React.PointerEvent<HTMLDivElement>, cancelled: boolean) => {
    const g = gesture.current;
    if (!g || g.pointerId !== e.pointerId) return;
    gesture.current = null;
    if (g.longPressTimer != null) window.clearTimeout(g.longPressTimer);

    if (g.preRate != null) {
      video.playbackRate = g.preRate;
      onClearFlash();
      return;
    }

    if (g.mode === 'h') {
      if (!cancelled && duration > 0) onSeekTo(g.seekTarget);
      onClearFlash();
      return;
    }

    if (g.mode === 'v') {
      onClearFlash();
      return;
    }

    if (cancelled) return;

    // Touch tap / double-tap; mouse clicks are handled directly via click handlers.
    if (lastPointerType.current !== 'mouse') {
      const now = Date.now();
      if (!locked && now - lastTapAt.current < 260) {
        lastTapAt.current = 0;
        if (tapTimer.current != null) {
          window.clearTimeout(tapTimer.current);
          tapTimer.current = null;
        }
        onSeekBy(isRight ? seekStep : -seekStep);
      } else {
        lastTapAt.current = now;
        if (tapTimer.current != null) window.clearTimeout(tapTimer.current);
        tapTimer.current = window.setTimeout(() => {
          tapTimer.current = null;
          onToggleHud();
        }, 230);
      }
    }
  };

  useEffect(() => {
    const el = zoneRef.current;
    if (!el) return;
    const onDblClick = () => {
      if (lastPointerType.current !== 'mouse' || locked) return;
      onToggleFullscreen();
    };
    el.addEventListener('dblclick', onDblClick);
    return () => el.removeEventListener('dblclick', onDblClick);
  }, [locked, onToggleFullscreen]);

  return (
    <div
      ref={zoneRef}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={(e) => finishGesture(e, false)}
      onPointerCancel={(e) => finishGesture(e, true)}
      onClick={() => {
        if (lastPointerType.current !== 'mouse') return;
        if (locked) onReveal();
        else onTogglePlay();
      }}
      style={{ flex: 1, height: '100%', touchAction: 'none' }}
    />
  );
}

function SheetShell({
  title,
  isCompact,
  accent,
  onClose,
  leftColumn,
  rightColumn,
}: {
  title: string;
  isCompact: boolean;
  accent: string;
  onClose: () => void;
  leftColumn: ReactNode;
  rightColumn: ReactNode;
}) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 8,
        display: 'flex',
        alignItems: isCompact ? 'center' : 'flex-end',
        justifyContent: isCompact ? 'center' : 'flex-end',
        padding: isCompact ? '0 12px' : '0 14px 54px 0',
      }}
    >
      <div
        onClick={onClose}
        style={{ position: 'absolute', inset: 0, background: black(isCompact ? 0.45 : 0.15) }}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        style={{
          position: 'relative',
          width: '100%',
          maxWidth: isCompact ? 420 : 390,
          maxHeight: isCompact ? 260 : 340,
          overflowY: 'auto',
          background: withAlpha(AppColors.inkDeep, 0.94),
          borderRadius: AppRadius.md,
          border: `1px solid ${withAlpha(accent, 0.35)}`,
          padding: '8px 12px 10px',
          display: 'flex',
          flexDirection: 'column',
          gap: 6,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitWhite, fontSize: 13, fontWeight: 700, lineHeight: lineHeight(13) }}>{title}</span>
          <div style={{ flex: 1 }} />
          <button
            type="button"
            className="bare-button player-focusable"
            aria-label={`Close ${title}`}
            onClick={onClose}
            style={{ width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 6 }}
          >
            <Icon name="close" size={18} color="#fff" />
          </button>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>{leftColumn}</div>
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 8 }}>{rightColumn}</div>
        </div>
      </div>
    </div>
  );
}

function SettingsGroup({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <div
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 10,
          fontWeight: 700,
          letterSpacing: 0.6,
          lineHeight: lineHeight(10),
          color: white(0.56),
        }}
      >
        {title}
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>{children}</div>
    </div>
  );
}

function SettingsChip({
  label,
  active,
  accent,
  onTap,
}: {
  label: string;
  active: boolean;
  accent: string;
  onTap: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button player-focusable"
      aria-pressed={active}
      onClick={onTap}
      style={{
        padding: '5px 8px',
        borderRadius: AppRadius.xs,
        background: active ? withAlpha(accent, 0.28) : white(0.08),
        border: `1px solid ${active ? accent : white(0.12)}`,
        ...AppTypography.outfitWhite,
        fontSize: 11,
        fontWeight: 600,
        lineHeight: lineHeight(11),
      }}
    >
      {label}
    </button>
  );
}

function PillBadge({ label, background, maxWidth }: { label: string; background: string; maxWidth?: string }) {
  const style: CSSProperties = {
    padding: '5px 10px',
    background,
    borderRadius: AppRadius.full,
    border: `1px solid ${white(0.14)}`,
    maxWidth,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    ...AppTypography.outfitWhite,
    color: '#fff',
    fontSize: 12,
    fontWeight: 600,
    lineHeight: lineHeight(12),
  };
  return <div style={style}>{label}</div>;
}

function HudChipButton({
  icon,
  label,
  onTap,
  background,
}: {
  icon?: string;
  label: string;
  onTap: () => void;
  background?: string;
}) {
  return (
    <button
      type="button"
      className="bare-button player-focusable"
      aria-label={label}
      onClick={onTap}
      style={{
        padding: '5px 10px',
        background: background ?? withAlpha(AppColors.inkDeep, 0.78),
        borderRadius: AppRadius.full,
        display: 'inline-flex',
        alignItems: 'center',
        gap: 5,
      }}
    >
      {icon && <Icon name={icon} size={15} color="#fff" />}
      <span style={{ ...AppTypography.outfitWhite, color: '#fff', fontSize: 12, fontWeight: 600, lineHeight: lineHeight(12) }}>
        {label}
      </span>
    </button>
  );
}

function HudIconButton({
  icon,
  tooltip,
  onTap,
  size = 18,
  padding = 7,
  background,
  accent,
  active = false,
}: {
  icon: string;
  tooltip: string;
  onTap: () => void;
  size?: number;
  padding?: number;
  background?: string;
  accent?: string;
  active?: boolean;
}) {
  const bg = active && accent ? accent : (background ?? withAlpha(AppColors.inkDeep, 0.68));
  return (
    <button
      type="button"
      className="bare-button player-focusable"
      aria-label={tooltip}
      title={tooltip}
      onClick={onTap}
      style={{
        padding,
        borderRadius: '50%',
        background: bg,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      <Icon name={icon} size={size} color="#fff" />
    </button>
  );
}
