// Ports of lib/features/jukebox/presentation/widgets/{jukebox_widget,music_stats_section,artist_showdown_card}.dart.
import { useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, AppArt, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, boxShadow, linear, lineHeight, radial } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { HueGlyph } from '../../shared/widgets/HueGlyph';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import {
  DEFAULT_SHOWDOWN_ARTIST,
  LASTFM_USER_CLAIR,
  LASTFM_USER_KHENT,
  disconnectSpotify,
  emptyMusicStatus,
  fetchArtistImage,
  fetchArtistShowdown,
  fetchArtistShowdownHistory,
  fetchMusicStats,
  fetchTrackMetadata,
  linkSpotify,
  musicStatusSource,
  searchLastfmArtists,
  spotifyTokenSource,
  syncMusicStatusPoll,
  type ArtistSuggestion,
  type MusicStatsData,
  type MusicStatus,
  type ShowdownTrack,
  type SpotifyLinkState,
  type TopMusicTrack,
} from './jukeboxService';
import { showListenAlong } from './ListenAlongPopup';

function formatTime(dt: Date): string {
  const h = dt.getHours();
  const m = String(dt.getMinutes()).padStart(2, '0');
  const ampm = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${m} ${ampm}`;
}

function formatNumber(n: number): string {
  return n.toLocaleString('en-US');
}

const GRAIN_DOTS = (() => {
  const dots: { x: number; y: number; r: number }[] = [];
  let s = 42;
  const next = () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 0xffffffff;
  };
  for (let i = 0; i < 180; i++) {
    dots.push({
      x: Math.round(next() * 1000) / 10,
      y: Math.round(next() * 1000) / 10,
      r: next() * 0.7 + 0.3,
    });
  }
  return dots;
})();

export function JukeboxWidget({ showHeader = true }: { showHeader?: boolean } = {}) {
  const auth = useAuth();
  const { width } = useViewport();
  const statuses = useSource<Record<string, MusicStatus>>(() => musicStatusSource(), [auth.uid], {});
  const khentStatus = statuses[LASTFM_USER_KHENT] ?? emptyMusicStatus(LASTFM_USER_KHENT);
  const clairStatus = statuses[LASTFM_USER_CLAIR] ?? emptyMusicStatus(LASTFM_USER_CLAIR);
  const eitherLive = khentStatus.isPlaying || clairStatus.isPlaying;
  const isMobile = width - 32 < 620;

  useEffect(() => {
    let alive = true;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let inFlight = false;
    let lastRunAt = 0;

    const schedule = (delayMs: number) => {
      if (!alive) return;
      if (timer != null) clearTimeout(timer);
      timer = setTimeout(() => {
        void run();
      }, delayMs);
    };

    const run = async () => {
      if (!alive || inFlight || document.visibilityState === 'hidden') return;
      inFlight = true;
      lastRunAt = Date.now();
      let live = false;
      try {
        live = await syncMusicStatusPoll(auth.currentUser);
      } finally {
        inFlight = false;
      }
      if (!alive) return;
      schedule(live ? 25_000 : 60_000);
    };

    const onVisibility = () => {
      if (document.visibilityState === 'visible' && Date.now() - lastRunAt > 15_000) {
        void run();
      }
    };

    void run();
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      alive = false;
      if (timer != null) clearTimeout(timer);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [auth.uid, auth.currentUser]);

  return (
    // In Flutter the gradient Container has no child, so inside the Stack it is
    // zero pixels tall: only its 1px border shows, as a line along the top.
    <div style={{ position: 'relative' }}>
      {showHeader && (
        <div
          aria-hidden
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            background: withAlpha(AppColors.moonlight, eitherLive ? 0.18 : 0.12),
            pointerEvents: 'none',
          }}
        />
      )}
      <div
        aria-hidden
        style={{ position: 'absolute', inset: 0, borderRadius: AppRadius.x2, overflow: 'hidden', pointerEvents: 'none' }}
      >
        <div
          aria-hidden
          style={{
            position: 'absolute',
            top: -40,
            left: -30,
            width: 180,
            height: 180,
            borderRadius: '50%',
            opacity: 0.22 * (0.85 + Math.sin(0) * 0.15) + 0.06,
            background: radial([withAlpha(AppColors.deepRose, 0.55), AppColors.transparent], { size: [180, 180] }),
            pointerEvents: 'none',
          }}
        />
        <div
          aria-hidden
          style={{
            position: 'absolute',
            bottom: -50,
            right: -20,
            width: 220,
            height: 220,
            borderRadius: '50%',
            opacity: 0.22 * (0.85 + Math.sin(1.2) * 0.15) + 0.06,
            background: radial([withAlpha(AppColors.auroraLilac, 0.55), AppColors.transparent], { size: [220, 220] }),
            pointerEvents: 'none',
          }}
        />
        <svg aria-hidden style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
          {GRAIN_DOTS.map((d, i) => (
            <circle key={i} cx={`${d.x}%`} cy={`${d.y}%`} r={d.r} fill="rgba(255,255,255,0.015)" />
          ))}
        </svg>
        <div
          aria-hidden
          style={{
            position: 'absolute',
            inset: 0,
            background: linear(['rgba(255,255,255,0.04)', AppColors.transparent], {
              begin: Align.topCenter,
              end: Align.bottomCenter,
            }),
            pointerEvents: 'none',
          }}
        />
      </div>

      <div style={{ position: 'relative', padding: 18 }}>
        {showHeader && (
          <>
            <JukeboxHeader eitherLive={eitherLive} />
            <div style={{ height: 12 }} />
          </>
        )}
        <SpotifyConnectCard />
        <div style={{ height: 16 }} />
        <div
          style={{
            display: 'flex',
            flexDirection: isMobile ? 'column' : 'row',
            gap: 14,
            alignItems: isMobile ? 'stretch' : 'flex-start',
          }}
        >
          <div style={{ flex: isMobile ? undefined : 1, minWidth: 0 }}>
            <MusicCard status={khentStatus} title="Khent is vibing to..." />
          </div>
          <div style={{ flex: isMobile ? undefined : 1, minWidth: 0 }}>
            <MusicCard status={clairStatus} title="Clair is vibing to..." />
          </div>
        </div>
      </div>
    </div>
  );
}

function JukeboxHeader({ eitherLive }: { eitherLive: boolean }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 34,
          height: 34,
          borderRadius: 11,
          background: linear([AppColors.auroraRose, AppColors.deepRose], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          boxShadow: boxShadow([{ blur: 14, spread: -2, color: withAlpha(AppColors.deepRose, 0.35) }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="graphic_eq" size={18} color="#FFFFFF" />
      </div>
      <div style={{ width: 10 }} />
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
        <span style={{ ...AppTypography.cormorantBoldWhite, fontSize: 19, lineHeight: 1.1 }}>Jukebox</span>
        <span
          style={{
            fontFamily: 'Outfit, sans-serif',
            fontSize: 11,
            fontWeight: 500,
            color: withAlpha(AppColors.petalWhite, 0.52),
            letterSpacing: '0.2px',
          }}
        >
          {eitherLive ? 'Live from Last.fm' : "What we're listening to"}
        </span>
      </div>
      <div style={{ flex: 1 }} />
      <div
        style={{
          padding: '6px 10px',
          borderRadius: 999,
          background: eitherLive ? withAlpha(AppColors.success, 0.12) : withAlpha(AppColors.moonlight, 0.08),
          border: `1px solid ${eitherLive ? withAlpha(AppColors.success, 0.24) : withAlpha(AppColors.moonlight, 0.12)}`,
          display: 'inline-flex',
          alignItems: 'center',
          gap: 6,
        }}
      >
        <span
          style={{
            width: 7,
            height: 7,
            borderRadius: '50%',
            background: eitherLive ? AppColors.success : withAlpha(AppColors.mutedPurple, 0.8),
            boxShadow: eitherLive ? boxShadow([{ blur: 8, color: withAlpha(AppColors.success, 0.55) }]) : undefined,
          }}
        />
        <span
          style={{
            fontFamily: 'Outfit, sans-serif',
            fontSize: 11,
            fontWeight: 700,
            color: eitherLive ? AppColors.success : withAlpha(AppColors.petalWhite, 0.55),
          }}
        >
          {eitherLive ? 'On air' : 'Quiet'}
        </span>
      </div>
    </div>
  );
}

const EMPTY_SPOTIFY_LINK: SpotifyLinkState = { isLinked: false, spotifyUserId: null, displayName: null };

function SpotifyConnectCard() {
  const auth = useAuth();
  const link = useSource<SpotifyLinkState>(() => spotifyTokenSource(auth.uid), [auth.uid], EMPTY_SPOTIFY_LINK);

  return (
    <div
      style={{
        padding: '12px 14px',
        background: withAlpha(AppColors.velvet, 0.6),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          width: 28,
          height: 28,
          borderRadius: 8,
          background: '#1DB954',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="music_note" size={16} color={AppColors.petalWhite} />
      </div>
      <div style={{ width: 10 }} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <span style={{ color: AppColors.petalWhite, fontWeight: 700, fontSize: 13 }}>
          {link.isLinked ? 'Spotify linked' : 'Connect Spotify'}
        </span>
        <span style={{ color: withAlpha(AppColors.petalWhite, 0.6), fontSize: 11 }}>
          {link.isLinked ? (link.displayName ?? link.spotifyUserId ?? 'Premium ✓') : 'For in-app playback (Duo required)'}
        </span>
      </div>
      <div style={{ width: 10 }} />
      {!link.isLinked ? (
        <div style={{ height: 48, display: 'flex', alignItems: 'center', flexShrink: 0 }}>
          <button
            type="button"
            className="bare-button"
            onClick={() =>
              void linkSpotify().catch((e: unknown) =>
                showSnackBar(String(e instanceof Error ? e.message : e).replace(/^Exception: /, '')),
              )
            }
            style={{
              height: 40,
              minWidth: 64,
              padding: '0 14px',
              background: '#1DB954',
              color: AppColors.petalWhite,
              borderRadius: 999,
              boxShadow: '0 1px 2px rgba(0,0,0,0.3), 0 1px 3px 1px rgba(0,0,0,0.15)',
              fontFamily: Fonts.body,
              fontSize: 12,
              fontWeight: 800,
              letterSpacing: 0.6,
              lineHeight: '15px',
            }}
          >
            Link
          </button>
        </div>
      ) : (
        <button
          type="button"
          className="bare-button"
          aria-label="Unlink"
          title="Unlink"
          onClick={() => void disconnectSpotify()}
          style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
        >
          <Icon name="logout" size={18} color={withAlpha(AppColors.petalWhite, 0.54)} />
        </button>
      )}
    </div>
  );
}

function MusicCard({ status, title }: { status: MusicStatus; title: string }) {
  const [hovered, setHovered] = useState(false);
  const isLive = status.isPlaying;

  if (!isLive && status.timestamp == null && status.trackName === 'Silent Night') {
    return (
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 12,
          padding: '12px 14px',
          borderRadius: AppRadius.xl,
          background: withAlpha(AppColors.moonlight, 0.06),
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
        }}
      >
        <HueGlyph icon="music_note" hue={AppColors.softLavender} size={32} iconSize={16} />
        <span style={{ ...AppTypography.outfitBold, fontSize: 13, color: withAlpha(AppColors.petalWhite, 0.86) }}>
          {title.split(' ')[0]}
        </span>
        <span style={{ ...AppTypography.handwrittenBody, fontSize: 17, lineHeight: 1, color: withAlpha(AppColors.petalWhite, 0.5) }}>
          nothing playing yet
        </span>
      </div>
    );
  }

  return (
    <button
      type="button"
      className="bare-button"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={() => void showListenAlong(status)}
      style={{
        display: 'block',
        width: '100%',
        textAlign: 'left',
        transform: `translateY(${hovered ? -3 : 0}px) scale(${hovered ? 1.015 : 1})`,
        transition: 'transform 220ms cubic-bezier(0.22, 1, 0.36, 1)',
      }}
    >
      <div
        style={{
          position: 'relative',
          padding: 20,
          borderRadius: AppRadius.x2,
          background: isLive
            ? linear([withAlpha(AppColors.moonlight, 0.18), withAlpha(AppColors.velvet, 0.55), withAlpha(AppColors.plum, 0.55)], {
                begin: Align.topLeft,
                end: Align.bottomRight,
              })
            : withAlpha(AppColors.moonlight, 0.1),
          border: `${isLive ? 1.2 : 1}px solid ${
            isLive ? withAlpha(AppColors.blushGold, 0.42) : withAlpha(AppColors.moonlight, hovered ? 0.22 : 0.14)
          }`,
          boxShadow: boxShadow([
            { offset: [0, 8], blur: isLive ? 22 : 14, color: withAlpha('#000000', isLive ? 0.28 : 0.14) },
            ...(isLive
              ? [
                  { blur: 28, spread: -6, color: withAlpha(AppColors.deepRose, 0.18) },
                  { blur: 36, spread: -10, color: withAlpha(AppColors.auroraLilac, 0.1) },
                ]
              : []),
          ]),
        }}
      >
        <div style={{ position: 'relative', borderRadius: AppRadius.x2, overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
            <div
              style={{
                padding: '4px 8px',
                background: isLive ? withAlpha(AppColors.deepRose, 0.18) : withAlpha(AppColors.moonlight, 0.08),
                borderRadius: 999,
                border: `1px solid ${isLive ? withAlpha(AppColors.deepRose, 0.28) : 'transparent'}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <Icon name="music_note" size={11} color={isLive ? AppColors.blushGold : withAlpha(AppColors.moonlight, 0.6)} />
              <span
                style={{
                  ...AppTypography.outfitBold,
                  fontSize: 11,
                  color: isLive ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.72),
                  letterSpacing: '0.6px',
                }}
              >
                {title}
              </span>
            </div>

            {isLive ? (
              <div
                style={{
                  padding: '3px 7px',
                  background: withAlpha(AppColors.success, 0.14),
                  borderRadius: 999,
                  border: `1px solid ${withAlpha(AppColors.success, 0.22)}`,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 5,
                }}
              >
                <span
                  style={{
                    width: 7,
                    height: 7,
                    borderRadius: '50%',
                    background: AppColors.success,
                    boxShadow: boxShadow([{ blur: 6, spread: 1, color: withAlpha(AppColors.success, 0.6) }]),
                  }}
                />
                <span
                  style={{
                    ...AppTypography.outfitWhite,
                    fontSize: 9,
                    fontWeight: 800,
                    color: AppColors.success,
                    letterSpacing: '1.1px',
                  }}
                >
                  LIVE
                </span>
              </div>
            ) : (
              <div
                style={{
                  padding: '3px 7px',
                  background: withAlpha(AppColors.moonlight, 0.08),
                  borderRadius: 999,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 6,
                }}
              >
                <span
                  style={{
                    width: 6,
                    height: 6,
                    borderRadius: '50%',
                    background: withAlpha(AppColors.mutedPurple, 0.9),
                  }}
                />
                <span
                  style={{
                    ...AppTypography.outfitWhite,
                    fontSize: 9,
                    fontWeight: 700,
                    color: withAlpha(AppColors.petalWhite, 0.55),
                    letterSpacing: '1px',
                  }}
                >
                  OFFLINE
                </span>
              </div>
            )}
          </div>

          <div style={{ height: 16 }} />

          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div style={{ position: 'relative', width: 84, height: 84, flexShrink: 0 }}>
              {isLive && <VinylDisc />}
              <div
                style={{
                  position: 'relative',
                  width: 84,
                  height: 84,
                  borderRadius: 16,
                  overflow: 'hidden',
                  boxShadow: boxShadow([
                    ...(isLive ? [{ blur: 18, spread: 1, color: withAlpha(AppColors.deepRose, 0.28) }] : []),
                    { offset: [0, 6], blur: 16, color: withAlpha('#000000', 0.28) },
                  ]),
                }}
              >
                {status.imageUrl ? (
                  <img
                    src={status.imageUrl}
                    alt={status.trackName || 'Album art'}
                    style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                  />
                ) : (
                  <div
                    style={{
                      width: '100%',
                      height: '100%',
                      background: linear([AppColors.velvet, AppColors.plum, AppColors.twilight], {
                        begin: Align.topLeft,
                        end: Align.bottomRight,
                      }),
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <Icon
                      name="music_note"
                      size={32}
                      color={isLive ? AppColors.roseQuartz : withAlpha(AppColors.roseQuartz, 0.55)}
                    />
                  </div>
                )}
                {!isLive && (
                  <div
                    style={{
                      position: 'absolute',
                      inset: 0,
                      background: withAlpha('#000000', 0.18),
                    }}
                  />
                )}
                <div
                  style={{
                    position: 'absolute',
                    inset: 0,
                    borderRadius: 16,
                    border: `1px solid ${withAlpha(AppColors.petalWhite, isLive ? 0.1 : 0.06)}`,
                    pointerEvents: 'none',
                  }}
                />
              </div>
            </div>

            <div style={{ width: 42, flexShrink: 0 }} />

            <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
              <span
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 16.5,
                  fontWeight: 800,
                  color: isLive ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.82),
                  letterSpacing: '-0.2px',
                  lineHeight: lineHeight(16.5, 1.1),
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  maxWidth: '100%',
                }}
              >
                {status.trackName || '—'}
              </span>
              <div style={{ height: 3 }} />
              <span
                style={{
                  ...AppTypography.outfitWhite,
                  fontSize: 13,
                  fontWeight: 500,
                  color: withAlpha(AppColors.petalWhite, isLive ? 0.78 : 0.62),
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  maxWidth: '100%',
                }}
              >
                {status.artistName || 'Unknown Artist'}
              </span>
              {status.albumName && (
                <span
                  style={{
                    ...AppTypography.outfitWhite,
                    marginTop: 2,
                    fontSize: 11,
                    color: withAlpha(AppColors.petalWhite, isLive ? 0.52 : 0.42),
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    maxWidth: '100%',
                  }}
                >
                  {status.albumName}
                </span>
              )}
              <div style={{ height: 9 }} />
              {isLive ? (
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span
                    style={{
                      width: 4,
                      height: 4,
                      borderRadius: '50%',
                      background: withAlpha(AppColors.blushGold, 0.9),
                    }}
                  />
                  <span
                    style={{
                      ...AppTypography.outfitWhite,
                      fontSize: 11,
                      fontWeight: 600,
                      color: withAlpha(AppColors.blushGold, 0.9),
                      letterSpacing: '0.15px',
                    }}
                  >
                    Tap to listen along →
                  </span>
                </div>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                  <Icon name="schedule" size={12} color={withAlpha(AppColors.petalWhite, 0.42)} />
                  <span
                    style={{
                      ...AppTypography.outfitWhite,
                      fontSize: 11,
                      fontStyle: 'italic',
                      color: withAlpha(AppColors.petalWhite, 0.48),
                    }}
                  >
                    {status.timestamp ? `Last heard ${formatTime(status.timestamp)}` : 'Not vibing right now'}
                  </span>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </button>
  );
}

function VinylDisc() {
  return (
    <div
      style={{
        position: 'absolute',
        right: -28,
        top: 11,
        width: 62,
        height: 62,
        borderRadius: '50%',
        background: radial([AppArt.vinylEdge, AppArt.vinylCore, '#000000'], {
          stops: [0.3, 0.65, 1],
          size: [62, 62],
        }),
        boxShadow: boxShadow([{ blur: 12, spread: 1, color: withAlpha('#000000', 0.55) }]),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          width: 18,
          height: 18,
          borderRadius: '50%',
          background: linear([AppColors.deepRose, AppColors.blushGold], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
        }}
      />
    </div>
  );
}

function formatRelativeTime(timestamp: Date | null, isPlaying: boolean): string {
  if (isPlaying) return 'now';
  if (!timestamp) return 'heard';
  const diffSec = Math.floor((Date.now() - timestamp.getTime()) / 1000);
  if (diffSec < 60) return 'Just now';
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr}h ago`;
  const diffDays = Math.floor(diffHr / 24);
  if (diffDays < 7) return `${diffDays}d ago`;
  return timestamp.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

function JukeboxArtwork({
  imageUrl,
  size = 44,
  radius = 12,
  borderColor = withAlpha(AppColors.moonlight, 0.14),
  borderWidth = 1,
  glowColor,
  iconSize = 18,
}: {
  imageUrl: string | null;
  size?: number;
  radius?: number;
  borderColor?: string;
  borderWidth?: number;
  glowColor?: string;
  iconSize?: number;
}) {
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    setFailed(false);
  }, [imageUrl]);

  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        overflow: 'hidden',
        background: AppColors.velvet,
        border: `${borderWidth}px solid ${borderColor}`,
        boxShadow: glowColor ? boxShadow([{ offset: [0, 4], blur: 14, color: withAlpha(glowColor, 0.35) }]) : undefined,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      {imageUrl && !failed ? (
        <img
          src={imageUrl}
          alt=""
          loading="lazy"
          onError={() => setFailed(true)}
          style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
        />
      ) : (
        <Icon name="music_note" size={iconSize} color={withAlpha(AppColors.roseQuartz, 0.72)} />
      )}
    </div>
  );
}

function podiumColorFor(rank: number, isPink: boolean): string {
  if (isPink) {
    if (rank === 1) return AppColors.cinemaPink;
    if (rank === 2) return AppColors.roseQuartz;
    if (rank === 3) return AppColors.softLavender;
    return AppColors.auroraRose;
  }
  if (rank === 1) return AppColors.auroraGold;
  if (rank === 2) return '#D8D6F0';
  if (rank === 3) return '#E69F6B';
  return AppColors.blushGold;
}

function RankBadge({ rank, isPink }: { rank: number; isPink: boolean }) {
  if (rank <= 3) {
    const c = podiumColorFor(rank, isPink);
    return (
      <div
        style={{
          width: 32,
          height: 32,
          borderRadius: '50%',
          background: linear([withAlpha(c, 0.34), withAlpha(c, 0.1)], { begin: Align.topLeft, end: Align.bottomRight }),
          border: `1.4px solid ${withAlpha(c, 0.72)}`,
          boxShadow: boxShadow([{ blur: 12, color: withAlpha(c, 0.35) }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <span style={{ ...AppTypography.cormorantBold, fontSize: 17, lineHeight: 1, color: c }}>{rank}</span>
      </div>
    );
  }
  return (
    <div
      style={{
        width: 32,
        height: 32,
        borderRadius: '50%',
        background: isPink ? withAlpha(AppColors.auroraRose, 0.1) : withAlpha(AppColors.moonlight, 0.06),
        border: `1px solid ${isPink ? withAlpha(AppColors.auroraRose, 0.35) : withAlpha(AppColors.moonlight, 0.12)}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      <span style={{ ...AppTypography.cormorantHeading, fontSize: 16, lineHeight: 1, color: Derived.textMedium }}>
        {rank}
      </span>
    </div>
  );
}

function PodiumArtwork({
  imageUrl,
  rank,
  isPink,
}: {
  imageUrl: string | null;
  rank: number;
  isPink: boolean;
}) {
  const isPodium = rank <= 3;
  const color = podiumColorFor(rank, isPink);
  const size = isPodium ? 48 : 44;
  const art = (
    <JukeboxArtwork
      imageUrl={imageUrl}
      size={size}
      radius={12}
      borderColor={isPodium ? withAlpha(color, rank === 1 ? 0.9 : 0.75) : withAlpha(AppColors.moonlight, 0.14)}
      borderWidth={isPodium ? 1.6 : 1}
      glowColor={isPodium ? color : undefined}
    />
  );
  if (!isPodium) return art;
  const medalIcon = rank === 1 ? 'emoji_events' : rank === 2 ? 'workspace_premium' : 'military_tech';
  return (
    <div style={{ position: 'relative', flexShrink: 0 }}>
      {art}
      <div
        style={{
          position: 'absolute',
          top: -7,
          right: -7,
          width: 20,
          height: 20,
          borderRadius: '50%',
          background: linear(
            isPink
              ? rank === 1
                ? ['#FFF0F6', AppColors.cinemaPink]
                : rank === 2
                  ? ['#FFF0F6', AppColors.roseQuartz]
                  : [AppColors.moonlight, AppColors.softLavender]
              : rank === 1
                ? ['#FFF3B0', AppColors.auroraGold]
                : rank === 2
                  ? ['#F0F0FF', '#B8B9D6']
                  : ['#FFD7B5', '#C47A3A'],
            { begin: Align.topLeft, end: Align.bottomRight },
          ),
          border: `1.2px solid ${withAlpha(AppColors.petalWhite, 0.85)}`,
          boxShadow: boxShadow([{ blur: 8, color: withAlpha(color, 0.55) }]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon name={medalIcon} size={11} color={isPink ? (rank === 1 ? '#5D1032' : '#2A2340') : rank === 1 ? '#5E4200' : '#2A2340'} />
      </div>
    </div>
  );
}

function TopTrackRow({
  track,
  username,
  maxPlays,
  isPink,
}: {
  track: TopMusicTrack;
  username: string;
  maxPlays: number;
  isPink: boolean;
}) {
  const isPodium = track.rank <= 3;
  const color = podiumColorFor(track.rank, isPink);
  const fraction = Math.max(0.08, Math.min(1, track.playCount / Math.max(maxPlays, 1)));

  const openTrack = () =>
    void showListenAlong({
      username,
      trackName: track.trackName,
      artistName: track.artistName,
      albumName: track.albumName && track.albumName !== 'No Album' ? track.albumName : '',
      imageUrl: track.imageUrl,
      isPlaying: false,
      spotifyUrl: track.spotifyUrl,
      timestamp: null,
    });

  const rowCore = (
    <div style={{ minHeight: isPodium ? 66 : 62, display: 'flex', alignItems: 'center', gap: AppSpacing.md }}>
      <RankBadge rank={track.rank} isPink={isPink} />
      <PodiumArtwork imageUrl={track.imageUrl} rank={track.rank} isPink={isPink} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          className="ellipsis"
          style={{
            ...AppTypography.outfitHeading,
            fontSize: isPodium ? 15 : 14,
            lineHeight: 1.15,
            color: AppColors.petalWhite,
            textShadow: isPodium ? `0 0 12px ${withAlpha(color, 0.35)}` : undefined,
          }}
        >
          {track.trackName}
        </div>
        <div style={{ height: 2 }} />
        <div
          className="ellipsis"
          style={{
            ...AppTypography.outfitMedium,
            fontSize: 12.5,
            lineHeight: 1.15,
            color: isPodium ? withAlpha(AppColors.petalWhite, 0.88) : Derived.textMedium,
          }}
        >
          {track.artistName}
        </div>
        {isPodium && (
          <div
            style={{
              height: 4,
              borderRadius: 99,
              background: withAlpha(AppColors.petalWhite, 0.1),
              overflow: 'hidden',
              marginTop: 6,
            }}
          >
            <div
              style={{
                height: '100%',
                width: `${Math.round(fraction * 100)}%`,
                borderRadius: 99,
                background: linear([withAlpha(color, 0.95), withAlpha(color, 0.45)]),
                boxShadow: boxShadow([{ blur: 8, color: withAlpha(color, 0.55) }]),
              }}
            />
          </div>
        )}
      </div>
      {isPodium ? (
        <div
          style={{
            padding: '5px 9px',
            borderRadius: 99,
            background: linear([withAlpha(color, 0.22), withAlpha(color, 0.08)]),
            border: `1px solid ${withAlpha(color, 0.4)}`,
            boxShadow: boxShadow([{ blur: 14, color: withAlpha(color, 0.22) }]),
            textAlign: 'center',
            flexShrink: 0,
          }}
        >
          <div style={{ ...AppTypography.cormorantHeading, fontSize: 15, lineHeight: 1, color }}>
            {formatNumber(track.playCount)}
          </div>
          <div style={{ ...AppTypography.outfitMedium, fontSize: 8, fontWeight: 700, color: withAlpha(color, 0.85), letterSpacing: '1.1px', marginTop: 2 }}>
            {track.playCount === 1 ? 'play' : 'plays'}
          </div>
        </div>
      ) : (
        <div style={{ textAlign: 'right', flexShrink: 0, minWidth: 44 }}>
          <div style={{ ...AppTypography.cormorantHeading, fontSize: 18, lineHeight: 1, color: isPink ? AppColors.roseQuartz : AppColors.blushGold }}>
            {formatNumber(track.playCount)}
          </div>
          <div style={{ ...AppTypography.outfitMedium, fontSize: 9, fontWeight: 600, color: isPink ? withAlpha(AppColors.roseQuartz, 0.72) : Derived.textMuted, letterSpacing: '1.3px', marginTop: 3 }}>
            {track.playCount === 1 ? 'play' : 'plays'}
          </div>
        </div>
      )}
    </div>
  );

  if (!isPodium) {
    return (
      <button type="button" className="bare-button" onClick={openTrack} style={{ width: '100%', textAlign: 'left' }}>
        {rowCore}
      </button>
    );
  }

  const cardGradient = isPink
    ? track.rank === 1
      ? [withAlpha(AppColors.cinemaPink, 0.22), withAlpha(AppColors.deepRose, 0.2), withAlpha(AppColors.inkDeep, 0.32)]
      : track.rank === 2
        ? [withAlpha(AppColors.roseQuartz, 0.2), withAlpha('#522443', 0.22), withAlpha(AppColors.inkDeep, 0.3)]
        : [withAlpha(AppColors.softLavender, 0.2), withAlpha('#5B2A4A', 0.2), withAlpha(AppColors.inkDeep, 0.28)]
    : track.rank === 1
      ? [withAlpha(AppColors.auroraGold, 0.22), withAlpha('#8D6500', 0.22), withAlpha(AppColors.inkDeep, 0.35)]
      : track.rank === 2
        ? [withAlpha('#D8D6F0', 0.22), withAlpha('#3A3566', 0.22), withAlpha(AppColors.inkDeep, 0.32)]
        : [withAlpha('#E69F6B', 0.22), withAlpha('#6B3A14', 0.22), withAlpha(AppColors.inkDeep, 0.3)];

  return (
    <div style={{ position: 'relative', marginTop: track.rank === 1 ? 6 : 0 }}>
      <button
        type="button"
        className="bare-button stats-shimmer"
        onClick={openTrack}
        style={{
          width: '100%',
          textAlign: 'left',
          padding: '8px 10px',
          borderRadius: 18,
          background: linear(cardGradient, { begin: Align.topLeft, end: Align.bottomRight }),
          border: `1.25px solid ${withAlpha(color, 0.48)}`,
          boxShadow: boxShadow([
            { offset: [0, 8], blur: track.rank === 1 ? 22 : 16, color: withAlpha(color, track.rank === 1 ? 0.28 : 0.18) },
            { offset: [0, 4], blur: 14, color: withAlpha(AppColors.inkDeep, 0.45) },
          ]),
        }}
      >
        {rowCore}
      </button>
      {track.rank === 1 && (
        <div className="stats-sparkle" style={{ position: 'absolute', top: -6, right: 8, pointerEvents: 'none' }}>
          <Icon name="auto_awesome" size={13} color={withAlpha(color, 0.95)} />
        </div>
      )}
    </div>
  );
}

function RecentTrackRow({ status }: { status: MusicStatus }) {
  const isLive = status.isPlaying;
  return (
    <button
      type="button"
      className="bare-button"
      onClick={() => void showListenAlong(status)}
      style={{ width: '100%', textAlign: 'left' }}
    >
      <div style={{ minHeight: 62, padding: '6px 0', display: 'flex', alignItems: 'center', gap: AppSpacing.md }}>
        <JukeboxArtwork imageUrl={status.imageUrl} size={44} radius={12} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="ellipsis" style={{ ...AppTypography.outfitHeading, fontSize: 15, lineHeight: 1.15, color: AppColors.petalWhite }}>
              {status.trackName}
            </span>
            {isLive && (
              <span
                style={{
                  padding: '2px 7px',
                  borderRadius: 99,
                  background: withAlpha(AppColors.success, 0.16),
                  border: `1px solid ${withAlpha(AppColors.success, 0.45)}`,
                  ...AppTypography.outfitBold,
                  fontSize: 9,
                  letterSpacing: '0.8px',
                  color: AppColors.success,
                  flexShrink: 0,
                }}
              >
                LIVE
              </span>
            )}
          </div>
          <div style={{ height: 3 }} />
          <div className="ellipsis" style={{ ...AppTypography.outfitMedium, fontSize: 12.5, lineHeight: 1.15, color: Derived.textMedium }}>
            {status.artistName}
          </div>
        </div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
          <Icon name="schedule" size={13} color={isLive ? AppColors.warmAmber : Derived.textMuted} />
          <span
            style={{
              ...AppTypography.outfitMedium,
              fontSize: 11.5,
              fontWeight: isLive ? 700 : 500,
              color: isLive ? AppColors.warmAmber : Derived.textMedium,
            }}
          >
            {formatRelativeTime(status.timestamp, isLive)}
          </span>
        </div>
      </div>
    </button>
  );
}

async function enrichTrackListArtwork<T extends { artistName?: string; trackName: string; imageUrl: string | null; mbid?: string | null }>(
  list: T[],
  artistFallback: string | undefined,
  onPatch: (index: number, imageUrl: string, albumName?: string | null) => void,
  isAlive: () => boolean,
): Promise<void> {
  const missing = list
    .map((item, index) => ({ item, index }))
    .filter(({ item }) => !item.imageUrl);
  const concurrency = 4;
  for (let i = 0; i < missing.length; i += concurrency) {
    if (!isAlive()) return;
    const chunk = missing.slice(i, i + concurrency);
    const results = await Promise.all(
      chunk.map(async ({ item, index }) => {
        const artist = item.artistName ?? artistFallback ?? '';
        if (!artist) return null;
        const meta = await fetchTrackMetadata({ artist, track: item.trackName, mbid: item.mbid });
        return meta?.artworkUrl ? { index, artworkUrl: meta.artworkUrl, albumName: meta.albumName } : null;
      }),
    );
    if (!isAlive()) return;
    for (const r of results) {
      if (r) onPatch(r.index, r.artworkUrl, r.albumName);
    }
  }
}

export function MusicStatsSection() {
  const auth = useAuth();
  const { width } = useViewport();
  const [data, setData] = useState<MusicStatsData | null>(null);

  useEffect(() => {
    let alive = true;
    let lastLoadAt = 0;
    let inFlight = false;

    const load = () => {
      if (!alive || inFlight || document.visibilityState === 'hidden') return;
      inFlight = true;
      lastLoadAt = Date.now();
      void fetchMusicStats(auth.currentUser ?? undefined)
        .then((res) => {
          if (!alive) return;
          setData(res);
          void enrichTrackListArtwork(
            res.topTracks,
            undefined,
            (idx, imageUrl, albumName) =>
              setData((prev) =>
                prev
                  ? {
                      ...prev,
                      topTracks: prev.topTracks.map((t, i) =>
                        i === idx ? { ...t, imageUrl, albumName: albumName ?? t.albumName } : t,
                      ),
                    }
                  : prev,
              ),
            () => alive,
          );
          void enrichTrackListArtwork(
            res.clairTopTracks,
            undefined,
            (idx, imageUrl, albumName) =>
              setData((prev) =>
                prev
                  ? {
                      ...prev,
                      clairTopTracks: prev.clairTopTracks.map((t, i) =>
                        i === idx ? { ...t, imageUrl, albumName: albumName ?? t.albumName } : t,
                      ),
                    }
                  : prev,
              ),
            () => alive,
          );
          void enrichTrackListArtwork(
            res.recentTracks,
            undefined,
            (idx, imageUrl) =>
              setData((prev) =>
                prev
                  ? { ...prev, recentTracks: prev.recentTracks.map((t, i) => (i === idx ? { ...t, imageUrl } : t)) }
                  : prev,
              ),
            () => alive,
          );
          void enrichTrackListArtwork(
            res.clairRecentTracks,
            undefined,
            (idx, imageUrl) =>
              setData((prev) =>
                prev
                  ? { ...prev, clairRecentTracks: prev.clairRecentTracks.map((t, i) => (i === idx ? { ...t, imageUrl } : t)) }
                  : prev,
              ),
            () => alive,
          );
        })
        .finally(() => {
          inFlight = false;
        });
    };

    const onVisibility = () => {
      if (document.visibilityState === 'visible' && Date.now() - lastLoadAt > 30_000) {
        load();
      }
    };

    load();
    const interval = setInterval(load, 60_000);
    document.addEventListener('visibilitychange', onVisibility);
    return () => {
      alive = false;
      clearInterval(interval);
      document.removeEventListener('visibilitychange', onVisibility);
    };
  }, [auth.uid, auth.currentUser]);

  if (!data) {
    return (
      <div
        style={{
          padding: AppSpacing.xl,
          borderRadius: AppRadius.x2,
          background: linear([withAlpha(AppColors.velvet, 0.86), withAlpha(AppColors.inkDeep, 0.88)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.18)}`,
          display: 'flex',
          flexDirection: 'column',
          gap: 16,
        }}
      >
        <div style={{ width: 170, height: 18, borderRadius: 8, background: withAlpha(AppColors.moonlight, 0.12) }} />
        {[0, 1, 2, 3].map((i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 46, height: 46, borderRadius: 14, background: withAlpha(AppColors.moonlight, 0.1) }} />
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ height: 13, borderRadius: 6, background: withAlpha(AppColors.moonlight, 0.1) }} />
              <div style={{ width: 120, height: 11, borderRadius: 5, background: withAlpha(AppColors.moonlight, 0.08) }} />
            </div>
            <div style={{ width: 46, height: 11, borderRadius: 5, background: withAlpha(AppColors.moonlight, 0.08) }} />
          </div>
        ))}
      </div>
    );
  }

  const isWide = width - 32 >= 720;
  const kLeader = data.khentTotalPlays > 0 && data.khentTotalPlays > data.clairTotalPlays;
  const cLeader = data.clairTotalPlays > 0 && data.clairTotalPlays > data.khentTotalPlays;

  return (
    <div
      style={{
        padding: AppSpacing.xl,
        borderRadius: AppRadius.x2,
        background: linear([withAlpha(AppColors.velvet, 0.86), withAlpha(AppColors.inkDeep, 0.88)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
        boxShadow: boxShadow([{ offset: [0, 8], blur: 20, color: withAlpha(AppColors.inkDeep, 0.5) }]),
      }}
    >
      {isWide ? (
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 20 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <MusicStatsBlock
              displayName="Khent"
              username={LASTFM_USER_KHENT}
              topTracks={data.topTracks}
              recentTracks={data.recentTracks}
              totalPlays={data.khentTotalPlays}
              isLeader={kLeader}
              needsSpotifyRecentScope={Boolean(data.needsSpotifyRecentScope && auth.currentUser === LASTFM_USER_KHENT)}
            />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <MusicStatsBlock
              displayName="Clair"
              username={LASTFM_USER_CLAIR}
              topTracks={data.clairTopTracks}
              recentTracks={data.clairRecentTracks}
              totalPlays={data.clairTotalPlays}
              isLeader={cLeader}
              isClair
              needsSpotifyRecentScope={Boolean(data.needsSpotifyRecentScope && auth.currentUser === LASTFM_USER_CLAIR)}
            />
          </div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: AppSpacing.x2 }}>
          <MusicStatsBlock
            displayName="Khent"
            username={LASTFM_USER_KHENT}
            topTracks={data.topTracks}
            recentTracks={data.recentTracks}
            totalPlays={data.khentTotalPlays}
            isLeader={kLeader}
            needsSpotifyRecentScope={Boolean(data.needsSpotifyRecentScope && auth.currentUser === LASTFM_USER_KHENT)}
          />
          <StatsDivider />
          <MusicStatsBlock
            displayName="Clair"
            username={LASTFM_USER_CLAIR}
            topTracks={data.clairTopTracks}
            recentTracks={data.clairRecentTracks}
            totalPlays={data.clairTotalPlays}
            isLeader={cLeader}
            isClair
            needsSpotifyRecentScope={Boolean(data.needsSpotifyRecentScope && auth.currentUser === LASTFM_USER_CLAIR)}
          />
        </div>
      )}
    </div>
  );
}

function MusicStatsBlock({
  displayName,
  username,
  topTracks,
  recentTracks,
  totalPlays,
  isLeader,
  isClair = false,
  needsSpotifyRecentScope = false,
}: {
  displayName: string;
  username: string;
  topTracks: TopMusicTrack[];
  recentTracks: MusicStatus[];
  totalPlays: number;
  isLeader: boolean;
  isClair?: boolean;
  needsSpotifyRecentScope?: boolean;
}) {
  const maxPlays = topTracks.length > 0 ? Math.max(...topTracks.map((t) => t.playCount), 1) : 1;
  const content = (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <div style={{ minWidth: 0, flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span
              style={{
                ...AppTypography.cormorantBoldWhite,
                fontSize: 21,
                lineHeight: 1.05,
                textShadow: isLeader
                  ? `0 0 12px ${withAlpha(isClair ? AppColors.auroraRose : AppColors.auroraGold, 0.35)}`
                  : undefined,
              }}
            >
              {`${displayName}'s Top 10`}
            </span>
          </div>
          <div style={{ height: 2 }} />
          <div
            style={{
              ...AppTypography.handwrittenBody,
              fontSize: 17,
              lineHeight: 1.1,
              color: isClair ? AppColors.auroraRose : AppColors.blushGold,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            most listened, all-time
          </div>
        </div>
        {totalPlays > 0 && (
          <div
            style={{
              padding: '5px 10px',
              borderRadius: 99,
              background: withAlpha(AppColors.moonlight, 0.08),
              border: `1px solid ${withAlpha(isClair ? AppColors.auroraRose : AppColors.auroraGold, 0.3)}`,
              fontFamily: 'Outfit, sans-serif',
              fontSize: 11,
              fontWeight: 700,
              color: AppColors.petalWhite,
            }}
          >
            {`${formatNumber(totalPlays)} plays`}
          </div>
        )}
      </div>

      <div style={{ height: AppSpacing.lg }} />
      {topTracks.length === 0 ? (
        <EmptyStats />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {topTracks.map((track, idx) => (
            <div key={`${track.rank}-${track.trackName}`}>
              <TopTrackRow track={track} username={username} maxPlays={maxPlays} isPink={isClair} />
              {idx !== topTracks.length - 1 && (
                <div
                  style={{
                    margin: `${track.rank <= 3 ? 7 : 0}px 0`,
                    height: 1,
                    background: withAlpha(AppColors.moonlight, 0.14),
                  }}
                />
              )}
            </div>
          ))}
        </div>
      )}

      <div style={{ height: AppSpacing.x2 }} />
      <StatsDivider />
      <div style={{ height: AppSpacing.x2 }} />

      <div style={{ display: 'flex', alignItems: 'center', gap: AppSpacing.md }}>
        <div
          style={{
            width: 38,
            height: 38,
            borderRadius: '50%',
            background: linear(
              isClair
                ? [withAlpha(AppColors.auroraRose, 0.2), withAlpha(AppColors.cinemaPink, 0.1)]
                : [withAlpha(AppColors.blushGold, 0.18), withAlpha(AppColors.blushGold, 0.05)],
              { begin: Align.topLeft, end: Align.bottomRight },
            ),
            border: `1px solid ${withAlpha(isClair ? AppColors.auroraRose : AppColors.blushGold, 0.45)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <Icon name="history" size={18} color={isClair ? AppColors.auroraRose : AppColors.blushGold} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 21, lineHeight: 1.05 }}>Recently Heard</div>
          <div style={{ height: 2 }} />
          <div
            style={{
              ...AppTypography.handwrittenBody,
              fontSize: 17,
              lineHeight: 1.1,
              color: isClair ? AppColors.auroraRose : AppColors.blushGold,
            }}
          >
            latest 5 plays
          </div>
        </div>
        {needsSpotifyRecentScope && (
          <button
            type="button"
            className="bare-button"
            onClick={() =>
              void linkSpotify().catch((e: unknown) =>
                showSnackBar(String(e instanceof Error ? e.message : e).replace(/^Exception: /, '')),
              )
            }
            style={{
              padding: '6px 10px',
              borderRadius: 999,
              background: withAlpha('#1DB954', 0.16),
              border: `1px solid ${withAlpha('#1DB954', 0.4)}`,
              ...AppTypography.outfitBold,
              fontSize: 10.5,
              color: AppColors.petalWhite,
              flexShrink: 0,
            }}
          >
            Re-link Spotify
          </button>
        )}
      </div>

      <div style={{ height: AppSpacing.lg }} />
      {recentTracks.length === 0 ? (
        <EmptyStats />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {recentTracks.map((rt, idx) => (
            <div key={`${rt.trackName}-${idx}`}>
              <RecentTrackRow status={rt} />
              {idx !== recentTracks.length - 1 && <div style={{ height: 1, background: withAlpha(AppColors.moonlight, 0.14) }} />}
            </div>
          ))}
        </div>
      )}
    </div>
  );

  if (!isClair) return content;
  return (
    <div
      style={{
        padding: 12,
        borderRadius: 20,
        background: withAlpha(AppColors.auroraRose, 0.06),
        border: `1px solid ${withAlpha(AppColors.auroraRose, 0.14)}`,
        boxShadow: boxShadow([{ offset: [0, 4], blur: 16, color: withAlpha(AppColors.auroraRose, 0.1) }]),
      }}
    >
      {content}
    </div>
  );
}

function StatsDivider() {
  return (
    <div
      style={{
        height: 1,
        background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.28), AppColors.transparent]),
      }}
    />
  );
}

function EmptyStats() {
  return (
    <div
      style={{
        width: '100%',
        padding: `${AppSpacing.xl}px 0`,
        background: withAlpha(AppColors.moonlight, 0.06),
        borderRadius: AppRadius.md,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <Icon name="graphic_eq" size={26} color={AppColors.roseQuartz} />
      <div style={{ height: AppSpacing.sm }} />
      <span style={{ ...AppTypography.outfitMedium, fontSize: 13, color: Derived.textMedium }}>No music stats yet</span>
    </div>
  );
}

export function ArtistShowdownCard() {
  const auth = useAuth();
  const { width } = useViewport();
  const [artist, setArtist] = useState(DEFAULT_SHOWDOWN_ARTIST);
  const [artistImage, setArtistImage] = useState<string | null>(null);
  const [queryStr, setQueryStr] = useState('');
  const [suggestions, setSuggestions] = useState<ArtistSuggestion[]>([]);
  const [quickArtists, setQuickArtists] = useState<string[]>([DEFAULT_SHOWDOWN_ARTIST]);
  const [isLoading, setIsLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);
  const [khentTotal, setKhentTotal] = useState(0);
  const [clairTotal, setClairTotal] = useState(0);
  const [tracks, setTracks] = useState<ShowdownTrack[]>([]);
  const [historyOpen, setHistoryOpen] = useState(false);
  const reqIdRef = useRef(0);

  const loadArtist = async (target: string) => {
    const trimmed = target.trim();
    if (!trimmed) return;
    const reqId = ++reqIdRef.current;
    setArtist(trimmed);
    setArtistImage(null);
    setSuggestions([]);
    setExpanded(false);
    setIsLoading(true);
    void fetchArtistImage(trimmed).then((img) => {
      if (reqId === reqIdRef.current) setArtistImage(img);
    });
    const res = await fetchArtistShowdown(trimmed);
    if (reqId !== reqIdRef.current) return;
    setKhentTotal(res.khentTotal);
    setClairTotal(res.clairTotal);
    setTracks(res.tracks);
    setIsLoading(false);
    void enrichTrackListArtwork(
      res.tracks,
      trimmed,
      (idx, imageUrl) => {
        if (reqId !== reqIdRef.current) return;
        setTracks((prev) => prev.map((t, i) => (i === idx ? { ...t, imageUrl } : t)));
      },
      () => reqId === reqIdRef.current,
    );
  };

  useEffect(() => {
    void loadArtist(DEFAULT_SHOWDOWN_ARTIST);
    let alive = true;
    void fetchMusicStats().then((stats) => {
      if (!alive) return;
      const seen = new Set<string>([DEFAULT_SHOWDOWN_ARTIST.toLowerCase()]);
      const picks = [DEFAULT_SHOWDOWN_ARTIST];
      for (const tr of [...stats.topTracks, ...stats.clairTopTracks]) {
        const name = tr.artistName.trim();
        const key = name.toLowerCase();
        if (!name || key === 'unknown artist' || seen.has(key)) continue;
        seen.add(key);
        picks.push(name);
      }
      setQuickArtists(picks.slice(0, 12));
    });
    return () => {
      alive = false;
    };
  }, [auth.uid]);

  useEffect(() => {
    const q = queryStr.trim();
    if (q.length < 2) {
      setSuggestions([]);
      return;
    }
    let alive = true;
    const timer = window.setTimeout(() => {
      void searchLastfmArtists(q).then(async (list) => {
        if (!alive) return;
        setSuggestions(list);
        for (let i = 0; i < list.length; i++) {
          if (list[i].imageUrl) continue;
          const img = await fetchArtistImage(list[i].name);
          if (!alive || !img) continue;
          setSuggestions((prev) => prev.map((item, idx) => (idx === i ? { ...item, imageUrl: img } : item)));
        }
      });
    }, 300);
    return () => {
      alive = false;
      clearTimeout(timer);
    };
  }, [queryStr]);

  const hasData = khentTotal > 0 || clairTotal > 0;
  const isCompact = width - 32 - AppSpacing.xl * 2 < 360;
  const totalSum = Math.max(khentTotal + clairTotal, 1);
  const kShare = hasData ? khentTotal / totalSum : 0.5;
  const shownTracks = expanded ? tracks : tracks.slice(0, 6);

  return (
    <div
      style={{
        padding: AppSpacing.xl,
        borderRadius: AppRadius.x2,
        background: linear([withAlpha(AppColors.velvet, 0.92), withAlpha(AppColors.inkDeep, 0.96)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
        boxShadow: boxShadow([{ offset: [0, 8], blur: 22, color: withAlpha(AppColors.inkDeep, 0.45) }]),
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'stretch',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div
          style={{
            width: 38,
            height: 38,
            borderRadius: '50%',
            overflow: 'hidden',
            background: linear([AppColors.cinemaPink, AppColors.auroraLilac], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.4)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          {artistImage ? (
            <img
              src={artistImage}
              alt={artist}
              onError={() => setArtistImage(null)}
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
            />
          ) : (
            <Icon name="leaderboard" size={18} color={AppColors.petalWhite} />
          )}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ ...AppTypography.outfitBold, fontSize: 10, letterSpacing: '1.8px', color: AppColors.blushGold }}>
            ARTIST SHOWDOWN
          </div>
          <div
            style={{
              ...AppTypography.outfitMedium,
              fontSize: 11,
              color: Derived.textMuted,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {`${artist} • Khent vs Clair`}
          </div>
        </div>
        <button
          type="button"
          className="bare-button"
          onClick={() => void loadArtist(artist)}
          style={{
            padding: isCompact ? '6px 8px' : '6px 10px',
            borderRadius: 99,
            background: withAlpha(AppColors.petalWhite, 0.08),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
            color: AppColors.blushGold,
          }}
        >
          <Icon name="refresh" size={14} color={AppColors.blushGold} />
          {!isCompact && (
            <span style={{ ...AppTypography.outfitBold, fontSize: 11, letterSpacing: '0.5px', color: AppColors.blushGold }}>
              Refresh
            </span>
          )}
        </button>
        <button
          type="button"
          className="bare-button"
          onClick={() => setHistoryOpen(true)}
          style={{
            padding: '6px 10px',
            borderRadius: 99,
            background: withAlpha(AppColors.petalWhite, 0.08),
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
            display: 'inline-flex',
            alignItems: 'center',
            gap: 5,
            color: AppColors.blushGold,
          }}
        >
          <Icon name="schedule" size={14} color={AppColors.blushGold} />
          {!isCompact && (
            <span style={{ ...AppTypography.outfitBold, fontSize: 11, letterSpacing: '0.5px', color: AppColors.blushGold }}>
              History
            </span>
          )}
        </button>
      </div>

      <div style={{ height: AppSpacing.lg }} />

      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          background: withAlpha(AppColors.petalWhite, 0.05),
          border: `1px solid ${withAlpha(AppColors.petalWhite, 0.1)}`,
          borderRadius: 14,
          padding: '0 6px 0 12px',
          height: 44,
          gap: 8,
        }}
      >
        <Icon name="search" size={18} color={AppColors.roseQuartz} />
        <input
          type="text"
          value={queryStr}
          onChange={(e) => setQueryStr(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && queryStr.trim()) {
              void loadArtist(queryStr);
              setQueryStr('');
            }
          }}
          placeholder="Pick an artist… try Lana Del Rey"
          style={{
            flex: 1,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            ...AppTypography.outfitMedium,
            fontSize: 13,
            color: AppColors.petalWhite,
          }}
        />
        <button
          type="button"
          className="bare-button"
          onClick={() => {
            if (queryStr.trim()) {
              void loadArtist(queryStr);
              setQueryStr('');
            }
          }}
          style={{ padding: 8, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <Icon name="arrow_forward" size={18} color={AppColors.blushGold} />
        </button>
      </div>

      {suggestions.length > 0 && (
        <div
          style={{
            marginTop: 8,
            borderRadius: 12,
            background: AppColors.inkDeep,
            border: `1px solid ${withAlpha(AppColors.petalWhite, 0.12)}`,
            overflow: 'hidden',
          }}
        >
          {suggestions.map((s) => (
            <button
              key={s.name}
              type="button"
              className="bare-button"
              onClick={() => {
                void loadArtist(s.name);
                setQueryStr('');
              }}
              style={{
                width: '100%',
                padding: '8px 12px',
                textAlign: 'left',
                display: 'flex',
                alignItems: 'center',
                gap: 10,
                color: AppColors.petalWhite,
                ...AppTypography.outfitMedium,
                fontSize: 12.5,
              }}
            >
              <JukeboxArtwork imageUrl={s.imageUrl} size={36} radius={10} borderColor={withAlpha(AppColors.petalWhite, 0.08)} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="ellipsis" style={{ ...AppTypography.outfitHeading, fontSize: 13, color: AppColors.petalWhite }}>
                  {s.name}
                </div>
                <div style={{ fontSize: 11, color: Derived.textMuted }}>
                  {s.listeners > 0 ? `${formatNumber(s.listeners)} listeners` : 'Tap to compare'}
                </div>
              </div>
              <Icon name="north_west" size={15} color={AppColors.blushGold} />
            </button>
          ))}
        </div>
      )}

      <div style={{ height: AppSpacing.md }} />

      <div className="no-scrollbar" style={{ display: 'flex', gap: 8, overflowX: 'auto' }}>
        {quickArtists.map((a) => {
          const selected = a.toLowerCase() === artist.trim().toLowerCase();
          return (
            <button
              key={a}
              type="button"
              className="bare-button"
              onClick={() => void loadArtist(a)}
              style={{
                padding: '7px 12px',
                borderRadius: 99,
                background: selected ? withAlpha(AppColors.blushGold, 0.16) : withAlpha(AppColors.petalWhite, 0.05),
                border: `1px solid ${selected ? withAlpha(AppColors.blushGold, 0.45) : withAlpha(AppColors.petalWhite, 0.1)}`,
                ...AppTypography.outfitBold,
                fontSize: 11,
                color: selected ? AppColors.blushGold : Derived.textMedium,
                whiteSpace: 'nowrap',
              }}
            >
              {a}
            </button>
          );
        })}
      </div>

      <div style={{ height: AppSpacing.lg }} />

      {isLoading && !hasData ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: AppSpacing.lg }}>
          <div style={{ display: 'flex', gap: 10 }}>
            <div style={{ flex: 1, height: 86, borderRadius: 14, background: withAlpha(AppColors.moonlight, 0.1) }} />
            <div style={{ flex: 1, height: 86, borderRadius: 14, background: withAlpha(AppColors.moonlight, 0.1) }} />
          </div>
          <div style={{ height: 13, borderRadius: 6, background: withAlpha(AppColors.moonlight, 0.08) }} />
          <div style={{ height: 13, borderRadius: 6, background: withAlpha(AppColors.moonlight, 0.08) }} />
          <div style={{ width: 200, height: 13, borderRadius: 6, background: withAlpha(AppColors.moonlight, 0.08) }} />
        </div>
      ) : !hasData ? (
        <div
          style={{
            width: '100%',
            padding: 20,
            background: withAlpha(AppColors.petalWhite, 0.04),
            borderRadius: AppRadius.md,
            border: `1px solid ${withAlpha(AppColors.petalWhite, 0.06)}`,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
          }}
        >
          <Icon name="leaderboard" size={22} color={AppColors.roseQuartz} />
          <div style={{ height: 8 }} />
          <span style={{ ...AppTypography.outfitMedium, fontSize: 12, color: Derived.textMedium }}>
            {`No ${artist} plays yet`}
          </span>
          <span style={{ ...AppTypography.outfitMedium, fontSize: 11, color: Derived.textMuted }}>
            Play one and take the lead.
          </span>
          <div style={{ height: 12 }} />
          <button
            type="button"
            className="bare-button"
            onClick={() => void loadArtist(artist)}
            style={{
              padding: '6px 14px',
              borderRadius: 99,
              background: withAlpha(AppColors.petalWhite, 0.08),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 6,
            }}
          >
            <Icon name="refresh" size={14} color={AppColors.blushGold} />
            <span style={{ ...AppTypography.outfitBold, fontSize: 11, letterSpacing: '0.5px', color: AppColors.blushGold }}>
              Refresh
            </span>
          </button>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: AppSpacing.md }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <ScoreBlock name="Khent" plays={khentTotal} color={AppColors.auroraTeal} isLeader={khentTotal > clairTotal} />
            <span
              style={{
                padding: '0 10px',
                ...AppTypography.outfitBold,
                fontSize: 11,
                letterSpacing: '1.5px',
                color: Derived.textMuted,
              }}
            >
              VS
            </span>
            <ScoreBlock
              name="Clair"
              plays={clairTotal}
              color={AppColors.cinemaPink}
              isLeader={clairTotal > khentTotal}
              alignEnd
            />
          </div>
          <div style={{ height: 8, borderRadius: 99, overflow: 'hidden', display: 'flex' }}>
            <div style={{ flex: Math.max(Math.round(kShare * 1000), 1), background: AppColors.auroraTeal }} />
            <div
              style={{ flex: Math.max(Math.round((1 - kShare) * 1000), 1), background: withAlpha(AppColors.cinemaPink, 0.85) }}
            />
          </div>

          <button
            type="button"
            className="bare-button"
            onClick={() => setHistoryOpen(true)}
            style={{
              padding: '10px 14px',
              borderRadius: 12,
              background: withAlpha(AppColors.petalWhite, 0.04),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.26)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
            }}
          >
            <Icon name="history" size={15} color={AppColors.blushGold} />
            <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.blushGold }}>
              {`View ${artist} listening history`}
            </span>
            <Icon name="chevron_right" size={15} color={AppColors.blushGold} />
          </button>

          <div style={{ display: 'flex', flexDirection: 'column' }}>
            {shownTracks.map((t, i) => {
              const leader = t.khentPlays > t.clairPlays ? 'khent' : t.clairPlays > t.khentPlays ? 'clair' : null;
              const leaderColor = leader === 'khent' ? AppColors.auroraTeal : leader === 'clair' ? AppColors.cinemaPink : Derived.textMuted;
              return (
                <button
                  key={t.trackName}
                  type="button"
                  className="bare-button"
                  onClick={() =>
                    void showListenAlong({
                      username: '',
                      trackName: t.trackName,
                      artistName: artist,
                      albumName: '',
                      imageUrl: t.imageUrl,
                      isPlaying: false,
                      spotifyUrl: t.spotifyUrl,
                      timestamp: null,
                    })
                  }
                  style={{ width: '100%', textAlign: 'left' }}
                >
                  <div style={{ height: 58, display: 'flex', alignItems: 'center', gap: 10 }}>
                    <span style={{ width: 22, ...AppTypography.outfitBold, fontSize: 11, color: Derived.textMuted }}>
                      {i + 1}
                    </span>
                    <JukeboxArtwork
                      imageUrl={t.imageUrl}
                      size={40}
                      radius={10}
                      borderColor={withAlpha(AppColors.petalWhite, 0.08)}
                      iconSize={16}
                    />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className="ellipsis" style={{ ...AppTypography.outfitHeading, fontSize: 13, color: AppColors.petalWhite }}>
                        {t.trackName}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 2 }}>
                        <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.auroraTeal }}>
                          {`Khent ${formatNumber(t.khentPlays)}`}
                        </span>
                        <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.cinemaPink }}>
                          {`Clair ${formatNumber(t.clairPlays)}`}
                        </span>
                      </div>
                    </div>
                    <span style={{ width: 8, height: 8, borderRadius: '50%', background: leaderColor, flexShrink: 0 }} />
                  </div>
                </button>
              );
            })}
          </div>

          {tracks.length > 6 && (
            <button
              type="button"
              className="bare-button"
              onClick={() => setExpanded((v) => !v)}
              style={{
                alignSelf: 'center',
                ...AppTypography.outfitBold,
                fontSize: 11,
                color: AppColors.blushGold,
                padding: '6px 12px',
                borderRadius: 99,
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.28)}`,
              }}
            >
              {expanded ? 'Show less' : `Show all ${tracks.length} songs`}
            </button>
          )}
        </div>
      )}

      {historyOpen && <ShowdownHistoryModal artist={artist} onClose={() => setHistoryOpen(false)} />}
    </div>
  );
}

function ShowdownHistoryModal({ artist, onClose }: { artist: string; onClose: () => void }) {
  const [filter, setFilter] = useState<'both' | 'khent' | 'clair'>('both');
  const [loading, setLoading] = useState(true);
  const [khent, setKhent] = useState<MusicStatus[]>([]);
  const [clair, setClair] = useState<MusicStatus[]>([]);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    void fetchArtistShowdownHistory(artist).then((res) => {
      if (!alive) return;
      setKhent(res.khent);
      setClair(res.clair);
      setLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [artist]);

  const combined = useMemo(() => {
    const items: { status: MusicStatus; isKhent: boolean }[] = [];
    if (filter !== 'clair') for (const s of khent) items.push({ status: s, isKhent: true });
    if (filter !== 'khent') for (const s of clair) items.push({ status: s, isKhent: false });
    items.sort((a, b) => (b.status.timestamp?.getTime() ?? 0) - (a.status.timestamp?.getTime() ?? 0));
    return items;
  }, [filter, khent, clair]);

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        background: withAlpha(AppColors.inkDeep, 0.72),
        zIndex: 1100,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 16,
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 560,
          maxHeight: '82vh',
          display: 'flex',
          flexDirection: 'column',
          borderRadius: 24,
          background: linear([AppColors.velvet, AppColors.inkDeep]),
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.3)}`,
          overflow: 'hidden',
        }}
      >
        <div style={{ padding: '16px 20px', borderBottom: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`, display: 'flex', alignItems: 'center', gap: 12 }}>
          <Icon name="history" size={20} color={AppColors.blushGold} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.cormorantBoldWhite, fontSize: 21 }}>{`${artist} History`}</div>
            <div style={{ ...AppTypography.outfitMuted, fontSize: 11 }}>Recent scrobbles by Khent &amp; Clair</div>
          </div>
          <button type="button" className="bare-button" aria-label="Close" onClick={onClose} style={{ padding: 6 }}>
            <Icon name="close" size={20} color={Derived.textMedium} />
          </button>
        </div>

        <div style={{ padding: '12px 20px 8px', display: 'flex', gap: 8 }}>
          {(['both', 'khent', 'clair'] as const).map((k) => {
            const active = filter === k;
            return (
              <button
                key={k}
                type="button"
                className="bare-button"
                onClick={() => setFilter(k)}
                style={{
                  padding: '6px 12px',
                  borderRadius: 99,
                  background: active ? withAlpha(AppColors.blushGold, 0.18) : withAlpha(AppColors.petalWhite, 0.05),
                  border: `1px solid ${active ? withAlpha(AppColors.blushGold, 0.5) : withAlpha(AppColors.petalWhite, 0.1)}`,
                  ...AppTypography.outfitBold,
                  fontSize: 11.5,
                  color: active ? AppColors.blushGold : Derived.textMedium,
                }}
              >
                {k === 'both' ? 'Both' : k === 'khent' ? 'Khent' : 'Clair'}
              </button>
            );
          })}
        </div>

        <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', padding: '8px 20px 20px' }}>
          {loading ? (
            <div style={{ padding: 28, textAlign: 'center', color: Derived.textMuted }}>Loading listening history…</div>
          ) : combined.length === 0 ? (
            <div style={{ padding: 28, textAlign: 'center', color: Derived.textMuted }}>No recent plays found for {artist}.</div>
          ) : (
            combined.map((entry, idx) => (
              <div
                key={`${entry.status.username}-${entry.status.trackName}-${idx}`}
                style={{
                  padding: '10px 0',
                  borderBottom: idx === combined.length - 1 ? undefined : `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                }}
              >
                <JukeboxArtwork imageUrl={entry.status.imageUrl} size={38} radius={10} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="ellipsis" style={{ ...AppTypography.outfitHeading, fontSize: 13, color: AppColors.petalWhite }}>
                    {entry.status.trackName}
                  </div>
                  <div style={{ ...AppTypography.outfitMedium, fontSize: 11, color: entry.isKhent ? AppColors.auroraTeal : AppColors.cinemaPink }}>
                    {entry.isKhent ? 'Khent' : 'Clair'}
                  </div>
                </div>
                <span style={{ ...AppTypography.outfitMedium, fontSize: 11, color: Derived.textMuted }}>
                  {formatRelativeTime(entry.status.timestamp, entry.status.isPlaying)}
                </span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

function ScoreBlock({
  name,
  plays,
  color,
  isLeader,
  alignEnd = false,
}: {
  name: string;
  plays: number;
  color: string;
  isLeader: boolean;
  alignEnd?: boolean;
}) {
  return (
    <div
      style={{
        flex: 1,
        padding: '10px 12px',
        borderRadius: 14,
        background: withAlpha(color, isLeader ? 0.14 : 0.06),
        border: `1px solid ${withAlpha(color, isLeader ? 0.45 : 0.18)}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: alignEnd ? 'flex-end' : 'flex-start',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        {isLeader && <Icon name="emoji_events" size={12} color={color} />}
        <span style={{ ...AppTypography.outfitBold, fontSize: 11, color }}>{name}</span>
      </div>
      <span style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22, lineHeight: 1.1 }}>{formatNumber(plays)}</span>
    </div>
  );
}
