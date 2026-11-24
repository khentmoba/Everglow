// Port of lib/features/watch_party/presentation/widgets/cinema_watch_together_tab.dart
// (+ cinema_watch_together_widgets.dart).
import { useAuth } from '../../core/services/auth';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { cinemaTopInset } from '../cinema/CinemaLibraryTab';
import { NetflixColors, type MediaItem } from '../cinema/cinemaTypes';
import { NetflixPosterCard } from '../cinema/NetflixUi';
import { StartWatchPartyButton, startWatchParty } from './StartWatchParty';
import { TemporaryChatPanel } from './TemporaryChatPanel';
import { buildCoupleRoomId } from './temporaryChatService';
import { SheetFrame, showWatchPartyMediaPicker, type WatchPartyPickerCategory } from './WatchPartyPickerSheets';
import { useOpenWatchPartyRoom, WatchPartyLobby } from './WatchPartyPage';

export function CinemaWatchTogetherTab({
  isDesktop,
  width,
  watchlist,
  onMediaTap,
  onSwitchTab,
}: {
  isDesktop: boolean;
  width: number;
  watchlist: MediaItem[];
  onMediaTap: (m: MediaItem) => void;
  onSwitchTab: (tab: number) => void;
}) {
  const auth = useAuth();
  const openRoom = useOpenWatchPartyRoom();
  const isCouple = auth.isCoupleUser;
  const myUid = auth.uid;
  const partnerUid = auth.partnerUid;
  const h = isDesktop ? 48 : 16;
  const gridWidth = width - h * 2;
  const cols = Math.max(1, Math.ceil(gridWidth / (170 + 14)));

  return (
    <div>
      <div style={{ padding: `${cinemaTopInset(width)}px ${h}px 4px`, display: 'flex', alignItems: 'flex-end' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.outfitHeading,
              fontSize: isDesktop ? 26 : 22,
              lineHeight: lineHeight(isDesktop ? 26 : 22),
              color: NetflixColors.textPrimary,
            }}
          >
            Together
          </div>
          <div style={{ height: 4 }} />
          <div
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 13,
              lineHeight: lineHeight(13),
              color: NetflixColors.textMuted,
              fontWeight: 500,
            }}
          >
            {isCouple ? 'Start a movie night or resume what you were watching.' : 'Available for the couple profile.'}
          </div>
        </div>
        {!isCouple && (
          <div
            style={{
              padding: '6px 12px',
              background: withAlpha(NetflixColors.accent, 0.14),
              borderRadius: 20,
              border: `1px solid ${withAlpha(NetflixColors.accent, 0.5)}`,
              ...AppTypography.outfitHeading,
              fontSize: 9.5,
              lineHeight: lineHeight(9.5),
              letterSpacing: 1.2,
              color: NetflixColors.textPrimary,
            }}
          >
            COUPLE ONLY
          </div>
        )}
      </div>
      <div style={{ padding: `18px ${h}px 0` }}>
        <WatchPartyLobby embedded />
      </div>
      {isCouple && (
        <div style={{ padding: `18px ${h}px 0` }}>
          <ChooseTitleButton openRoom={openRoom} />
        </div>
      )}
      {isCouple && myUid && partnerUid && (
        <div style={{ padding: `18px ${h}px 0` }}>
          <TemporaryChatPanel roomId={buildCoupleRoomId(myUid, partnerUid)} myUid={myUid} partnerUid={partnerUid} />
        </div>
      )}
      {isCouple && (
        <>
          <div style={{ padding: `22px ${h}px 0`, display: 'flex', alignItems: 'center' }}>
            <span
              style={{
                ...AppTypography.outfitHeading,
                fontSize: isDesktop ? 18 : 16,
                lineHeight: lineHeight(isDesktop ? 18 : 16),
                color: NetflixColors.textPrimary,
              }}
            >
              Pick a title
            </span>
            <div style={{ width: 10 }} />
            <span
              style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), color: NetflixColors.textMuted }}
            >
              {watchlist.length} saved
            </span>
          </div>
          {watchlist.length === 0 ? (
            <div style={{ padding: `18px ${h}px 24px` }}>
              <EmptyWatchlist onOpenMyList={() => onSwitchTab(3)} />
            </div>
          ) : (
            <div
              style={{
                padding: `14px ${h}px 20px`,
                display: 'grid',
                gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
                gap: 14,
              }}
            >
              {watchlist.map((item) => (
                <div key={item.id || `${item.mediaType}:${item.tmdbId}`} style={{ position: 'relative', aspectRatio: '2 / 3' }}>
                  <NetflixPosterCard item={item} compact onTap={() => onMediaTap(item)} />
                  <div style={{ position: 'absolute', right: 6, bottom: 6 }}>
                    <StartWatchPartyButton
                      openRoom={openRoom}
                      media={{
                        tmdbId: item.tmdbId,
                        malId: item.isAnime ? item.tmdbId : undefined,
                        mediaType: item.mediaType,
                        isAnime: item.isAnime,
                        season: item.currentSeason,
                        episode: item.currentEpisode,
                        title: item.title,
                        posterPath: item.posterPath,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

function ChooseTitleButton({ openRoom }: { openRoom: (roomId: string) => void }) {
  const open = async () => {
    const category = await showModalBottomSheet<WatchPartyPickerCategory>((close) => (
      <SheetFrame>
        <ChooseSourceSheet onPick={(c) => close(c)} />
      </SheetFrame>
    ));
    if (!category) return;
    const media = await showWatchPartyMediaPicker({ currentTitle: '', initialCategory: category });
    if (media) void startWatchParty(media, openRoom);
  };
  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <button
        type="button"
        className="bare-button"
        aria-label="Choose a title to watch together"
        onClick={() => void open()}
        style={{
          padding: '14px 26px',
          // One accent inside Cinema: the rose gradient belonged to the couple
          // pages and read as a second brand on a red screen.
          background: NetflixColors.accent,
          borderRadius: 24,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <Icon name="search" size={20} color={AppColors.petalWhite} />
        <div style={{ width: 10 }} />
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 14,
            lineHeight: lineHeight(14),
            color: AppColors.petalWhite,
            letterSpacing: 0.3,
          }}
        >
          Choose a title
        </span>
      </button>
    </div>
  );
}

function ChooseSourceSheet({ onPick }: { onPick: (c: WatchPartyPickerCategory) => void }) {
  return (
    <div
      style={{
        margin: 16,
        padding: '18px 20px 20px',
        background: NetflixColors.surfaceElevated,
        borderRadius: 20,
        border: `1px solid ${NetflixColors.hairline}`,
      }}
    >
      <div style={{ ...AppTypography.outfitHeading, fontSize: 17, lineHeight: lineHeight(17), color: NetflixColors.textPrimary }}>
        What are we watching?
      </div>
      <div style={{ height: 16 }} />
      <SourceOption icon="movie_filter" title="Movies & TV" subtitle="Search films and series" onTap={() => onPick('cinema')} />
      <div style={{ height: 10 }} />
      <SourceOption icon="animation" title="Anime" subtitle="Search anime and episodes" onTap={() => onPick('anime')} />
    </div>
  );
}

function SourceOption({ icon, title, subtitle, onTap }: { icon: string; title: string; subtitle: string; onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={title}
      onClick={onTap}
      style={{
        width: '100%',
        padding: '14px 16px',
        boxSizing: 'border-box',
        background: NetflixColors.surface,
        borderRadius: 14,
        border: `1px solid ${NetflixColors.hairline}`,
        display: 'flex',
        alignItems: 'center',
        textAlign: 'left',
      }}
    >
      <Icon name={icon} size={24} color={NetflixColors.accent} />
      <div style={{ width: 14 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{ ...AppTypography.outfitBold, fontSize: 14.5, lineHeight: lineHeight(14.5), color: NetflixColors.textPrimary }}
        >
          {title}
        </div>
        <div style={{ height: 2 }} />
        <div style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), color: NetflixColors.textMuted }}>
          {subtitle}
        </div>
      </div>
      <Icon name="chevron_right" size={22} color={NetflixColors.textMuted} />
    </button>
  );
}

function EmptyWatchlist({ onOpenMyList }: { onOpenMyList: () => void }) {
  return (
    <div
      style={{
        padding: 22,
        background: NetflixColors.surface,
        borderRadius: 14,
        border: `1px solid ${NetflixColors.hairline}`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-start',
      }}
    >
      <Icon name="movie_filter" size={28} color={NetflixColors.gold} />
      <div style={{ height: 10 }} />
      <div style={{ ...AppTypography.outfitHeading, fontSize: 15, lineHeight: lineHeight(15), color: NetflixColors.textPrimary }}>
        Your list is empty
      </div>
      <div style={{ height: 4 }} />
      <div
        style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12, 1.4), color: NetflixColors.textMuted }}
      >
        Add movies in Cinema or browse the My List tab, then start a party here.
      </div>
      <div style={{ height: 12 }} />
      <button
        type="button"
        className="bare-button"
        onClick={onOpenMyList}
        style={{
          padding: '9px 14px',
          background: withAlpha(NetflixColors.accent, 0.16),
          borderRadius: 20,
          border: `1px solid ${withAlpha(NetflixColors.accent, 0.55)}`,
          ...AppTypography.outfitBold,
          fontSize: 12,
          lineHeight: lineHeight(12),
          color: NetflixColors.textPrimary,
        }}
      >
        Open My List
      </button>
    </div>
  );
}
