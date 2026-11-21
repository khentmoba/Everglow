import { useEffect, useState } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { Align, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import {
  fetchLovedTracks,
  fetchOnThisDayMusic,
  LASTFM_USER_CLAIR,
  LASTFM_USER_KHENT,
  type LovedTrack,
  type MusicStatus,
  type OnThisDayMusicData,
} from './jukeboxService';
import { showListenAlong } from './ListenAlongPopup';

function TrackRow({
  title,
  artist,
  imageUrl,
  badge,
  badgeColor,
  onTap,
}: {
  title: string;
  artist: string;
  imageUrl: string;
  badge?: string;
  badgeColor?: string;
  onTap: () => void;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        width: '100%',
        padding: '8px 10px',
        borderRadius: 12,
        background: withAlpha(AppColors.petalWhite, 0.04),
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        textAlign: 'left',
      }}
    >
      <div
        style={{
          width: 40,
          height: 40,
          borderRadius: 10,
          overflow: 'hidden',
          background: AppColors.shimmerBase,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        {imageUrl ? (
          <img src={imageUrl} alt={title} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
        ) : (
          <Icon name="music_note" size={18} color={AppColors.roseQuartz} />
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="ellipsis" style={{ ...AppTypography.outfitBold, fontSize: 13, color: AppColors.petalWhite }}>
          {title}
        </div>
        <div className="ellipsis" style={{ fontSize: 11.5, color: Derived.textMuted }}>
          {artist}
        </div>
      </div>
      {badge && (
        <span
          style={{
            padding: '2px 7px',
            borderRadius: 999,
            background: withAlpha(badgeColor ?? AppColors.roseQuartz, 0.16),
            color: badgeColor ?? AppColors.roseQuartz,
            ...AppTypography.outfitBold,
            fontSize: 10,
            flexShrink: 0,
          }}
        >
          {badge}
        </span>
      )}
      <Icon name="play_circle_outline" size={18} color={Derived.textMuted} />
    </button>
  );
}

export function OnThisDayMusicCard() {
  const [data, setData] = useState<OnThisDayMusicData | null>(null);
  const [loading, setLoading] = useState(true);
  const [mode, setMode] = useState<'today' | 'anniversary'>('today');

  useEffect(() => {
    let alive = true;
    void fetchOnThisDayMusic()
      .then((res) => {
        if (!alive) return;
        setData(res);
        setLoading(false);
        const hasToday = res.khentOnThisDay.length > 0 || res.clairOnThisDay.length > 0;
        const hasAnn = res.khentAnniversary.length > 0 || res.clairAnniversary.length > 0;
        if (!hasToday && hasAnn) setMode('anniversary');
      })
      .catch(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, []);

  if (loading) {
    return (
      <div
        style={{
          height: 132,
          borderRadius: AppRadius.x2,
          background: AppColors.shimmerBase,
          border: `1px solid ${Derived.border}`,
        }}
      />
    );
  }

  const lastYear = new Date();
  lastYear.setFullYear(lastYear.getFullYear() - 1);
  const todayLabel = lastYear.toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' });

  const hasToday = Boolean(data && (data.khentOnThisDay.length > 0 || data.clairOnThisDay.length > 0));
  const hasAnn = Boolean(data && (data.khentAnniversary.length > 0 || data.clairAnniversary.length > 0));

  if (!hasToday && !hasAnn) {
    return (
      <div
        style={{
          padding: AppSpacing.xl,
          borderRadius: AppRadius.x2,
          background: linear([withAlpha(AppColors.velvet, 0.86), withAlpha(AppColors.inkDeep, 0.9)], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
          textAlign: 'center',
        }}
      >
        <Icon name="history" size={26} color={AppColors.blushGold} />
        <div style={{ ...AppTypography.outfitBold, fontSize: 11, letterSpacing: '1.3px', color: AppColors.blushGold, marginTop: 8 }}>
          ON THIS DAY IN YOUR MUSIC
        </div>
        <div style={{ fontSize: 12.5, color: Derived.textMedium, marginTop: 6, lineHeight: 1.45 }}>
          No echo from a year ago today yet — your music time capsule will bloom as your listening history grows.
        </div>
      </div>
    );
  }

  const list: Array<{ track: MusicStatus; who: 'Khent' | 'Clair'; color: string }> =
    mode === 'today'
      ? [
          ...(data?.khentOnThisDay ?? []).map((track) => ({ track, who: 'Khent' as const, color: AppColors.auroraTeal })),
          ...(data?.clairOnThisDay ?? []).map((track) => ({ track, who: 'Clair' as const, color: AppColors.cinemaPink })),
        ]
      : [
          ...(data?.khentAnniversary ?? []).map((track) => ({ track, who: 'Khent' as const, color: AppColors.auroraTeal })),
          ...(data?.clairAnniversary ?? []).map((track) => ({ track, who: 'Clair' as const, color: AppColors.cinemaPink })),
        ];

  return (
    <div
      style={{
        padding: AppSpacing.xl,
        borderRadius: AppRadius.x2,
        background: linear([withAlpha(AppColors.velvet, 0.94), withAlpha(AppColors.inkDeep, 0.96)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.22)}`,
        display: 'flex',
        flexDirection: 'column',
        gap: 12,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 10,
              background: withAlpha(AppColors.blushGold, 0.16),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="history" size={18} color={AppColors.blushGold} />
          </div>
          <div>
            <div style={{ ...AppTypography.outfitHeading, fontSize: 14.5, color: AppColors.petalWhite }}>
              On This Day in Your Music
            </div>
            <div style={{ fontSize: 11.5, color: Derived.textMuted }}>
              {mode === 'today' ? todayLabel : 'Feb 14 · Anniversary Soundtrack'}
            </div>
          </div>
        </div>
        {hasToday && hasAnn && (
          <div style={{ display: 'flex', gap: 6 }}>
            {(['today', 'anniversary'] as const).map((m) => (
              <button
                key={m}
                type="button"
                className="bare-button"
                onClick={() => setMode(m)}
                style={{
                  padding: '5px 10px',
                  borderRadius: 999,
                  background: mode === m ? withAlpha(AppColors.blushGold, 0.22) : withAlpha(AppColors.petalWhite, 0.06),
                  border: `1px solid ${mode === m ? AppColors.blushGold : Derived.border}`,
                  color: mode === m ? AppColors.petalWhite : Derived.textMuted,
                  ...AppTypography.outfitBold,
                  fontSize: 11,
                }}
              >
                {m === 'today' ? '1 Year Ago' : 'Feb 14'}
              </button>
            ))}
          </div>
        )}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {list.slice(0, 6).map((item, idx) => (
          <TrackRow
            key={`${item.who}-${item.track.trackName}-${idx}`}
            title={item.track.trackName}
            artist={item.track.artistName}
            imageUrl={item.track.imageUrl ?? ''}
            badge={item.who}
            badgeColor={item.color}
            onTap={() => void showListenAlong(item.track)}
          />
        ))}
      </div>
    </div>
  );
}

export function LovedTracksCard() {
  const [khentLoved, setKhentLoved] = useState<LovedTrack[]>([]);
  const [clairLoved, setClairLoved] = useState<LovedTrack[]>([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState<'khent' | 'clair'>('clair');

  useEffect(() => {
    let alive = true;
    void Promise.all([fetchLovedTracks(LASTFM_USER_KHENT, 10), fetchLovedTracks(LASTFM_USER_CLAIR, 10)])
      .then(([k, c]) => {
        if (!alive) return;
        setKhentLoved(k);
        setClairLoved(c);
        if (c.length === 0 && k.length > 0) setSelected('khent');
        setLoading(false);
      })
      .catch(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, []);

  if (loading || (khentLoved.length === 0 && clairLoved.length === 0)) return null;

  const activeList = selected === 'khent' ? khentLoved : clairLoved;
  const activeName = selected === 'khent' ? 'Khent' : 'Clair';
  const activeUser = selected === 'khent' ? LASTFM_USER_KHENT : LASTFM_USER_CLAIR;
  const activeColor = selected === 'khent' ? AppColors.auroraTeal : AppColors.cinemaPink;

  return (
    <div
      style={{
        padding: AppSpacing.xl,
        borderRadius: AppRadius.x2,
        background: linear([withAlpha(AppColors.velvet, 0.92), withAlpha(AppColors.inkDeep, 0.96)], {
          begin: Align.topLeft,
          end: Align.bottomRight,
        }),
        border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.2)}`,
        display: 'flex',
        flexDirection: 'column',
        gap: 12,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 10,
              background: withAlpha(AppColors.deepRose, 0.2),
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="favorite" size={18} color={AppColors.roseQuartz} />
          </div>
          <div>
            <div style={{ ...AppTypography.outfitHeading, fontSize: 14.5, color: AppColors.petalWhite }}>
              Loved Tracks
            </div>
            <div style={{ fontSize: 11.5, color: Derived.textMuted }}>Songs you both hearted on Last.fm</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['clair', 'khent'] as const).map((who) => {
            const active = selected === who;
            const color = who === 'khent' ? AppColors.auroraTeal : AppColors.cinemaPink;
            return (
              <button
                key={who}
                type="button"
                className="bare-button"
                onClick={() => setSelected(who)}
                style={{
                  padding: '5px 11px',
                  borderRadius: 999,
                  background: active ? withAlpha(color, 0.2) : withAlpha(AppColors.petalWhite, 0.06),
                  border: `1px solid ${active ? color : Derived.border}`,
                  color: active ? AppColors.petalWhite : Derived.textMuted,
                  ...AppTypography.outfitBold,
                  fontSize: 11,
                }}
              >
                {who === 'khent' ? `Khent (${khentLoved.length})` : `Clair (${clairLoved.length})`}
              </button>
            );
          })}
        </div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {activeList.slice(0, 6).map((t, idx) => (
          <TrackRow
            key={`${activeName}-${t.name}-${idx}`}
            title={t.name}
            artist={t.artist}
            imageUrl={t.imageUrl}
            badge="Loved"
            badgeColor={activeColor}
            onTap={() =>
              void showListenAlong({
                username: activeUser,
                trackName: t.name,
                artistName: t.artist,
                albumName: '',
                imageUrl: t.imageUrl || null,
                isPlaying: false,
                spotifyUrl: '',
                timestamp: t.lovedAt ?? null,
              })
            }
          />
        ))}
      </div>
    </div>
  );
}
