// Faithful port of animex_player_web.dart: the sandboxed embed frame, its
// postMessage bridge (progress, actions, content errors, wheel scroll), the
// direct-video fallback, and the YouTube trailer modal.
import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { showDialog } from '../../shared/widgets/Dialogs';
import type { AniSkipTimes } from './animexData';
import { fetchDetailsWithFallback } from './animexData';
import {
  ANIMEX_PROXY_ORIGIN,
  EmbedPolicy,
  animeXPlayerMessageOriginAllowed,
  isAnimeXProxyPlayerUrl,
  parseAnimeXProgress,
  parseEverglowEmbedScrollDelta,
  parseVideasyProgress,
  type VideasyProgress,
} from './animexWatchConfig';
import { AnimeXTokens, dmSansStyle } from './animeTokens';
import { AnimeXIconButton } from './AnimeUi';

const SANDBOX = 'allow-scripts allow-same-origin allow-forms allow-presentation allow-pointer-lock';
const ALLOW = 'autoplay *; fullscreen *; encrypted-media *; picture-in-picture *; accelerometer *; gyroscope *; clipboard-write *';

let fullscreenExitSettling = false;
export const isPlayerFullscreenActive = () => fullscreenExitSettling || document.fullscreenElement != null;
export function exitPlayerFullscreen() {
  if (document.fullscreenElement != null) void document.exitFullscreen();
}

function scrollParent(el: HTMLElement | null): HTMLElement | null {
  for (let n = el?.parentElement ?? null; n; n = n.parentElement) {
    const oy = getComputedStyle(n).overflowY;
    if ((oy === 'auto' || oy === 'scroll') && n.scrollHeight > n.clientHeight) return n;
  }
  return null;
}

export interface AnimeXPlayerFrameProps {
  url: string;
  referrerPolicy?: string;
  onContentError?: () => void;
  onProgress?: (p: VideasyProgress) => void;
  seekSeconds?: number;
  seekRequest?: number;
  skipTimes?: AniSkipTimes | null;
  nextToken?: string;
  nextIsSeason?: boolean;
  onNextEpisode?: () => void;
  autoAdvance?: boolean;
  onAudioChanged?: (audio: string) => void;
  onShowEpisodes?: () => void;
  onPlayerEpisodeChanged?: (season: number, episode: number) => void;
  sandbox?: boolean;
}

const isWholePositive = (v: unknown): v is number =>
  typeof v === 'number' && Number.isFinite(v) && v > 0 && v === Math.trunc(v);

export function AnimeXPlayerFrame(props: AnimeXPlayerFrameProps) {
  const { url, referrerPolicy = 'no-referrer', sandbox = true } = props;
  const hostRef = useRef<HTMLDivElement>(null);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [loaded, setLoaded] = useState(false);
  const contentError = useRef(false);
  const latest = useRef(props);
  latest.current = props;
  const loadedRef = useRef(false);

  const isDirectVideo = url.endsWith('.mp4') || url.endsWith('.webm') || url.startsWith('blob:') || url.startsWith('offline:');
  const sandboxed = sandbox && EmbedPolicy.sandboxAllowed(url);
  const referrer = EmbedPolicy.referrerFor(url, referrerPolicy);

  useLayoutEffect(() => {
    loadedRef.current = false;
    contentError.current = false;
    setLoaded(false);
  }, [url]);

  const applyEmbedScroll = (dy: number) => {
    if (document.fullscreenElement != null) return;
    const sc = scrollParent(hostRef.current);
    if (!sc) return;
    const next = Math.min(Math.max(sc.scrollTop + dy, 0), sc.scrollHeight - sc.clientHeight);
    if (next !== sc.scrollTop) sc.scrollTop = next;
  };

  const post = (msg: unknown) => iframeRef.current?.contentWindow?.postMessage(msg, ANIMEX_PROXY_ORIGIN);

  const sendSeek = () => {
    const seconds = latest.current.seekSeconds;
    if (!loadedRef.current || seconds == null || seconds < 0 || !isAnimeXProxyPlayerUrl(latest.current.url)) return;
    post({ type: 'animex-seek', seconds });
  };

  const sendPlayerState = () => {
    if (!loadedRef.current || !isAnimeXProxyPlayerUrl(latest.current.url)) return;
    const { skipTimes, nextToken, nextIsSeason } = latest.current;
    const op = skipTimes?.opening;
    const ed = skipTimes?.ending;
    post({
      type: 'animex-player-state',
      ...(op ? { op: [op.start, op.end] } : {}),
      ...(ed ? { ed: [ed.start, ed.end] } : {}),
      next: nextToken ?? null,
      nextKind: nextIsSeason ? 'season' : 'episode',
    });
  };

  useEffect(() => {
    const onMessage = (event: MessageEvent) => {
      const frame = iframeRef.current;
      const p = latest.current;
      if (!frame?.contentWindow || event.source !== frame.contentWindow || !animeXPlayerMessageOriginAllowed(p.url, event.origin)) {
        return;
      }
      const obj = event.data as unknown;
      const owned = parseAnimeXProgress(event.origin, p.url, obj);
      if (owned) {
        p.onProgress?.(owned);
        return;
      }
      const dy = parseEverglowEmbedScrollDelta(obj);
      if (dy != null) {
        applyEmbedScroll(dy);
        return;
      }
      const map = obj && typeof obj === 'object' ? (obj as Record<string, unknown>) : null;
      if (map?.type === 'animex-action') {
        const act = map.action;
        if (act === 'next-episode') p.onNextEpisode?.();
        else if (act === 'episodes') p.onShowEpisodes?.();
        else if (act === 'audio' && (map.audio === 'sub' || map.audio === 'dub')) p.onAudioChanged?.(map.audio);
        return;
      }
      if (map?.type === 'cinesrc:nextepisode') {
        if (isWholePositive(map.season) && isWholePositive(map.episode)) p.onPlayerEpisodeChanged?.(map.season, map.episode);
        return;
      }
      const data = typeof obj === 'string' ? obj : '';
      if ((data === 'animex-content-error' || map?.type === 'everglow-embed-failed') && !contentError.current) {
        contentError.current = true;
        p.onContentError?.();
        return;
      }
      const progress = parseVideasyProgress(event.origin, data);
      if (progress) p.onProgress?.(progress);
    };
    let settle: number | undefined;
    const onFullscreen = () => {
      window.clearTimeout(settle);
      if (document.fullscreenElement != null) {
        fullscreenExitSettling = false;
      } else {
        fullscreenExitSettling = true;
        settle = window.setTimeout(() => (fullscreenExitSettling = false), 260);
      }
    };
    window.addEventListener('message', onMessage);
    document.addEventListener('fullscreenchange', onFullscreen);
    return () => {
      window.clearTimeout(settle);
      fullscreenExitSettling = false;
      window.removeEventListener('message', onMessage);
      document.removeEventListener('fullscreenchange', onFullscreen);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    sendSeek();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [props.seekSeconds, props.seekRequest]);
  useEffect(() => {
    sendPlayerState();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [props.skipTimes, props.nextToken, props.nextIsSeason]);

  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    const onWheel = (ev: WheelEvent) => {
      const dy = parseEverglowEmbedScrollDelta({ type: 'everglow-embed-scroll', deltaY: ev.deltaY, deltaMode: ev.deltaMode });
      if (dy != null) applyEmbedScroll(dy);
    };
    v.addEventListener('wheel', onWheel);
    return () => v.removeEventListener('wheel', onWheel);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isDirectVideo]);

  const onLoad = () => {
    loadedRef.current = true;
    setLoaded(true);
    sendSeek();
    sendPlayerState();
  };

  return (
    <div
      ref={hostRef}
      style={{
        position: 'relative',
        width: '100%',
        aspectRatio: '16 / 9',
        background: '#000',
        borderRadius: AnimeXTokens.radiusLg,
        overflow: 'hidden',
      }}
    >
      {isDirectVideo ? (
        <video
          ref={videoRef}
          src={url}
          controls
          autoPlay
          playsInline
          onLoadedData={() => setLoaded(true)}
          onTimeUpdate={(ev) => {
            const v = ev.currentTarget;
            props.onProgress?.({ positionSeconds: v.currentTime, durationSeconds: Number.isFinite(v.duration) ? v.duration : 0 });
          }}
          onEnded={() => {
            if (props.autoAdvance ?? true) props.onNextEpisode?.();
          }}
          onError={() => {
            setLoaded(true);
            contentError.current = true;
            props.onContentError?.();
          }}
          style={{ border: 'none', width: '100%', height: '100%', background: '#000', display: 'block' }}
        />
      ) : (
        <iframe
          ref={iframeRef}
          key={`${sandboxed}`}
          src={url}
          title="Player"
          allow={ALLOW}
          allowFullScreen
          referrerPolicy={referrer as React.HTMLAttributeReferrerPolicy}
          sandbox={sandboxed ? SANDBOX : undefined}
          onLoad={onLoad}
          style={{ border: 'none', width: '100%', height: '100%', display: 'block' }}
        />
      )}
      {!loaded && (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: 'none' }}>
          <CircularProgress size={26} strokeWidth={2.5} color={AnimeXTokens.accent} />
        </div>
      )}
    </div>
  );
}

export async function showAnimexTrailer(o: { youtubeId?: string; anilistId?: number; malId?: number; title: string }) {
  let trailerId = o.youtubeId;
  if (!trailerId && (o.anilistId != null || o.malId != null)) {
    const detail = await fetchDetailsWithFallback({ anilistId: o.anilistId, malId: o.malId });
    trailerId = detail?.trailerYoutubeId;
  }
  if (!trailerId) return;
  const id = trailerId;
  await showDialog<void>((close) => <AnimeXTrailerModal title={o.title} youtubeId={id} onClose={() => close(null)} />, {
    barrierColor: 'rgba(0, 0, 0, 0.878)',
    insetPadding: '24px',
  });
}

export function AnimeXTrailerModal({ title, youtubeId, onClose }: { title: string; youtubeId: string; onClose: () => void }) {
  const url = `https://www.youtube.com/embed/${youtubeId}?autoplay=1&rel=0&color=white`;
  return (
    <div
      style={{
        width: '100%',
        maxWidth: 880,
        maxHeight: '100%',
        overflowY: 'auto',
        background: AnimeXTokens.surface,
        borderRadius: AnimeXTokens.radius2xl,
        border: `1px solid ${AnimeXTokens.border}`,
        boxSizing: 'border-box',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', padding: '14px 12px 14px 18px' }}>
        <div
          style={{
            ...dmSansStyle({ size: 14, color: AnimeXTokens.textSecondary }),
            flex: 1,
            minWidth: 0,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {title} — Official Trailer
        </div>
        <AnimeXIconButton icon="close" tooltip="Close" onClick={onClose} />
      </div>
      <div style={{ padding: '0 18px 18px' }}>
        <AnimeXPlayerFrame url={url} referrerPolicy="strict-origin-when-cross-origin" sandbox={false} />
      </div>
    </div>
  );
}
