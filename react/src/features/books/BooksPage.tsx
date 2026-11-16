// Port of lib/features/books/presentation/screens/books_screen.dart.
import { Fragment, useEffect, useState, type ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { useBoxSize } from '../../core/system/useBoxSize';
import { EverglowPillNav } from '../../shared/widgets/EverglowPillNav';
import { Icon } from '../../shared/widgets/Icon';
import {
  ScrollEdgeFade,
  ShelfAtmosphericBackdrop,
  ShelfIconButton,
  ShelfSectionHeader,
  StaggeredEntrance,
} from '../../shared/widgets/shelf/Shelf';
import { MediaSectionMenuButton } from '../cinema/NetflixUi';
import { BookCover, BookCoverCard } from './BookCover';
import {
  BOOK_CATEGORIES,
  BookColors,
  bookItemToSearchResult,
  bookReadDisplay,
  isBookRead,
  type BookItem,
  type BookSearchResult,
} from './bookTypes';
import {
  fetchPopularBooks,
  fetchRecentBooks,
  searchBooksCatalog,
  watchBookDownloads,
  watchBookFavorites,
  watchReadList,
} from './booksService';

export { BookCoverCard } from './BookCover';

const cBlack = BookColors.black;

function readBadgeColor(status: string): string {
  if (status === 'read-clair') return AppColors.cinemaPink;
  if (status === 'read-khent') return AppColors.cinemaBlue;
  return AppColors.cinemaGreen;
}

/** A horizontal ListView.separated: fixed height, side padding, gaps. */
function Rail({ height, gap, padding, children }: { height: number; gap: number; padding: string; children: ReactNode[] }) {
  return (
    <ScrollEdgeFade fadeColor={cBlack}>
      <div className="no-scrollbar" style={{ height, display: 'flex', alignItems: 'stretch', overflowX: 'auto', overflowY: 'hidden', padding, boxSizing: 'border-box' }}>
        {children.map((child, i) => (
          <Fragment key={i}>
            {i > 0 && <div style={{ width: gap, flexShrink: 0 }} />}
            {child}
          </Fragment>
        ))}
        <div style={{ width: 20, flexShrink: 0 }} />
      </div>
    </ScrollEdgeFade>
  );
}

function SectionHead(props: { eyebrow: string; title: string; accent: string; onSeeAll: () => void }) {
  return (
    <div style={{ padding: '30px 20px 14px' }}>
      <ShelfSectionHeader {...props} />
    </div>
  );
}

// _buildShimmerHome: still skeleton blocks (phones never animate them).
function ShimmerHome() {
  const block = (h: number, r: number, w?: number) => (
    <div style={{ height: h, width: w ?? '100%', borderRadius: r, background: AppColors.shimmerBase }} />
  );
  return (
    <div style={{ overflow: 'hidden', height: '100%' }}>
      <div style={{ padding: '14px 20px 20px' }}>{block(40, 8, 160)}</div>
      <div style={{ padding: '0 12px' }}>{block(320, 24)}</div>
      <div style={{ padding: '32px 20px 0' }}>{block(280, 16)}</div>
      <div style={{ padding: '32px 20px 14px' }}>{block(36, 8, 200)}</div>
      <div style={{ display: 'flex', gap: 12, padding: '0 20px' }}>
        {Array.from({ length: 6 }, (_, i) => (
          <div key={i} style={{ flexShrink: 0 }}>{block(240, 12, 150)}</div>
        ))}
      </div>
    </div>
  );
}

function Spotlight({ pick, onOpen }: { pick: BookSearchResult; onOpen: () => void }) {
  const [boxRef, box] = useBoxSize<HTMLDivElement>();
    const blurb = pick.description ? pick.description : pick.subjects.slice(0, 3).join(' · ');
    return (
      <div style={{ padding: '22px 20px 0' }}>
        <div
          role="button"
          onClick={onOpen}
          ref={boxRef}
          style={{
            padding: 16,
            borderRadius: 22,
            background: linear(
              [withAlpha(AppColors.warmAmber, 0.16), withAlpha(AppColors.velvet, 0.85), withAlpha(cBlack, 0.9)],
              { begin: Align.topLeft, end: Align.bottomRight, size: box },
            ),
            border: `1px solid ${withAlpha(AppColors.warmAmber, 0.18)}`,
            display: 'flex',
            alignItems: 'center',
            cursor: 'pointer',
          }}
        >
          <BookCover imageUrl={pick.coverUrl} title={pick.title} author={pick.author} width={112} />
          <div style={{ width: 16, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.outfitBold, color: AppColors.warmAmber, fontSize: 10, lineHeight: lineHeight(10), letterSpacing: 1.6 }}>
              TOP PICK THIS WEEK
            </div>
            <div style={{ height: 6 }} />
            <div className="clamp-3" style={{ ...AppTypography.cormorantBlack, fontSize: 22, lineHeight: lineHeight(22, 1.1), color: AppColors.petalWhite }}>
              {pick.title}
            </div>
            {pick.author && (
              <>
                <div style={{ height: 4 }} />
                <div
                  className="ellipsis"
                  style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.85), fontSize: 12.5, lineHeight: lineHeight(12.5) }}
                >
                  {pick.author}
                </div>
              </>
            )}
            {blurb && (
              <>
                <div style={{ height: 8 }} />
                <div className="clamp-2" style={{ ...AppTypography.outfitWhite, color: AppColors.mutedPurple, fontSize: 11.5, lineHeight: lineHeight(11.5, 1.4) }}>
                  {blurb}
                </div>
              </>
            )}
            <div style={{ height: 12 }} />
            <div style={{ display: 'inline-flex', alignItems: 'center', padding: '9px 16px', borderRadius: 20, background: AppColors.petalWhite }}>
              <Icon name="auto_stories" size={16} color={cBlack} />
              <div style={{ width: 6 }} />
              <span style={{ ...AppTypography.outfitBold, color: cBlack, fontSize: 12.5, lineHeight: lineHeight(12.5) }}>Open book</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

export function BooksPage() {
  const { width } = useViewport();
  const { currentUser, isCoupleUser, isCinemaOnlyUser } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const initialQuery = (location.state as { query?: string } | null)?.query ?? '';
  // Navigator.canPop: true only when the app pushed this page.
  const canPop = (window.history.state as { idx?: number } | null)?.idx ? true : false;

  const [tab, setTab] = useState<0 | 1 | 2>(initialQuery ? 1 : 0);
  const [librarySegment, setLibrarySegment] = useState<0 | 1 | 2 | 3>(0);

  const [popular, setPopular] = useState<BookSearchResult[]>([]);
  const [recent, setRecent] = useState<BookSearchResult[]>([]);
  const [loadingHome, setLoadingHome] = useState(true);

  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [searchResults, setSearchResults] = useState<BookSearchResult[]>([]);
  const [searching, setSearching] = useState(false);

  const userName = currentUser ?? '';
  const readlist = useSource(() => watchReadList(userName), [userName], []);
  const favorites = useSource(() => watchBookFavorites(userName), [userName], []);
  const downloads = useSource(() => watchBookDownloads(userName), [userName], []);

  const toReadList = readlist.filter((b) => b.status === 'to-read');
  const readHistoryList = readlist.filter((b) => isBookRead(b.status));

  useEffect(() => {
    let alive = true;
    setLoadingHome(true);
    void Promise.all([
      fetchPopularBooks(12).then((pop) => alive && setPopular(pop)),
      fetchRecentBooks(12).then((rec) => alive && setRecent(rec)),
    ]).finally(() => alive && setLoadingHome(false));
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    const q = searchQuery.trim();
    if (!q) {
      setSearchResults([]);
      return;
    }
    let alive = true;
    setSearching(true);
    const t = window.setTimeout(() => {
      searchBooksCatalog(q).then((res) => {
        if (!alive) return;
        setSearchResults(res.results);
        setSearching(false);
      });
    }, 500);
    return () => {
      alive = false;
      window.clearTimeout(t);
    };
  }, [searchQuery]);

  const openDetails = (r: BookSearchResult) => {
    navigate('/books/detail', { state: { result: r } });
  };

  const openItemDetails = (b: BookItem) => {
    navigate('/books/detail', { state: { result: bookItemToSearchResult(b), saved: b } });
  };

  const spotlight = popular[0] ?? recent[0] ?? null;
  const showSkeleton = loadingHome && popular.length === 0 && recent.length === 0;
  const cols = width >= 1024 ? 7 : width >= 600 ? 5 : 3;
  const libraryList =
    librarySegment === 0 ? toReadList : librarySegment === 1 ? readHistoryList : librarySegment === 2 ? favorites : downloads;

  const header = (
    <div style={{ padding: '14px 20px 0', display: 'flex', alignItems: 'center' }}>
      {isCinemaOnlyUser ? (
        <>
          <MediaSectionMenuButton currentRoute="/books" />
          <div style={{ width: 12, flexShrink: 0 }} />
        </>
      ) : canPop ? (
        <>
          <ShelfIconButton icon="arrow_back_ios_new" label="Back" tooltip="Back" onClick={() => navigate(-1)} />
          <div style={{ width: 12, flexShrink: 0 }} />
        </>
      ) : null}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...AppTypography.cormorantBlack, fontSize: 32, lineHeight: '32px', color: AppColors.petalWhite }}>Books</div>
        <div style={{ height: 4 }} />
        <div style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), color: AppColors.mutedPurple }}>
          Free classics and new finds
        </div>
      </div>
      {isCoupleUser && (
        <ShelfIconButton icon="favorite" label="Open Our Books" tooltip="Our Books" onClick={() => navigate('/our-books')} />
      )}
    </div>
  );

  const homeSearch = (
    <div style={{ padding: '18px 20px 0' }}>
      <button
        type="button"
        className="bare-button"
        aria-label="Search books"
        onClick={() => setTab(1)}
        style={{
          width: '100%',
          height: 50,
          borderRadius: 25,
          background: withAlpha(AppColors.shimmerBase, 0.7),
          border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.12)}`,
          padding: '0 18px',
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <Icon name="search" size={20} color={withAlpha(AppColors.roseQuartz, 0.8)} />
        <div style={{ width: 10, flexShrink: 0 }} />
        <span style={{ ...AppTypography.outfitWhite, fontSize: 14, lineHeight: lineHeight(14), color: AppColors.mutedPurple }}>
          Search titles, authors, subjects
        </span>
      </button>
    </div>
  );

  const feedRail = (eyebrow: string, title: string, accent: string, results: BookSearchResult[], kind: 'popular' | 'recent') =>
    results.length === 0 ? null : (
      <StaggeredEntrance>
        <SectionHead
          eyebrow={eyebrow}
          title={title}
          accent={accent}
          onSeeAll={() => navigate('/books/list', { state: { kind, title, initialResults: results } })}
        />
        <Rail height={262} gap={14} padding="0 0 4px 20px">
          {results.map((r) => (
            <BookCoverCard key={r.workKey || r.title} width={124} result={r} onClick={() => openDetails(r)} />
          ))}
        </Rail>
      </StaggeredEntrance>
    );

  return (
    <div style={{ position: 'relative', height: '100%', background: cBlack, color: AppColors.petalWhite, overflow: 'hidden' }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: AppColors.warmAmber, alignment: [-0.7, -0.85], size: 0.85, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.85, 0.95], size: 0.8, opacity: 0.1 },
        ]}
      />

      {tab === 0 && showSkeleton && (
        <div style={{ position: 'absolute', inset: 0 }}>
          <ShimmerHome />
        </div>
      )}

      {tab === 0 && !showSkeleton && (
        <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden' }}>
          <StaggeredEntrance>{header}</StaggeredEntrance>
          <StaggeredEntrance>{homeSearch}</StaggeredEntrance>
          {spotlight && <StaggeredEntrance><Spotlight pick={spotlight} onOpen={() => openDetails(spotlight)} /></StaggeredEntrance>}
          {readHistoryList.length > 0 && (
            <StaggeredEntrance>
              <SectionHead
                eyebrow="Pick one up again"
                title="Read Before"
                accent={AppColors.roseQuartz}
                onSeeAll={() => {
                  setLibrarySegment(1);
                  setTab(2);
                }}
              />
              <Rail height={246} gap={14} padding="0 0 4px 20px">
                {readHistoryList.slice(0, 12).map((b) => (
                  <BookCoverCard
                    key={b.workKey}
                    width={112}
                    item={b}
                    statusBadge={bookReadDisplay(b.status)}
                    badgeColor={readBadgeColor(b.status)}
                    onClick={() => openItemDetails(b)}
                  />
                ))}
              </Rail>
            </StaggeredEntrance>
          )}
          <StaggeredEntrance>
            <SectionHead eyebrow="Browse" title="Shelves" accent={AppColors.warmAmber} onSeeAll={() => navigate('/books/categories')} />
            <Rail height={44} gap={8} padding="0 0 0 20px">
              {BOOK_CATEGORIES.map((cat) => (
                <button
                  key={cat.query}
                  type="button"
                  className="bare-button"
                  onClick={() => navigate('/books/category', { state: { category: cat } })}
                  style={{
                    flexShrink: 0,
                    padding: '0 16px',
                    borderRadius: 22,
                    background: withAlpha(cat.color, 0.12),
                    border: `1px solid ${withAlpha(cat.color, 0.3)}`,
                    display: 'flex',
                    alignItems: 'center',
                  }}
                >
                  <Icon name={cat.icon} size={17} color={cat.color} />
                  <div style={{ width: 8 }} />
                  <span style={{ ...AppTypography.outfitBold, color: AppColors.petalWhite, fontSize: 12.5, lineHeight: lineHeight(12.5), whiteSpace: 'nowrap' }}>
                    {cat.name}
                  </span>
                </button>
              ))}
            </Rail>
          </StaggeredEntrance>
          {feedRail('Trending this week', 'Most Popular', AppColors.warmAmber, popular, 'popular')}
          {feedRail('Fresh in the catalog', 'Recently Added', AppColors.deepRose, recent, 'recent')}
          <div style={{ height: 100 }} />
        </div>
      )}

      <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', paddingBottom: 100, display: tab === 0 ? 'none' : undefined }}>
        {tab === 1 && (
          <div style={{ padding: '14px 20px 0' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => setTab(0)}
                style={{ width: 38, height: 38, borderRadius: 12, background: 'rgba(255,255,255,0.06)', display: 'grid', placeItems: 'center' }}
              >
                <Icon name="arrow_back_ios_new" size={16} color={BookColors.white} />
              </button>
              <div>
                <div style={{ fontFamily: Fonts.display, fontWeight: 800, fontSize: 26, color: BookColors.white }}>Search</div>
                <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: 2, color: BookColors.muted }}>FIND YOUR NEXT OBSESSION</div>
              </div>
            </div>

            <div
              style={{
                marginTop: 16,
                height: 54,
                borderRadius: 18,
                background: BookColors.card,
                border: `1px solid ${withAlpha(BookColors.rose, 0.15)}`,
                display: 'flex',
                alignItems: 'center',
                padding: '0 14px',
                gap: 10,
              }}
            >
              <Icon name="search" size={22} color={BookColors.deepRose} />
              <input
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Title, author, ISBN..."
                autoFocus
                style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: BookColors.white, fontSize: 15 }}
              />
            </div>

            <div style={{ marginTop: 18 }}>
              {searching ? (
                <div style={{ padding: 48, textAlign: 'center', color: BookColors.muted }}>Searching Open Library &amp; Gutenberg…</div>
              ) : searchResults.length === 0 ? (
                <div style={{ padding: '48px 16px', textAlign: 'center', color: BookColors.muted }}>
                  {searchQuery.trim() ? 'No results found.' : 'Search Open Library, Project Gutenberg, and Internet Archive.'}
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {searchResults.map((r) => (
                    <div
                      key={r.workKey || r.title}
                      onClick={() => openDetails(r)}
                      style={{
                        padding: 12,
                        borderRadius: 14,
                        background: withAlpha(BookColors.card, 0.7),
                        border: `1px solid ${withAlpha(BookColors.rose, 0.1)}`,
                        display: 'flex',
                        gap: 12,
                        cursor: 'pointer',
                      }}
                    >
                      {r.coverUrl && <img src={r.coverUrl} alt={r.title} style={{ width: 56, height: 82, borderRadius: 8, objectFit: 'cover', flexShrink: 0 }} />}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div className="clamp-2" style={{ fontSize: 14.5, fontWeight: 700, color: BookColors.white }}>{r.title}</div>
                        <div style={{ fontSize: 12, color: BookColors.muted, marginTop: 3 }}>
                          {[r.author, r.year, r.sourceLabel].filter(Boolean).join(' · ')}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {tab === 2 && (
          <div style={{ padding: '14px 20px 0' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div>
                <h1 style={{ fontFamily: Fonts.display, fontWeight: 900, fontSize: 28, margin: 0 }}>Library</h1>
                <div style={{ fontSize: 12, color: BookColors.muted }}>Your personal shelves</div>
              </div>
              <span
                style={{
                  padding: '6px 12px',
                  borderRadius: 20,
                  background: withAlpha(BookColors.deepRose, 0.15),
                  border: `1px solid ${withAlpha(BookColors.deepRose, 0.3)}`,
                  color: BookColors.deepRose,
                  fontWeight: 800,
                  fontSize: 14,
                }}
              >
                {libraryList.length}
              </span>
            </div>

            <div className="no-scrollbar" style={{ display: 'flex', gap: 8, overflowX: 'auto', margin: '14px 0' }}>
              {([
                ['To Read', 'bookmark', toReadList.length],
                ['Read', 'check', readHistoryList.length],
                ['Loved', 'favorite', favorites.length],
                ['Files', 'download', downloads.length],
              ] as const).map(([label, icon, cnt], idx) => {
                const active = librarySegment === idx;
                return (
                  <button
                    key={label}
                    type="button"
                    className="bare-button"
                    onClick={() => setLibrarySegment(idx as 0 | 1 | 2 | 3)}
                    style={{
                      height: 40,
                      padding: '0 14px',
                      borderRadius: 20,
                      background: active ? withAlpha(BookColors.deepRose, 0.2) : withAlpha(BookColors.card, 0.6),
                      border: `1px solid ${active ? withAlpha(BookColors.deepRose, 0.5) : withAlpha(BookColors.rose, 0.1)}`,
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 6,
                      flexShrink: 0,
                    }}
                  >
                    <Icon name={icon} size={15} color={active ? BookColors.deepRose : BookColors.muted} />
                    <span style={{ fontSize: 12, fontWeight: 700, color: active ? BookColors.white : BookColors.muted }}>{label}</span>
                    <span style={{ fontSize: 12, fontWeight: 700, color: active ? BookColors.deepRose : BookColors.muted }}>{cnt}</span>
                  </button>
                );
              })}
            </div>

            {libraryList.length === 0 ? (
              <div style={{ padding: '56px 20px', textAlign: 'center', color: BookColors.muted }}>
                Nothing here yet. Open any book and save it to your shelf.
              </div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: '18px 14px' }}>
                {libraryList.map((b) => (
                  <BookCoverCard
                    key={b.workKey}
                    width={Math.floor((width - 40 - (cols - 1) * 14) / cols)}
                    item={b}
                    statusBadge={librarySegment === 1 ? bookReadDisplay(b.status) : undefined}
                    onClick={() => openItemDetails(b)}
                  />
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      <EverglowPillNav
        currentIndex={tab}
        onTap={(i) => setTab(i as 0 | 1 | 2)}
        items={[
          { icon: 'home', activeIcon: 'home', label: 'Home' },
          { icon: 'search', activeIcon: 'search', label: 'Search', iconVariant: 'round' },
          { icon: 'library_books', activeIcon: 'library_books', label: 'Library' },
        ]}
      />
    </div>
  );
}
