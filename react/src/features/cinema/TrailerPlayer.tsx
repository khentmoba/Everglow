// lib/features/cinema/presentation/widgets/trailer_player_web.dart:
// a muted, chromeless YouTube embed that covers its box and reports when
// it really starts playing (or after a 2.2s fallback once loaded).
import { useEffect, useRef } from 'react';
import { Logger } from '../../core/system/logger';

function embedUrl(key: string, o: { autoplay: boolean; playing: boolean; muted: boolean; loop: boolean }) {
  return (
    `https://www.youtube.com/embed/${key}?` +
    [
      `autoplay=${o.autoplay && o.playing ? 1 : 0}`,
      `mute=${o.muted ? 1 : 0}`,
      'controls=0',
      `loop=${o.loop ? 1 : 0}`,
      ...(o.loop ? [`playlist=${key}`] : []),
      'rel=0',
      'modestbranding=1',
      'showinfo=0',
      'iv_load_policy=3',
      'cc_load_policy=0',
      'disablekb=1',
      'fs=0',
      'playsinline=1',
      'enablejsapi=1',
    ].join('&')
  );
}

export function TrailerPlayer({
  videoKey,
  muted = true,
  autoplay = true,
  loop = true,
  playing = true,
  onLoaded,
}: {
  videoKey: string;
  muted?: boolean;
  autoplay?: boolean;
  loop?: boolean;
  playing?: boolean;
  onLoaded?: () => void;
}) {
  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const loaded = useRef(false);
  const latest = useRef({ muted, playing, autoplay, loop, onLoaded });
  latest.current = { muted, playing, autoplay, loop, onLoaded };

  const YT_ORIGIN = 'https://www.youtube.com';

  const post = (func: string, args?: string | number) => {
    try {
      const a = typeof args === 'string' ? `"${args}"` : args != null ? `${args}` : '""';
      iframeRef.current?.contentWindow?.postMessage(`{"event":"command","func":"${func}","args":${a}}`, YT_ORIGIN);
    } catch {
      /* the frame may be gone */
    }
  };

  // Load (or reload) the video and wire the ready signals.
  useEffect(() => {
    const iframe = iframeRef.current;
    if (!iframe) return;
    let notified = false;
    let fallback: number | undefined;
    let settle: number | undefined;
    loaded.current = false;
    const notify = () => {
      if (notified) return;
      notified = true;
      window.clearTimeout(fallback);
      window.clearTimeout(settle);
      latest.current.onLoaded?.();
    };
    const onMessage = (e: MessageEvent) => {
      if (notified || e.origin !== YT_ORIGIN || e.source !== iframe.contentWindow || typeof e.data !== 'string') return;
      if (!e.data.includes('playerState')) return;
      try {
        const decoded = JSON.parse(e.data) as { info?: { playerState?: number } };
        if (decoded?.info?.playerState === 1) {
          window.clearTimeout(settle);
          settle = window.setTimeout(notify, 350);
        }
      } catch (err) {
        Logger.d(`TrailerPlayer: ignored non-JSON postMessage: ${err}`);
      }
    };
    const onLoad = () => {
      loaded.current = true;
      try {
        iframe.contentWindow?.postMessage('{"event":"listening"}', YT_ORIGIN);
      } catch (err) {
        Logger.d(`TrailerPlayer: failed to subscribe to YT events: ${err}`);
      }
      if (!latest.current.playing) post('pauseVideo');
      window.clearTimeout(fallback);
      fallback = window.setTimeout(notify, 2200);
    };
    window.addEventListener('message', onMessage);
    iframe.addEventListener('load', onLoad);
    iframe.src = embedUrl(videoKey, latest.current);
    return () => {
      window.clearTimeout(fallback);
      window.clearTimeout(settle);
      window.removeEventListener('message', onMessage);
      iframe.removeEventListener('load', onLoad);
      iframe.src = 'about:blank';
    };
  }, [videoKey]);

  const prevMuted = useRef(muted);
  useEffect(() => {
    if (prevMuted.current === muted) return;
    prevMuted.current = muted;
    if (!loaded.current) return;
    if (muted) post('mute');
    else {
      post('unMute');
      post('setVolume', 100);
    }
  }, [muted]);

  const prevPlaying = useRef(playing);
  useEffect(() => {
    if (prevPlaying.current === playing) return;
    prevPlaying.current = playing;
    if (loaded.current) post(playing ? 'playVideo' : 'pauseVideo');
  }, [playing]);

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden', pointerEvents: 'none' }}>
      <iframe
        ref={iframeRef}
        title="Trailer"
        allow="autoplay; encrypted-media"
        frameBorder={0}
        scrolling="no"
        referrerPolicy="strict-origin-when-cross-origin"
        style={{
          border: 0,
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: 'auto',
          height: 'auto',
          minWidth: '100%',
          minHeight: '100%',
          aspectRatio: '16 / 9',
          backgroundColor: '#000',
          pointerEvents: 'none',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          zIndex: 10,
          cursor: 'default',
          touchAction: 'none',
          userSelect: 'none',
          pointerEvents: 'none',
        }}
      />
    </div>
  );
}
