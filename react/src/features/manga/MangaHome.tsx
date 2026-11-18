// Port of lib/features/manga/presentation/screens/katana_home_screen.dart
// (the embedded home tab): type chips, latest updates, Hot Manga, Genres.
import type { ReactNode } from 'react';
import { withAlpha } from '../../core/theme/colors';
import { lineHeight, Align, linear } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { KatanaCard, KatanaCompactCard, KatanaCoverImage, KatanaItemCard, KatanaPagination, KatanaSectionHeader } from './MangaUi';
import type { KatanaBookmark, KatanaGenre, KatanaHomeData, KatanaManga } from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';

export type MangaType = 'all' | 'manga' | 'manhwa' | 'manhua';

const typeLabel = (t: MangaType) => (t === 'manga' ? 'Manga' : t === 'manhwa' ? 'Manhwa' : t === 'manhua' ? 'Manhua' : 'All Manga');
const typeEyebrow = (t: MangaType) => (t === 'manga' ? 'Japanese' : t === 'manhwa' ? 'Korean' : t === 'manhua' ? 'Chinese' : '');

function TypeChip({ label, icon, selected, onClick }: { label: string; icon: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        flexShrink: 0,
        padding: '8px 15px',
        borderRadius: 99,
        background: selected
          ? linear([KatanaColors.accent, KatanaColors.accentDark], { begin: Align.topLeft, end: Align.bottomRight })
          : KatanaColors.surfaceAlt,
        border: `1px solid ${selected ? KatanaColors.accentSoft : KatanaColors.border}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Icon name={icon} size={15} color={selected ? '#FFFFFF' : KatanaColors.accentSoft} />
      <div style={{ width: 6 }} />
      <span
        style={{
          fontFamily: Fonts.body,
          fontWeight: 600,
          fontSize: 12.5,
          lineHeight: lineHeight(12.5),
          color: selected ? '#FFFFFF' : KatanaColors.text,
          whiteSpace: 'nowrap',
        }}
      >
        {label}
      </span>
    </button>
  );
}

function SmallCard({ children }: { children: ReactNode }) {
  return (
    <KatanaCard padding={20}>
      <div style={KatanaType.small}>{children}</div>
    </KatanaCard>
  );
}

function CurrentlyReadingShelf({
  items,
  onSelectManga,
  onViewAll,
}: {
  items: KatanaBookmark[];
  onSelectManga: (slug: string) => void;
  onViewAll: () => void;
}) {
  if (items.length === 0) return null;
  return (
    <div style={{ marginBottom: 16 }}>
      <KatanaSectionHeader
        title="Currently Reading"
        badge="READING NOOK"
        trailing={
          <button
            type="button"
            className="bare-button"
            onClick={onViewAll}
            style={{
              padding: '4px 10px',
              borderRadius: 99,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.borderStrong}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 2,
            }}
          >
            <span style={KatanaType.accent}>View all</span>
            <Icon name="chevron_right" size={16} color={KatanaColors.accent} />
          </button>
        }
      />
      <div style={{ height: 10 }} />
      <div className="no-scrollbar" style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingBottom: 4 }}>
        {items.slice(0, 10).map((bm) => (
          <button
            key={bm.slug}
            type="button"
            className="bare-button"
            onClick={() => onSelectManga(bm.slug)}
            style={{
              width: 112,
              flexShrink: 0,
              textAlign: 'left',
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            <div
              style={{
                position: 'relative',
                width: 112,
                height: 158,
                borderRadius: 8,
                overflow: 'hidden',
                border: `1px solid ${withAlpha(KatanaColors.accent, 0.35)}`,
                background: KatanaColors.surfaceAlt,
              }}
            >
              <KatanaCoverImage url={bm.coverUrl} iconSize={24} />
              {bm.lastReadChapterTitle && (
                <div
                  className="ellipsis"
                  style={{
                    position: 'absolute',
                    left: 6,
                    right: 6,
                    bottom: 6,
                    padding: '3px 7px',
                    borderRadius: 6,
                    background: 'rgba(10, 10, 18, 0.85)',
                    border: `1px solid ${withAlpha(KatanaColors.accent, 0.4)}`,
                    fontFamily: Fonts.body,
                    fontSize: 10,
                    fontWeight: 700,
                    color: KatanaColors.accentSoft,
                  }}
                >
                  {bm.lastReadChapterTitle}
                </div>
              )}
            </div>
            <div style={{ height: 6 }} />
            <div className="clamp-2" style={{ fontFamily: Fonts.body, fontSize: 12, fontWeight: 600, color: KatanaColors.text, lineHeight: 1.25 }}>
              {bm.title || bm.slug.replace(/-/g, ' ')}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}

export function MangaHome({
  width,
  data,
  currentlyReading = [],
  type,
  typeItems,
  typeLoading,
  typePage,
  typeHasNext,
  onSelectType,
  onTypePage,
  onSelectManga,
  onSelectGenre,
  onOpenChapter,
  onViewAllReading,
}: {
  width: number;
  data: KatanaHomeData;
  currentlyReading?: KatanaBookmark[];
  type: MangaType;
  typeItems: KatanaManga[];
  typeLoading: boolean;
  typePage: number;
  typeHasNext: boolean;
  onSelectType: (t: MangaType) => void;
  onTypePage: (page: number) => void;
  onSelectManga: (slug: string) => void;
  onSelectGenre: (g: KatanaGenre) => void;
  onOpenChapter: (manga: KatanaManga, chapterId: string) => void;
  onViewAllReading?: () => void;
}) {
  const desktop = width >= 960;
  const compact = width < 720;
  const card = (m: KatanaManga) => (
    <KatanaItemCard
      manga={m}
      compact={compact}
      onSelectManga={onSelectManga}
      onSelectGenre={onSelectGenre}
      onOpenChapter={onOpenChapter}
    />
  );

  const typeChips = (
    <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex' }}>
      {(['all', 'manga', 'manhwa', 'manhua'] as const).map((t) => (
        <div key={t} style={{ display: 'flex', flexShrink: 0 }}>
          <TypeChip
            label={t === 'all' ? 'All' : t[0].toUpperCase() + t.slice(1)}
            icon={t === 'all' ? 'all_inclusive' : 'menu_book'}
            selected={type === t}
            onClick={() => onSelectType(t)}
          />
          <div style={{ width: 8 }} />
        </div>
      ))}
    </div>
  );

  const typeHeader = (
    <>
      <KatanaSectionHeader title={typeLabel(type)} trailing={<span style={KatanaType.small}>{typeEyebrow(type)}</span>} />
      <div style={{ height: 12 }} />
      {typeLoading && typeItems.length === 0 ? (
        <div style={{ padding: '48px 0', display: 'grid', placeItems: 'center' }}>
          <div className="spin" style={{ width: 36, height: 36, borderRadius: '50%', border: `4px solid ${KatanaColors.accent}`, borderRightColor: 'transparent', boxSizing: 'border-box' }} />
        </div>
      ) : typeItems.length === 0 ? (
        <SmallCard>No {typeLabel(type)} titles yet.</SmallCard>
      ) : null}
    </>
  );

  const hotCard =
    data.hot.length > 0 ? (
      <KatanaCard padding={14}>
        <KatanaSectionHeader title="Hot Manga" trailing={<Icon name="local_fire_department" size={20} color={KatanaColors.orange} />} />
        <div style={{ height: 10 }} />
        <div className="no-scrollbar" style={{ height: 226, overflowX: 'auto', overflowY: 'hidden', display: 'flex', alignItems: 'flex-start' }}>
          {data.hot.map((m, i) => (
            <div key={m.slug} style={{ display: 'flex', flexShrink: 0 }}>
              {i > 0 && <div style={{ width: 10 }} />}
              <KatanaCompactCard manga={m} width={96} onSelect={() => onSelectManga(m.slug)} onOpenChapter={onOpenChapter} />
            </div>
          ))}
        </div>
      </KatanaCard>
    ) : null;

  const genresCard =
    data.genres.length > 0 ? (
      <KatanaCard padding={14}>
        <KatanaSectionHeader title="Genres" />
        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7 }}>
          {data.genres.map((g) => (
            <button
              key={g.slug}
              type="button"
              className="bare-button"
              onClick={() => onSelectGenre(g)}
              style={{
                padding: '5px 10px',
                borderRadius: 4,
                background: KatanaColors.surfaceAlt,
                border: `1px solid ${KatanaColors.border}`,
                lineHeight: lineHeight(12),
                whiteSpace: 'nowrap',
              }}
            >
              <span style={{ fontFamily: Fonts.body, fontWeight: 600, fontSize: 12, color: KatanaColors.text, lineHeight: lineHeight(12) }}>
                {g.name}
              </span>
              {g.count > 0 && <span style={{ ...KatanaType.small, fontSize: 10.5, lineHeight: '1px' }}> ({g.count})</span>}
            </button>
          ))}
        </div>
      </KatanaCard>
    ) : null;

  if (!desktop) {
    const items = type === 'all' ? data.latest : typeItems;
    return (
      <div>
        <div style={{ padding: '16px 16px 0' }}>
          <CurrentlyReadingShelf items={currentlyReading} onSelectManga={onSelectManga} onViewAll={() => onViewAllReading?.()} />
          {typeChips}
          <div style={{ height: 14 }} />
          {type === 'all' ? (
            <>
              <KatanaSectionHeader title="Latest Updates" />
              <div style={{ height: 12 }} />
              {items.length === 0 && <SmallCard>Nothing updated yet.</SmallCard>}
            </>
          ) : (
            typeHeader
          )}
        </div>
        <div style={{ padding: '0 16px' }}>
          {items.map((m) => (
            <div key={m.slug} style={{ paddingBottom: 10 }}>
              {card(m)}
            </div>
          ))}
        </div>
        {type !== 'all' && items.length > 0 && (
          <div style={{ padding: '14px 16px 0' }}>
            <KatanaPagination page={typePage} hasPrev={typePage > 1} hasNext={typeHasNext} onPageChange={onTypePage} />
          </div>
        )}
        {type === 'all' && hotCard && <div style={{ padding: '20px 16px 0' }}>{hotCard}</div>}
        {genresCard ? <div style={{ padding: '20px 16px 60px' }}>{genresCard}</div> : <div style={{ height: 60 }} />}
      </div>
    );
  }

  const center = (child: ReactNode) => <div style={{ maxWidth: 1240, margin: '0 auto' }}>{child}</div>;
  return (
    <div style={{ padding: '16px 16px 60px' }}>
      {center(<CurrentlyReadingShelf items={currentlyReading} onSelectManga={onSelectManga} onViewAll={() => onViewAllReading?.()} />)}
      {center(typeChips)}
      <div style={{ height: 14 }} />
      {type === 'all' && data.hotUpdates.length > 0 && (
        <>
          {center(
            <KatanaCard padding={14}>
              <KatanaSectionHeader title="Hot Updates" trailing={<Icon name="whatshot" size={20} color={KatanaColors.orange} />} />
              <div style={{ height: 10 }} />
              <div className="no-scrollbar" style={{ height: 258, overflowX: 'auto', overflowY: 'hidden', display: 'flex', alignItems: 'flex-start' }}>
                {data.hotUpdates.map((m, i) => (
                  <div key={m.slug} style={{ display: 'flex', flexShrink: 0 }}>
                    {i > 0 && <div style={{ width: 10 }} />}
                    <KatanaCompactCard manga={m} width={120} onSelect={() => onSelectManga(m.slug)} onOpenChapter={onOpenChapter} />
                  </div>
                ))}
              </div>
            </KatanaCard>,
          )}
          <div style={{ height: 14 }} />
        </>
      )}
      {center(
        <div style={{ display: 'flex', alignItems: 'flex-start' }}>
          <div style={{ flex: 7, minWidth: 0 }}>
            {type === 'all' ? (
              <>
                <KatanaSectionHeader title="Latest Updates" />
                <div style={{ height: 12 }} />
                {data.latest.length === 0 && <SmallCard>Nothing updated yet.</SmallCard>}
                {data.latest.map((m) => (
                  <div key={m.slug} style={{ paddingBottom: 10 }}>
                    {card(m)}
                  </div>
                ))}
              </>
            ) : (
              <>
                {typeHeader}
                {typeItems.map((m) => (
                  <div key={m.slug} style={{ paddingBottom: 10 }}>
                    {card(m)}
                  </div>
                ))}
                {typeItems.length > 0 && (
                  <>
                    <div style={{ height: 14 }} />
                    <KatanaPagination page={typePage} hasPrev={typePage > 1} hasNext={typeHasNext} onPageChange={onTypePage} />
                  </>
                )}
              </>
            )}
          </div>
          <div style={{ width: 16, flexShrink: 0 }} />
          <div style={{ width: 330, flexShrink: 0 }}>
            {genresCard}
            {type === 'all' && hotCard && (
              <>
                <div style={{ height: 16 }} />
                {hotCard}
              </>
            )}
          </div>
        </div>,
      )}
    </div>
  );
}
