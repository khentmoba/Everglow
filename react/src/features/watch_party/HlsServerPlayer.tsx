import { useEffect, useRef, useState } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import type { WatchPartyRoom } from './watchPartyService';
import { resolveWatchPartyStream, type WatchPartyClock, type WatchPartyStream } from './watchPartySync';

export function HlsServerPlayer({
  room,
  clock,
  onUserPlay,
  onUserPause,
  onUserSeek,
  onFallbackToEmbed,
}: {
  room: WatchPartyRoom;
  clock: WatchPartyClock;
  onUserPlay: (seconds: number) => void;
  onUserPause: (seconds: number) => void;
  onUserSeek: (seconds: number) => void;
  onFallbackToEmbed: () => void;
}) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const suppressEventsUntil = useRef(0);
  const [stream, setStream] = useState<WatchPartyStream | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const mediaKey = `${room.isAnime ? 'a' : 'c'}:${room.tmdbId}:${room.malId ?? ''}:${room.season ?? 1}:${room.episode ?? 1}`;

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError(null);
    setStream(null);
    void resolveWatchPartyStream(room)
      .then((s) => {
        if (!alive) return;
        setStream(s);
        setLoading(false);
      })
      .catch((e: unknown) => {
        if (!alive) return;
        setError(e instanceof Error ? e.message : 'Stream could not be loaded');
        setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [mediaKey]);

  useEffect(() => {
    const v = videoRef.current;
    if (!v || !stream) return;
    const expected = clock.expectedPosition(room);
    if (Math.abs(v.currentTime - expected) > 2.2) {
      suppressEventsUntil.current = Date.now() + 900;
      try {
        v.currentTime = expected;
      } catch {
        // Metadata not loaded yet.
      }
    }
    if (room.state === 'playing' && v.paused) {
      suppressEventsUntil.current = Date.now() + 900;
      void v.play().catch(() => {});
    } else if (room.state !== 'playing' && !v.paused) {
      suppressEventsUntil.current = Date.now() + 900;
      v.pause();
    }
  }, [stream, room.state, room.currentTime, room.positionAt, room.updatedAt, clock]);

  if (loading) {
    return (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 10,
          color: AppColors.petalWhite,
        }}
      >
        <Icon name="sync" size={28} color={AppColors.roseQuartz} />
        <div style={{ ...AppTypography.outfitMedium, fontSize: 13 }}>Resolving synced HLS stream…</div>
      </div>
    );
  }

  if (error || !stream) {
    return (
      <div
        style={{
          width: '100%',
          height: '100%',
          padding: 20,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 10,
          textAlign: 'center',
        }}
      >
        <Icon name="error_outline" size={28} color={AppColors.warmAmber} />
        <div style={{ ...AppTypography.outfitBold, fontSize: 14, color: AppColors.petalWhite }}>
          Direct HLS stream unavailable
        </div>
        <div style={{ fontSize: 12, color: Derived.textMuted, maxWidth: 340 }}>
          {error ?? 'This title is not available on the direct HLS server.'}
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={onFallbackToEmbed}
          style={{
            marginTop: 4,
            padding: '8px 16px',
            borderRadius: 999,
            background: AppColors.deepRose,
            color: AppColors.petalWhite,
            ...AppTypography.outfitBold,
            fontSize: 12.5,
          }}
        >
          Switch to Embed Sync
        </button>
      </div>
    );
  }

  return (
    <video
      ref={videoRef}
      src={stream.src}
      controls
      playsInline
      crossOrigin="anonymous"
      onLoadedMetadata={(e) => {
        const expected = clock.expectedPosition(room);
        if (expected > 1) {
          suppressEventsUntil.current = Date.now() + 900;
          e.currentTarget.currentTime = expected;
        }
        if (room.state === 'playing') {
          suppressEventsUntil.current = Date.now() + 900;
          void e.currentTarget.play().catch(() => {});
        }
      }}
      onPlay={(e) => {
        if (Date.now() < suppressEventsUntil.current) return;
        onUserPlay(e.currentTarget.currentTime);
      }}
      onPause={(e) => {
        if (Date.now() < suppressEventsUntil.current) return;
        onUserPause(e.currentTarget.currentTime);
      }}
      onSeeked={(e) => {
        if (Date.now() < suppressEventsUntil.current) return;
        onUserSeek(e.currentTarget.currentTime);
      }}
      onError={() => setError('Video playback failed on this browser — try Embed Sync.')}
      style={{
        width: '100%',
        height: '100%',
        background: '#000',
        display: 'block',
        outline: 'none',
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
      }}
    >
      {stream.subtitles.map((sub, i) => (
        <track key={sub.url} kind="subtitles" src={sub.url} label={sub.label} default={i === 0} />
      ))}
    </video>
  );
}
