// Ports of lib/features/jukebox/presentation/widgets/{jukebox_widget,music_stats_section,artist_showdown_card}.dart.
import { useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, AppArt, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, boxShadow, linear, radial } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import {
  DEFAULT_SHOWDOWN_ARTIST,
  LASTFM_USER_CLAIR,
  LASTFM_USER_KHENT,
  disconnectSpotify,
  emptyMusicStatus,
  fetchArtistShowdown,
  fetchMusicStats,
  musicStatusSource,
  searchLastfmArtists,
  spotifyTokenSource,
  type ArtistSuggestion,
  type MusicStatsData,
  type MusicStatus,
  type ShowdownTrack,
  type SpotifyLinkState,
  type TopMusicTrack,
} from './jukeboxService';

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

function openExternal(url: string) {
  window.open(url, '_blank', 'noopener,noreferrer');
}

const GRAIN_DOTS = (() => {
  const dots: { x: number; y: number; r: number }[] = [];
  let s = 42;
  const next = () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 0xffffffff;
  };
  for (let i = 0; i < 120; i++) {
    dots.push({
      x: Math.round(next() * 1000) / 10,
      y: Math.round(next() * 1000) / 10,
      r: next() * 0.7 + 0.3,
    });
  }
  return dots;
})();

export function JukeboxWidget() {
  const auth = useAuth();
  const { width } = useViewport();
  const statuses = useSource<Record<string, MusicStatus>>(() => musicStatusSource(), [auth.uid], {});
  const khentStatus = statuses[LASTFM_USER_KHENT] ?? emptyMusicStatus(LASTFM_USER_KHENT);
  const clairStatus = statuses[LASTFM_USER_CLAIR] ?? emptyMusicStatus(LASTFM_USER_CLAIR);
  const eitherLive = khentStatus.isPlaying || clairStatus.isPlaying;
  const isMobile = width - 32 < 620;

  return (
    <div
      style={{
        position: 'relative',
        borderRadius: AppRadius.x2,
        background: linear(
          [
            withAlpha(AppColors.velvet, 0.78),
            withAlpha(AppColors.inkDeep, 0.82),
            withAlpha('#1E1230', 0.78),
          ],
          { begin: Align.topLeft, end: Align.bottomRight },
        ),
        border: `1px solid ${withAlpha(AppColors.moonlight, eitherLive ? 0.18 : 0.12)}`,
        boxShadow: boxShadow([
          { offset: [0, 12], blur: 28, color: withAlpha(AppColors.inkDeep, 0.5) },
          ...(eitherLive ? [{ blur: 36, spread: -4, color: withAlpha(AppColors.deepRose, 0.11) }] : []),
        ]),
        overflow: 'hidden',
      }}
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
          opacity: 0.25,
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
          opacity: 0.27,
          background: radial([withAlpha(AppColors.auroraLilac, 0.55), AppColors.transparent], { size: [220, 220] }),
          pointerEvents: 'none',
        }}
      />
      <svg
        aria-hidden
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}
      >
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

      <div style={{ position: 'relative', padding: 18 }}>
        <JukeboxHeader eitherLive={eitherLive} />
        <div style={{ height: 12 }} />
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
        <span
          style={{
            fontFamily: 'Outfit, sans-serif',
            fontSize: 12.5,
            fontWeight: 800,
            letterSpacing: '1.4px',
            color: withAlpha(AppColors.petalWhite, 0.92),
          }}
        >
          JUKEBOX
        </span>
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
          background: eitherLive
            ? withAlpha(AppColors.success, 0.12)
            : withAlpha(AppColors.moonlight, 0.08),
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
            fontSize: 10,
            fontWeight: 800,
            letterSpacing: '0.9px',
            color: eitherLive ? AppColors.success : withAlpha(AppColors.petalWhite, 0.5),
          }}
        >
          {eitherLive ? 'ON AIR' : 'STANDBY'}
        </span>
      </div>
    </div>
  );
}

const EMPTY_SPOTIFY_LINK: SpotifyLinkState = { isLinked: false, spotifyUserId: null, displayName: null };

function SpotifyConnectCard() {
  const auth = useAuth();
  const link = useSource<SpotifyLinkState>(
    () => spotifyTokenSource(auth.uid),
    [auth.uid],
    EMPTY_SPOTIFY_LINK,
  );

  return (
    <div
      style={{
        padding: '12px 14px',
        background: withAlpha(AppColors.velvet, 0.6),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
        display: 'flex',
        alignItems: 'center',
        gap: 10,
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
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <span style={{ color: AppColors.petalWhite, fontWeight: 700, fontSize: 13 }}>
          {link.isLinked ? 'Spotify linked' : 'Connect Spotify'}
        </span>
        <span style={{ color: withAlpha(AppColors.petalWhite, 0.6), fontSize: 11 }}>
          {link.isLinked
            ? link.displayName ?? link.spotifyUserId ?? 'Premium ✓'
            : 'For in-app playback (Duo required)'}
        </span>
      </div>
      {!link.isLinked ? (
        <button
          type="button"
          className="bare-button"
          onClick={() => showSnackBar('Open /jukebox while signed in to connect Spotify.')}
          style={{
            background: '#1DB954',
            color: AppColors.petalWhite,
            padding: '10px 14px',
            borderRadius: 999,
            fontSize: 12,
            fontWeight: 800,
          }}
        >
          Connect
        </button>
      ) : (
        <button
          type="button"
          className="bare-button"
          onClick={() => void disconnectSpotify()}
          style={{
            color: withAlpha(AppColors.petalWhite, 0.65),
            padding: '8px 10px',
            fontSize: 12,
            fontWeight: 600,
          }}
        >
          Disconnect
        </button>
      )}
    </div>
  );
}

function MusicCard({ status, title }: { status: MusicStatus; title: string }) {
  const [hovered, setHovered] = useState(false);
  const isLive = status.isPlaying;

  return (
    <button
      type="button"
      className="bare-button"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={() => {
        if (status.trackName) openExternal(status.spotifyUrl);
        else showSnackBar(`${status.username} is offline right now`);
      }}
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
            ? linear(
                [
                  withAlpha(AppColors.moonlight, 0.18),
                  withAlpha(AppColors.velvet, 0.55),
                  withAlpha(AppColors.plum, 0.55),
                ],
                { begin: Align.topLeft, end: Align.bottomRight },
              )
            : withAlpha(AppColors.moonlight, 0.1),
          border: `${isLive ? 1.2 : 1}px solid ${
            isLive
              ? withAlpha(AppColors.blushGold, 0.42)
              : withAlpha(AppColors.moonlight, hovered ? 0.22 : 0.14)
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
          overflow: 'hidden',
        }}
      >
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
            <Icon
              name="music_note"
              size={11}
              color={isLive ? AppColors.blushGold : withAlpha(AppColors.moonlight, 0.6)}
            />
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
                lineHeight: 1.1,
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

export function MusicStatsSection() {
  const auth = useAuth();
  const { width } = useViewport();
  const [data, setData] = useState<MusicStatsData | null>(null);

  useEffect(() => {
    let alive = true;
    void fetchMusicStats().then((res) => {
      if (alive) setData(res);
    });
    return () => {
      alive = false;
    };
  }, [auth.uid]);

  if (!data) {
    return (
      <div
        style={{
          padding: AppSpacing.xl,
          borderRadius: AppRadius.x2,
          background: linear(
            [withAlpha(AppColors.velvet, 0.86), withAlpha(AppColors.inkDeep, 0.88)],
            { begin: Align.topLeft, end: Align.bottomRight },
          ),
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
        background: linear(
          [withAlpha(AppColors.velvet, 0.86), withAlpha(AppColors.inkDeep, 0.88)],
          { begin: Align.topLeft, end: Align.bottomRight },
        ),
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
}: {
  displayName: string;
  username: string;
  topTracks: TopMusicTrack[];
  recentTracks: MusicStatus[];
  totalPlays: number;
  isLeader: boolean;
  isClair?: boolean;
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
              ...AppTypography.outfitMedium,
              fontSize: 10,
              fontWeight: 600,
              color: isClair ? AppColors.auroraRose : AppColors.blushGold,
              letterSpacing: '1.6px',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            {`${username} · most listened all-time`.toUpperCase()}
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
              <div style={{ height: track.rank <= 3 ? 66 : 62, display: 'flex', alignItems: 'center', gap: AppSpacing.md }}>
                <span
                  style={{
                    width: 24,
                    textAlign: 'center',
                    ...AppTypography.outfitBold,
                    fontSize: 13,
                    color: track.rank <= 3 ? (isClair ? AppColors.auroraRose : AppColors.auroraGold) : Derived.textMuted,
                  }}
                >
                  #{track.rank}
                </span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{
                      ...AppTypography.outfitHeading,
                      fontSize: track.rank <= 3 ? 15 : 14,
                      lineHeight: 1.15,
                      color: AppColors.petalWhite,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {track.trackName}
                  </div>
                  <div
                    style={{
                      ...AppTypography.outfitMedium,
                      fontSize: 12.5,
                      lineHeight: 1.15,
                      color: track.rank <= 3 ? withAlpha(AppColors.petalWhite, 0.88) : Derived.textMedium,
                      whiteSpace: 'nowrap',
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    {track.artistName}
                  </div>
                </div>
                <div style={{ textAlign: 'right', minWidth: 46 }}>
                  <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: AppColors.blushGold }}>
                    {formatNumber(track.playCount)}
                  </span>
                  <div
                    style={{
                      height: 3,
                      width: 46,
                      borderRadius: 99,
                      background: withAlpha(AppColors.moonlight, 0.1),
                      overflow: 'hidden',
                      marginTop: 4,
                    }}
                  >
                    <div
                      style={{
                        height: '100%',
                        width: `${Math.round((track.playCount / maxPlays) * 100)}%`,
                        background: isClair ? AppColors.auroraRose : AppColors.blushGold,
                      }}
                    />
                  </div>
                </div>
              </div>
              {idx !== topTracks.length - 1 && (
                <div style={{ margin: `${track.rank <= 3 ? 7 : 0}px 0`, height: 1, background: withAlpha(AppColors.moonlight, 0.14) }} />
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
              ...AppTypography.outfitMedium,
              fontSize: 10,
              fontWeight: 600,
              color: isClair ? AppColors.auroraRose : AppColors.blushGold,
              letterSpacing: '1.6px',
            }}
          >
            {`${username}'s latest 5 scrobbles`.toUpperCase()}
          </div>
        </div>
      </div>

      <div style={{ height: AppSpacing.lg }} />
      {recentTracks.length === 0 ? (
        <EmptyStats />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {recentTracks.map((rt, idx) => (
            <div key={`${rt.trackName}-${idx}`}>
              <div style={{ padding: '8px 0', display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ ...AppTypography.outfitHeading, fontSize: 13.5, color: AppColors.petalWhite, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {rt.trackName}
                  </div>
                  <div style={{ ...AppTypography.outfitMedium, fontSize: 12, color: Derived.textMedium, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {rt.artistName}
                  </div>
                </div>
                {rt.timestamp && (
                  <span style={{ ...AppTypography.outfitMedium, fontSize: 11, color: Derived.textMuted }}>
                    {formatTime(rt.timestamp)}
                  </span>
                )}
              </div>
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
      <span style={{ ...AppTypography.outfitMedium, fontSize: 13, color: Derived.textMedium }}>
        No music stats yet
      </span>
    </div>
  );
}

export function ArtistShowdownCard() {
  const auth = useAuth();
  const { width } = useViewport();
  const [artist, setArtist] = useState(DEFAULT_SHOWDOWN_ARTIST);
  const [queryStr, setQueryStr] = useState('');
  const [suggestions, setSuggestions] = useState<ArtistSuggestion[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);
  const [khentTotal, setKhentTotal] = useState(0);
  const [clairTotal, setClairTotal] = useState(0);
  const [tracks, setTracks] = useState<ShowdownTrack[]>([]);
  const reqIdRef = useRef(0);

  const loadArtist = async (target: string) => {
    const trimmed = target.trim();
    if (!trimmed) return;
    const reqId = ++reqIdRef.current;
    setArtist(trimmed);
    setSuggestions([]);
    setIsLoading(true);
    const res = await fetchArtistShowdown(trimmed);
    if (reqId !== reqIdRef.current) return;
    setKhentTotal(res.khentTotal);
    setClairTotal(res.clairTotal);
    setTracks(res.tracks);
    setIsLoading(false);
  };

  useEffect(() => {
    void loadArtist(DEFAULT_SHOWDOWN_ARTIST);
  }, [auth.uid]);

  useEffect(() => {
    const q = queryStr.trim();
    if (q.length < 2) {
      setSuggestions([]);
      return;
    }
    const timer = window.setTimeout(() => {
      void searchLastfmArtists(q).then(setSuggestions);
    }, 300);
    return () => clearTimeout(timer);
  }, [queryStr]);

  const hasData = khentTotal > 0 || clairTotal > 0;
  const isCompact = width - 32 - AppSpacing.xl * 2 < 360;
  const quickArtists = useMemo(() => [DEFAULT_SHOWDOWN_ARTIST], []);
  const totalSum = Math.max(khentTotal + clairTotal, 1);
  const kShare = hasData ? khentTotal / totalSum : 0.5;
  const shownTracks = expanded ? tracks : tracks.slice(0, 6);

  return (
    <div
      style={{
        padding: AppSpacing.xl,
        borderRadius: AppRadius.x2,
        background: linear(
          [withAlpha(AppColors.velvet, 0.92), withAlpha(AppColors.inkDeep, 0.96)],
          { begin: Align.topLeft, end: Align.bottomRight },
        ),
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
            width: 36,
            height: 36,
            borderRadius: '50%',
            background: linear([AppColors.cinemaPink, AppColors.auroraLilac], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <Icon name="leaderboard" size={18} color={AppColors.petalWhite} />
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
          onClick={() => showSnackBar(`Play history for ${artist} requires signed-in Last.fm access.`)}
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
            background: withAlpha(AppColors.velvet, 0.95),
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
                padding: '10px 12px',
                textAlign: 'left',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                color: AppColors.petalWhite,
                ...AppTypography.outfitMedium,
                fontSize: 12.5,
              }}
            >
              <span>{s.name}</span>
              <span style={{ fontSize: 11, color: Derived.textMuted }}>{`${formatNumber(s.listeners)} listeners`}</span>
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
            <span style={{ padding: '0 10px', ...AppTypography.outfitBold, fontSize: 11, letterSpacing: '1.5px', color: Derived.textMuted }}>
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
            <div style={{ flex: Math.max(Math.round((1 - kShare) * 1000), 1), background: withAlpha(AppColors.cinemaPink, 0.85) }} />
          </div>
          {shownTracks.map((t) => (
            <div key={t.trackName} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '6px 0' }}>
              <span style={{ ...AppTypography.outfitMedium, fontSize: 12.5, color: AppColors.petalWhite, flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {t.trackName}
              </span>
              <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.auroraTeal, marginLeft: 12 }}>
                {formatNumber(t.khentPlays)}
              </span>
              <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.cinemaPink, marginLeft: 10 }}>
                {formatNumber(t.clairPlays)}
              </span>
            </div>
          ))}
          {tracks.length > 6 && (
            <button
              type="button"
              className="bare-button"
              onClick={() => setExpanded((v) => !v)}
              style={{ alignSelf: 'center', ...AppTypography.outfitBold, fontSize: 11, color: AppColors.blushGold, padding: '4px 8px' }}
            >
              {expanded ? 'Show less' : `Show all ${tracks.length} tracks`}
            </button>
          )}
        </div>
      )}
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
      <span style={{ ...AppTypography.outfitBold, fontSize: 11, color }}>{name}</span>
      <span style={{ ...AppTypography.cormorantBoldWhite, fontSize: 22, lineHeight: 1.1 }}>{formatNumber(plays)}</span>
    </div>
  );
}
