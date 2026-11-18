// Port of lib/features/jukebox/presentation/widgets/listen_along_popup.dart.
import { useEffect, useState, type CSSProperties, type ReactNode } from 'react';
import { useAuth } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { boxShadow } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { awardDaily, playAward } from '../xp/xpService';
import { spotifyTokenSource, type MusicStatus, type SpotifyLinkState } from './jukeboxService';
import { fetchTrackAlbum, hasSpotifyTrack, playInEverglow, resolveSpotify, resolvedSpotifyUrl } from './listenAlong';

// Material 3's disabled container: onSurface (from the deepRose dark seed) at 12%.
const DISABLED_BG = withAlpha('#EDE0E0', 0.12);
const EMPTY_LINK: SpotifyLinkState = { isLinked: false, spotifyUserId: null, displayName: null };

export function showListenAlong(status: MusicStatus) {
  return showDialog<void>((close) => <ListenAlongPopup status={status} close={() => close(null)} />);
}

function needsResolve(s: MusicStatus) {
  const needsAlbum = s.albumName === '' || s.albumName === 'No Album';
  return (!hasSpotifyTrack(s) || needsAlbum) && s.trackName !== 'Silent Night';
}

function ListenAlongPopup({ status: initial, close }: { status: MusicStatus; close: () => void }) {
  const auth = useAuth();
  const [status, setStatus] = useState(initial);
  const [resolving, setResolving] = useState(() => needsResolve(initial));
  const isLinked = useSource<SpotifyLinkState>(() => spotifyTokenSource(auth.uid), [auth.uid], EMPTY_LINK).isLinked;

  useEffect(() => {
    if (!needsResolve(initial)) return;
    let alive = true;
    void (async () => {
      let next = await resolveSpotify(initial);
      if (!alive) return;
      if (next.albumName === '' || next.albumName === 'No Album') {
        try {
          const album = await fetchTrackAlbum(next.artistName, next.trackName);
          if (album) next = { ...next, albumName: album };
        } catch (e) {
          Logger.e(`ListenAlong: album lookup failed for ${next.artistName} - ${next.trackName}`, e);
        }
      }
      if (!alive) return;
      setStatus(next);
      setResolving(false);
    })();
    return () => {
      alive = false;
    };
  }, [initial]);

  const hasTrack = hasSpotifyTrack(status);
  const playHere = async () => {
    if (!status.spotifyTrackId) return;
    await playInEverglow(status.spotifyTrackId);
    if (!auth.uid) return;
    try {
      await awardDaily(auth.uid, 'play', playAward);
    } catch (e) {
      Logger.e('Jukebox: play XP award failed', e);
    }
  };

  const art = (shadow: boolean) => (
    <div
      style={{
        width: 200,
        height: 200,
        borderRadius: 20,
        overflow: 'hidden',
        flexShrink: 0,
        boxShadow: shadow ? boxShadow([{ blur: 30, spread: 5, color: withAlpha(AppColors.deepRose, 0.3) }]) : undefined,
      }}
    >
      {status.imageUrl ? (
        <img src={status.imageUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      ) : (
        <div
          style={{
            width: '100%',
            height: '100%',
            background: AppColors.twilight,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name="music_note" variant="filled" size={80} color={AppColors.roseQuartz} />
        </div>
      )}
    </div>
  );

  const center: CSSProperties = { textAlign: 'center', display: 'block' };
  return (
    <div
      style={{
        width: '100%',
        maxWidth: 420,
        maxHeight: '100%',
        background: AppColors.velvet,
        borderRadius: 24,
        border: `1.5px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
        boxSizing: 'border-box',
        padding: 32,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <div className="no-scrollbar" style={{ overflowY: 'auto', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        {hasTrack ? (
          // A ClipRRect wraps the cover and the player, so the cover's glow is clipped away here.
          <div
            style={{
              borderRadius: 20,
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              alignSelf: 'stretch',
            }}
          >
            {art(false)}
            <div style={{ height: 16 }} />
            <iframe
              title="Spotify player"
              src={`https://open.spotify.com/embed/track/${status.spotifyTrackId}?utm_source=generator&theme=0`}
              allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
              loading="lazy"
              style={{ width: '100%', height: 80, border: 0, borderRadius: 12, display: 'block' }}
            />
          </div>
        ) : (
          art(true)
        )}
        {resolving && (
          <>
            <div style={{ height: 12 }} />
            <div style={{ width: 16, height: 16, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <CircularProgress size={14} strokeWidth={2} color={AppColors.blushGold} />
            </div>
          </>
        )}
        <div style={{ height: 24 }} />
        <span style={{ ...AppTypography.cormorantBold, fontSize: 24, ...center }}>{status.trackName}</span>
        <div style={{ height: 8 }} />
        <span style={{ ...AppTypography.outfitWhite, fontSize: 16, color: AppColors.blushGold, ...center }}>
          {status.artistName}
        </span>
        {status.albumName !== '' && status.albumName !== 'No Album' && (
          <>
            <div style={{ height: 4 }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 13, color: withAlpha(AppColors.petalWhite, 0.7), ...center }}>
              {status.albumName}
            </span>
          </>
        )}
        <div style={{ height: 24 }} />
        {hasTrack && (
          <WideButton
            onPressed={isLinked ? () => void playHere() : undefined}
            background={isLinked ? AppColors.deepRose : DISABLED_BG}
            icon={
              <Icon
                name={isLinked ? 'play_circle_fill' : 'link'}
                variant={isLinked ? 'filled' : 'round'}
                size={22}
                color={AppColors.petalWhite}
              />
            }
            label={isLinked ? 'Play in Everglow' : 'Link Spotify to play here'}
            weight={700}
          />
        )}
        {!isLinked && hasTrack && (
          <>
            <div style={{ height: 8 }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.55), ...center }}>
              Connect Spotify in Jukebox to enable in-app playback (Duo ✓)
            </span>
          </>
        )}
        <div style={{ height: 12 }} />
        <WideButton
          onPressed={() => window.open(resolvedSpotifyUrl(status), '_blank', 'noopener,noreferrer')}
          background={AppColors.twilight}
          border={withAlpha(AppColors.blushGold, 0.18)}
          icon={<Icon name="open_in_new" size={20} color={AppColors.petalWhite} />}
          label="Open in Spotify"
          weight={600}
        />
        {status.previewUrl != null && !hasTrack && (
          <>
            <div style={{ height: 8 }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.55) }}>
              30s preview available
            </span>
          </>
        )}
        <div style={{ height: 12 }} />
        <TextButton onPressed={close} color={withAlpha(AppColors.roseQuartz, 0.6)} style={{ fontWeight: 500 }}>
          Close
        </TextButton>
      </div>
    </div>
  );
}

/** ElevatedButton.icon at full width: 20/14 padding, 24 radius, no elevation. */
function WideButton({
  onPressed,
  background,
  border,
  icon,
  label,
  weight,
}: {
  onPressed?: () => void;
  background: string;
  border?: string;
  icon: ReactNode;
  label: string;
  weight: number;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      disabled={!onPressed}
      onClick={onPressed}
      style={{
        alignSelf: 'stretch',
        padding: '14px 20px',
        minHeight: 40,
        background,
        borderRadius: 24,
        boxShadow: border ? `inset 0 0 0 1px ${border}` : undefined,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 8,
        cursor: onPressed ? 'pointer' : 'default',
      }}
    >
      {icon}
      <span
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 14,
          fontWeight: weight,
          letterSpacing: 0.6,
          lineHeight: '18px',
        }}
      >
        {label}
      </span>
    </button>
  );
}
