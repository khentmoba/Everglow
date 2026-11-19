// Port of lib/features/books/presentation/screens/books_screen.dart.
import { Fragment, useEffect, useRef, useState, type ReactNode } from 'react';
import { useLocation, useNavigate, useSearchParams } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { Prefs } from '../../core/system/prefs';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { useBoxSize } from '../../core/system/useBoxSize';
import { useDialogFocus } from '../../shared/utils/focusTrap';
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
  searchResultToBookItem,
  type BookItem,
  type BookSearchResult,
} from './bookTypes';
import {
  catalogFailureAt,
  fetchBooksBySubject,
  saveCoupleGoal,
  fetchPopularBooks,
  fetchRecentBooks,
  searchBooksCatalog,
  watchAllReaderProgress,
  watchBookDownloads,
  watchCoupleGoal,
  watchBookFavorites,
  watchReadList,
} from './booksService';
import { listProgress, progressToBookItem, type ReaderProgress } from './readerPrefs';

export { BookCoverCard } from './BookCover';

const cBlack = BookColors.black;

/** What Clair was looking at before she opened a book — remembered across routes. */
const booksView = { tab: 0 as 0 | 1 | 2, segment: 0 as 0 | 1 | 2 | 3, scroll: 0 };

const LANG_CODES: Record<string, string> = {
  English: 'eng', Spanish: 'spa', French: 'fre', German: 'ger', Chinese: 'chi', Japanese: 'jpn',
};

function readBadgeColor(status: string): string {
  if (status === 'read-clair') return AppColors.cinemaPink;
  if (status === 'read-khent') return AppColors.cinemaBlue;
  return AppColors.cinemaGreen;
}

/** A horizontal ListView.separated: fixed height, side padding, gaps. */
function Rail({ height, gap, padding, children }: { height: number; gap: number; padding: string; children: ReactNode[] }) {
  return (
    <ScrollEdgeFade fadeColor={cBlack}>
      <div className="no-scrollbar" style={{ height, display: 'flex', alignItems: 'stretch', overflowX: 'auto', overflowY: 'hidden', padding, boxSizing: 'border-box', scrollSnapType: 'x mandatory' }}>
        {children.map((child, i) => (
          <Fragment key={i}>
            {i > 0 && <div style={{ width: gap, flexShrink: 0 }} />}
            <div style={{ scrollSnapAlign: 'start', display: 'flex' }}>{child}</div>
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
  const { width } = useViewport();
  const big = width >= 700;
  const block = (h: number, r: number, w?: number) => (
    <div className="skeleton-pulse" style={{ height: h, width: w ?? '100%', borderRadius: r, background: AppColors.shimmerBase }} />
  );
  return (
    <div style={{ overflow: 'hidden', height: '100%' }}>
      <div style={{ padding: '14px 20px 20px' }}>{block(40, 8, 160)}</div>
      <div style={{ padding: '0 12px' }}>{block(320, 24)}</div>
      <div style={{ padding: '32px 20px 0' }}>{block(280, 16)}</div>
      <div style={{ padding: '32px 20px 14px' }}>{block(36, 8, 200)}</div>
      <div style={{ display: 'flex', gap: 12, padding: '0 20px' }}>
        {Array.from({ length: 6 }, (_, i) => (
          <div key={i} style={{ flexShrink: 0 }}>{block(big ? 310 : 262, 12, big ? 150 : 124)}</div>
        ))}
      </div>
    </div>
  );
}

function Spotlight({ pick, onOpen, onDetails }: { pick: BookSearchResult; onOpen: () => void; onDetails: () => void }) {
  const [boxRef, box] = useBoxSize<HTMLButtonElement>();
  const { width } = useViewport();
  const big = width >= 700;
  const blurb = pick.description ? pick.description : pick.subjects.slice(0, 3).join(' · ');
  const cta = (
    <div style={{ display: 'inline-flex', alignItems: 'center', padding: '9px 16px', borderRadius: 20, background: AppColors.petalWhite }}>
      <Icon name="auto_stories" size={16} color={cBlack} />
      <div style={{ width: 6 }} />
      <span style={{ ...AppTypography.outfitBold, color: cBlack, fontSize: 12.5, lineHeight: lineHeight(12.5) }}>Open book</span>
    </div>
  );
  return (
    <div style={{ padding: '22px 20px 0' }}>
      <div style={{ position: 'relative' }}>
        <button
          type="button"
          className="bare-button"
          aria-label={pick.author ? `Open ${pick.title} by ${pick.author}` : `Open ${pick.title}`}
          onClick={onOpen}
          ref={boxRef}
          style={{
            width: '100%', textAlign: 'left', padding: 16, borderRadius: 22,
            background: linear(
              [withAlpha(AppColors.warmAmber, 0.16), withAlpha(AppColors.velvet, 0.85), withAlpha(cBlack, 0.9)],
              { begin: Align.topLeft, end: Align.bottomRight, size: box },
            ),
            border: `1px solid ${withAlpha(AppColors.warmAmber, 0.18)}`,
            display: 'flex', alignItems: 'center', cursor: 'pointer',
          }}
        >
          <BookCover imageUrl={pick.coverUrl} title={pick.title} author={pick.author} width={big ? 168 : 112} eager />
          <div style={{ width: 16, flexShrink: 0 }} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.outfitBold, color: AppColors.warmAmber, fontSize: 10, lineHeight: lineHeight(10), letterSpacing: 1.6 }}>POPULAR PICK</div>
            <div style={{ height: 6 }} />
            <div className="clamp-3" style={{ ...AppTypography.cormorantBlack, fontSize: big ? 32 : 22, lineHeight: lineHeight(big ? 32 : 22, 1.1), color: AppColors.petalWhite }}>{pick.title}</div>
            {pick.author && (
              <>
                <div style={{ height: 4 }} />
                <div className="ellipsis" style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.85), fontSize: 12.5, lineHeight: lineHeight(12.5) }}>{pick.author}</div>
              </>
            )}
            {!big && blurb && (
              <>
                <div style={{ height: 8 }} />
                <div className="clamp-2" style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.82), fontSize: 11.5, lineHeight: lineHeight(11.5, 1.4) }}>{blurb}</div>
              </>
            )}
            {!big && <div style={{ height: 12 }} />}
            {!big && cta}
          </div>
          {big && (
            <div style={{ width: '38%', flexShrink: 0, alignSelf: 'stretch', paddingLeft: 22, marginLeft: 8, borderLeft: `1px solid ${withAlpha(AppColors.petalWhite, 0.14)}`, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
              {blurb && (
                <div className="clamp-3" style={{ ...AppTypography.outfitWhite, color: withAlpha(AppColors.roseQuartz, 0.85), fontSize: 13, lineHeight: lineHeight(13, 1.5) }}>
                  {blurb}
                </div>
              )}
              <div style={{ height: 16 }} />
              {cta}
            </div>
          )}
        </button>
        <button type="button" className="bare-button" aria-label={`Details for ${pick.title}`} title="More details" onClick={onDetails} style={{ position: 'absolute', top: 10, right: 10, width: 44, height: 44, borderRadius: 22, display: 'grid', placeItems: 'center', background: withAlpha(AppColors.petalWhite, 0.1), border: `1px solid ${withAlpha(AppColors.petalWhite, 0.2)}`, color: AppColors.petalWhite }}>
          <Icon name="info" size={19} color={AppColors.petalWhite} />
        </button>
      </div>
    </div>
  );
}

  /** A quiet, one-tap way back into the book Clair was reading. */
  function ContinueReading({ progress, onOpen }: { progress: ReaderProgress; onOpen: () => void }) {
    const pct = Math.round(progress.scroll * 100);
    return (
      <div style={{ padding: '10px 20px 0' }}>
        <div style={{ ...AppTypography.outfitBold, fontSize: 11, lineHeight: lineHeight(11), letterSpacing: 1.5, color: AppColors.warmAmber, marginBottom: 8 }}>
          CONTINUE READING
        </div>
        <button
          type="button"
          className="bare-button"
          aria-label={`Continue reading ${progress.title}`}
          onClick={onOpen}
          style={{
            width: '100%', display: 'flex', alignItems: 'center', gap: 14, padding: 14, textAlign: 'left',
            borderRadius: 20, background: withAlpha(AppColors.shimmerBase, 0.85),
            border: `1px solid ${withAlpha(AppColors.warmAmber, 0.25)}`,
          }}
        >
          <BookCover imageUrl={progress.coverUrl} title={progress.title} author={progress.author} width={64} radius={8} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="clamp-2" style={{ ...AppTypography.cormorantBoldWhite, fontSize: 20, lineHeight: lineHeight(20, 1.15) }}>{progress.title}</div>
            {progress.author && (
              <div className="ellipsis" style={{ ...AppTypography.outfitWhite, fontSize: 12, color: withAlpha(AppColors.roseQuartz, 0.75), marginTop: 3 }}>{progress.author}</div>
            )}
            <div style={{ height: 8 }} />
            <div style={{ height: 4, borderRadius: 2, background: withAlpha(AppColors.petalWhite, 0.12), overflow: 'hidden' }}>
              <div style={{ height: '100%', width: `${Math.max(4, pct)}%`, background: AppColors.warmAmber }} />
            </div>
            <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.roseQuartz, 0.82), marginTop: 6 }}>
              {progress.readerName ? `${progress.readerName} is reading · ` : ''}Chapter {progress.chapter + 1} · {pct}% through · Tap to resume
            </div>
          </div>
          <Icon name="play_arrow" size={20} color={AppColors.warmAmber} />
        </button>
      </div>
    );
  }

export function BooksPage() {
  const { width } = useViewport();
  const { currentUser, isCoupleUser, isCinemaOnlyUser } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams, setSearchParams] = useSearchParams();
  const initialQuery = (location.state as { query?: string } | null)?.query ?? '';
  // Navigator.canPop: true only when the app pushed this page.
  const canPop = (window.history.state as { idx?: number } | null)?.idx ? true : false;

  const tabParam = Number(searchParams.get('tab'));
  const segmentParam = Number(searchParams.get('seg'));
  const [tab, setTabState] = useState<0 | 1 | 2>(initialQuery ? 1 : tabParam >= 0 && tabParam <= 2 ? (tabParam as 0 | 1 | 2) : booksView.tab);
  const [librarySegment, setLibrarySegmentState] = useState<0 | 1 | 2 | 3>(segmentParam >= 0 && segmentParam <= 3 ? (segmentParam as 0 | 1 | 2 | 3) : booksView.segment);
  const setTab = (next: 0 | 1 | 2) => {
    booksView.tab = next;
    setTabState(next);
    const params = new URLSearchParams(searchParams);
    params.set('tab', String(next));
    setSearchParams(params, { replace: true });
  };
  const setLibrarySegment = (next: 0 | 1 | 2 | 3) => {
    booksView.segment = next;
    setLibrarySegmentState(next);
    const params = new URLSearchParams(searchParams);
    params.set('tab', '2');
    params.set('seg', String(next));
    setSearchParams(params, { replace: true });
  };
  const homeRef = useRef<HTMLDivElement>(null);
  const advPanelRef = useRef<HTMLDivElement>(null);
  const advTriggerRef = useRef<HTMLButtonElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [recentSearches, setRecentSearches] = useState<string[]>(() => {
    const saved = Prefs.get('recent_book_searches');
    return Array.isArray(saved) ? (saved as string[]).slice(0, 6) : [];
  });

  const [popular, setPopular] = useState<BookSearchResult[]>([]);
  const [recent, setRecent] = useState<BookSearchResult[]>([]);
  const [because, setBecause] = useState<BookSearchResult[]>([]);
  const [loadingHome, setLoadingHome] = useState(true);
  const [homeError, setHomeError] = useState(false);
  const [popError, setPopError] = useState(false);
  const [recError, setRecError] = useState(false);
  const [homeRetryKey, setHomeRetryKey] = useState(0);
  const [slowLoad, setSlowLoad] = useState(false);
  const goal = useSource(() => watchCoupleGoal(), [], 12);
  const setGoal = (next: number) => {
    const value = Math.max(1, Math.min(52, next));
    void saveCoupleGoal(value);
  };

  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [searchResults, setSearchResults] = useState<BookSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState(false);
  const [searchRetryKey, setSearchRetryKey] = useState(0);
  const [searchTotal, setSearchTotal] = useState(0);
  const [searchLimit, setSearchLimit] = useState(30);
  const [searchOrder, setSearchOrder] = useState<'relevant' | 'popular' | 'newest'>('relevant');
  const [searchFormat, setSearchFormat] = useState<string>('');
  const [searchLang, setSearchLang] = useState<string>('All');
  const [advOpen, setAdvOpen] = useState(false);
  const [advTitle, setAdvTitle] = useState('');
  const [advAuthor, setAdvAuthor] = useState('');
  const [advPublisher, setAdvPublisher] = useState('');
  const [advIsbn, setAdvIsbn] = useState('');
  const [advYearFrom, setAdvYearFrom] = useState('');
  const [advYearTo, setAdvYearTo] = useState('');
  const [advExact, setAdvExact] = useState(false);
  const [appliedAdv, setAppliedAdv] = useState({
    title: '',
    author: '',
    publisher: '',
    isbn: '',
    yearFrom: '',
    yearTo: '',
    exact: false,
  });

  const userName = currentUser ?? '';
  const readlist = useSource(() => watchReadList(userName), [userName], []);
  const favorites = useSource(() => watchBookFavorites(userName), [userName], []);
  const downloads = useSource(() => watchBookDownloads(userName), [userName], []);

  const toReadList = readlist.filter((b) => b.status === 'to-read');
  const readHistoryList = readlist.filter((b) => isBookRead(b.status));
  const readThisYear = readHistoryList.filter((b) => b.addedAt.getFullYear() === new Date().getFullYear()).length;

  useEffect(() => {
    let alive = true;
    setLoadingHome(true);
    setPopError(false);
    setRecError(false);
    let popFailed = false;
    let recFailed = false;
    void Promise.all([
      fetchPopularBooks(12).catch(() => {
        popFailed = true;
        if (alive) setPopError(true);
        return [] as BookSearchResult[];
      }),
      fetchRecentBooks(12).catch(() => {
        recFailed = true;
        if (alive) setRecError(true);
        return [] as BookSearchResult[];
      }),
    ])
      .then(([pop, rec]) => {
        if (!alive) return;
        setPopular(pop);
        setRecent(rec);
        setHomeError(popFailed && recFailed);
      })
      .finally(() => alive && setLoadingHome(false));
    return () => {
      alive = false;
    };
  }, [homeRetryKey]);

  useEffect(() => {
    const counts = new Map<string, number>();
    for (const b of [...readHistoryList, ...favorites]) {
      for (const s of b.subjects.slice(0, 3)) counts.set(s, (counts.get(s) ?? 0) + 1);
    }
    const subjects = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3).map(([s]) => s);
    if (subjects.length === 0) {
      setBecause([]);
      return;
    }
    let alive = true;
    void Promise.all(subjects.map((s) => fetchBooksBySubject(s, 10))).then((pages) => {
      if (!alive) return;
      const seen = new Set([...readHistoryList, ...favorites].map((b) => b.workKey));
      const merged = pages.flat().filter((r) => r.title && !seen.has(r.workKey));
      const unique = [...new Map(merged.map((r) => [r.workKey, r])).values()];
      setBecause(unique.slice(0, 10));
    });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [readHistoryList.map((b) => b.workKey).join('|'), favorites.map((b) => b.workKey).join('|')]);

  useEffect(() => {
    const q = searchQuery.trim();
    if (q) {
      const nextRecent = [q, ...recentSearches.filter((s) => s.toLowerCase() !== q.toLowerCase())].slice(0, 6);
      setRecentSearches(nextRecent);
      Prefs.set('recent_book_searches', nextRecent);
    }
    if (!q) {
      setSearchResults([]);
      setSearching(false);
      setSearchError(false);
      return;
    }
    let alive = true;
    setSearching(true);
    setSearchError(false);
    const failureAt = catalogFailureAt();
    const t = window.setTimeout(() => {
      searchBooksCatalog(q, {
        filetype: searchFormat || undefined,
        language: searchLang !== 'All' ? LANG_CODES[searchLang] : undefined,
        title: appliedAdv.title || undefined,
        author: appliedAdv.author || undefined,
        isbn: appliedAdv.isbn || undefined,
        publisher: appliedAdv.publisher || undefined,
        limit: searchLimit,
        sort: searchOrder,
      }).then((res) => {
        if (!alive) return;
        let list = res.results;
        const yFrom = Number.parseInt(appliedAdv.yearFrom, 10);
        if (Number.isFinite(yFrom)) {
          list = list.filter((b) => {
            const by = Number.parseInt(b.year, 10);
            return Number.isFinite(by) && by >= yFrom;
          });
        }
        const yTo = Number.parseInt(appliedAdv.yearTo, 10);
        if (Number.isFinite(yTo)) {
          list = list.filter((b) => {
            const by = Number.parseInt(b.year, 10);
            return Number.isFinite(by) && by <= yTo;
          });
        }
        if (appliedAdv.exact) {
          const norm = (s: string) => s.trim().toLowerCase().replace(/\s+/g, ' ');
          const targetTitle = norm(appliedAdv.title);
          const targetAuthor = norm(appliedAdv.author);
          const targetQuery = norm(q);
          list = list.filter((b) => {
            const bt = norm(b.title);
            const ba = norm(b.author);
            if (targetTitle && targetAuthor) return bt === targetTitle && ba === targetAuthor;
            if (targetTitle) return bt === targetTitle;
            if (targetAuthor) return ba === targetAuthor;
            return bt === targetQuery || ba === targetQuery;
          });
        }
        if (searchOrder === 'newest') {
          list = [...list].sort((a, b) => Number(b.year || 0) - Number(a.year || 0));
        } else if (searchOrder === 'popular') {
          list = [...list].sort((a, b) => (b.ratingCount ?? 0) - (a.ratingCount ?? 0));
        }
        setSearchResults(list);
        const advancedFilter = Boolean(appliedAdv.title || appliedAdv.author || appliedAdv.yearFrom || appliedAdv.yearTo || appliedAdv.exact);
        setSearchTotal(advancedFilter ? list.length : res.total);
        setSearchError(list.length === 0 && catalogFailureAt() > failureAt);
        setSearching(false);
      });
    }, 250);
    return () => {
      alive = false;
      window.clearTimeout(t);
    };
  }, [searchQuery, searchFormat, searchLang, searchOrder, appliedAdv, searchRetryKey, searchLimit]);

  const openDetails = (r: BookSearchResult) => {
    navigate(`/books/detail?workKey=${encodeURIComponent(r.workKey)}`, { state: { result: r } });
  };

  const openItemDetails = (b: BookItem) => {
    navigate(`/books/detail?workKey=${encodeURIComponent(b.workKey)}`, { state: { result: bookItemToSearchResult(b), saved: b } });
  };

  const openReader = (item: BookItem) => {
    navigate(`/books/reader?workKey=${encodeURIComponent(item.workKey)}`, { state: { book: item } });
  };

  const spotlight = popular[0] ?? recent[0] ?? null;
  const seenKeys = new Set(spotlight ? [spotlight.workKey] : [] as string[]);
  const dedupe = (list: BookSearchResult[]) => list.filter((r) => {
    if (seenKeys.has(r.workKey)) return false;
    seenKeys.add(r.workKey);
    return true;
  });
  const becauseRail = dedupe(because);
  const popularRail = dedupe(popular);
  const recentRail = dedupe(recent);
  const showSkeleton = loadingHome && popular.length === 0 && recent.length === 0;
  const remoteProgress = useSource(() => watchAllReaderProgress(20), [userName], [] as ReaderProgress[]);
  const progressMap = new Map<string, ReaderProgress>();
  for (const p of listProgress()) progressMap.set(p.workKey, p);
  for (const p of remoteProgress) progressMap.set(p.workKey, p);
  const resumeList = [...progressMap.values()].filter((p) => p.title !== '' && (p.chapter > 0 || p.scroll > 0)).slice(0, 3);
  const isTablet = width >= 700;
  const cols = width >= 1024 ? 7 : width >= 600 ? 5 : 3;

  useEffect(() => {
    if (!showSkeleton) {
      setSlowLoad(false);
      return;
    }
    const timer = window.setTimeout(() => setSlowLoad(true), 3000);
    return () => window.clearTimeout(timer);
  }, [showSkeleton]);

  useEffect(() => {
    if (showSkeleton || tab !== 0) return;
    const id = window.requestAnimationFrame(() => {
      if (homeRef.current) homeRef.current.scrollTop = booksView.scroll;
    });
    return () => window.cancelAnimationFrame(id);
  }, [showSkeleton, tab]);

  useEffect(() => {
    if (tab === 1) window.requestAnimationFrame(() => searchInputRef.current?.focus());
  }, [tab]);

  useDialogFocus(advOpen, advPanelRef, () => setAdvOpen(false), advTriggerRef);
  const libraryList =
    librarySegment === 0 ? toReadList : librarySegment === 1 ? readHistoryList : librarySegment === 2 ? favorites : downloads;

  const header = (
    <div style={{ padding: '14px 20px 0', paddingTop: 'calc(14px + env(safe-area-inset-top, 0px))', display: 'flex', alignItems: 'center' }}>
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
        <div style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), color: withAlpha(AppColors.roseQuartz, 0.82) }}>
          Free classics and new finds
        </div>
      </div>
      {isCoupleUser && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {width >= 700 && <span style={{ ...AppTypography.outfitBold, fontSize: 12.5, color: AppColors.roseQuartz }}>Our Books</span>}
          <ShelfIconButton icon="favorite" label="Open Our Books" tooltip="Our Books" onClick={() => navigate('/our-books')} />
        </div>
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
        <span style={{ ...AppTypography.outfitWhite, fontSize: 14, lineHeight: lineHeight(14), color: withAlpha(AppColors.roseQuartz, 0.82) }}>
          Search titles, authors, subjects
        </span>
      </button>
    </div>
  );

  const feedRail = (eyebrow: string, title: string, accent: string, results: BookSearchResult[], kind: 'popular' | 'recent') =>
    results.length === 0 ? null : (
      <div>
        <SectionHead
          eyebrow={eyebrow}
          title={title}
          accent={accent}
          onSeeAll={() => navigate(`/books/list?kind=${kind}&title=${encodeURIComponent(title)}`, { state: { kind, title, initialResults: results } })}
        />
        <Rail height={isTablet ? 310 : 262} gap={14} padding="0 0 4px 20px">
          {results.map((r) => (
            <BookCoverCard key={r.workKey || r.title} width={isTablet ? 150 : 124} result={r} onClick={() => openDetails(r)} />
          ))}
        </Rail>
      </div>
    );

  return (
    <div style={{ position: 'relative', height: '100%', background: cBlack, color: AppColors.petalWhite, overflow: 'hidden' }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: AppColors.warmAmber, alignment: [-0.7, -0.85], size: 0.85, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.85, 0.95], size: 0.8, opacity: 0.1 },
        ]}
      />

      {tab === 0 && (
        <div
          ref={homeRef}
          onScroll={(e) => { booksView.scroll = e.currentTarget.scrollTop; }}
          style={{ position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden', maxWidth: isTablet ? 1180 : undefined, margin: '0 auto' }}
        >
          {header}
          {homeSearch}
          {resumeList.slice(0, 1).map((p) => (
            <ContinueReading key={p.workKey} progress={p} onOpen={() => openReader(progressToBookItem(p))} />
          ))}
          {resumeList.length > 1 && (
            <button type="button" className="bare-button" onClick={() => { setLibrarySegment(1); setTab(2); }} style={{ display: 'block', width: 'calc(100% - 40px)', margin: '8px 20px 0', textAlign: 'left', fontSize: 12, fontWeight: 700, color: AppColors.warmAmber }}>
              {resumeList.length} books in progress — see your shelf →
            </button>
          )}
          {homeError && (
            <div style={{ margin: '14px 20px 0', padding: 14, borderRadius: 16, background: withAlpha(AppColors.error, 0.1), border: `1px solid ${withAlpha(AppColors.error, 0.35)}`, display: 'flex', alignItems: 'center', gap: 12 }}>
              <Icon name="cloud_off" size={20} color={AppColors.error} />
              <div style={{ flex: 1, fontSize: 13, color: AppColors.petalWhite }}>Couldn't reach the catalogue.</div>
              <button type="button" className="bare-button" onClick={() => setHomeRetryKey((k) => k + 1)} style={{ minHeight: 40, padding: '0 14px', borderRadius: 12, background: withAlpha(AppColors.error, 0.2), color: AppColors.petalWhite, fontWeight: 700, fontSize: 12 }}>Try again</button>
            </div>
          )}
          {!homeError && !loadingHome && popular.length === 0 && recent.length === 0 && (
            <div style={{ margin: '14px 20px 0', padding: 14, borderRadius: 16, background: withAlpha(BookColors.card, 0.6), border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.12)}` }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: AppColors.petalWhite }}>The shelves are quiet right now.</div>
              <div style={{ fontSize: 12, color: withAlpha(AppColors.roseQuartz, 0.82), marginTop: 4 }}>Search for a title, or check back in a little while.</div>
            </div>
          )}
          {showSkeleton && (
            <div>
              <ShimmerHome />
              {slowLoad && (
                <div style={{ padding: '4px 20px 12px', textAlign: 'center', color: AppColors.roseQuartz, fontSize: 12 }}>
                  Still loading… the catalogue can be slow. Your shelves and saved books are right here.
                </div>
              )}
            </div>
          )}
          {!showSkeleton && spotlight && (
            <StaggeredEntrance>
              <Spotlight
                pick={spotlight}
                onOpen={() => openReader(searchResultToBookItem(spotlight))}
                onDetails={() => openDetails(spotlight)}
              />
            </StaggeredEntrance>
          )}
          {!showSkeleton && (becauseRail.length > 0 || (readHistoryList.length === 0 && recentRail.length > 0)) && (
            <div>
              <SectionHead
                eyebrow={readHistoryList.length > 0 ? `Because you read ${readHistoryList[0]?.subjects[0] ?? 'books'}` : 'A good place to start'}
                title={readHistoryList.length > 0 ? 'Because you read…' : 'Fresh finds'}
                accent={AppColors.softLavender}
                onSeeAll={() => navigate('/books/list?kind=recent&title=Fresh%20picks', { state: { title: 'Fresh picks', initialResults: becauseRail.length ? becauseRail : recentRail } })}
              />
              <Rail height={isTablet ? 310 : 262} gap={14} padding="0 0 4px 20px">
                {(becauseRail.length ? becauseRail : recentRail.slice(0, 8)).map((r) => (
                  <BookCoverCard key={r.workKey || r.title} width={isTablet ? 150 : 124} result={r} onClick={() => openDetails(r)} />
                ))}
              </Rail>
            </div>
          )}
          <div>
            <SectionHead eyebrow="Browse" title="Shelves" accent={AppColors.warmAmber} onSeeAll={() => navigate('/books/categories')} />
            <Rail height={44} gap={8} padding="0 0 0 20px">
              {BOOK_CATEGORIES.map((cat) => (
                <button
                  key={cat.query}
                  type="button"
                  className="bare-button"
                  onClick={() => navigate(`/books/category?subject=${encodeURIComponent(cat.query)}`, { state: { category: cat } })}
                  style={{ flexShrink: 0, padding: '0 16px', borderRadius: 22, background: withAlpha(cat.color, 0.12), border: `1px solid ${withAlpha(cat.color, 0.3)}`, display: 'flex', alignItems: 'center' }}
                >
                  <Icon name={cat.icon} size={17} color={cat.color} />
                  <div style={{ width: 8 }} />
                  <span style={{ ...AppTypography.outfitBold, color: AppColors.petalWhite, fontSize: 12.5, lineHeight: lineHeight(12.5), whiteSpace: 'nowrap' }}>{cat.name}</span>
                </button>
              ))}
            </Rail>
          </div>
          {readHistoryList.length > 0 && (
            <div>
              <SectionHead
                eyebrow="Pick one up again"
                title="Read Before"
                accent={AppColors.roseQuartz}
                onSeeAll={() => {
                  setLibrarySegment(1);
                  setTab(2);
                }}
              />
              <Rail height={isTablet ? 296 : 246} gap={14} padding="0 0 4px 20px">
                {readHistoryList.slice(0, 12).map((b) => (
                  <BookCoverCard
                    key={b.workKey}
                    width={isTablet ? 140 : 112}
                    item={b}
                    statusBadge={bookReadDisplay(b.status)}
                    badgeColor={readBadgeColor(b.status)}
                    progress={progressMap.get(b.workKey)?.scroll}
                    onClick={() => openReader(b)}
                  />
                ))}
              </Rail>
            </div>
          )}
          {!showSkeleton && (
            <>
              {popError && popular.length === 0 ? (
                <div style={{ margin: '16px 20px 0', fontSize: 12.5, color: AppColors.roseQuartz }}>
                  Most Popular couldn’t load. <button type="button" className="bare-button" onClick={() => setHomeRetryKey((k) => k + 1)} style={{ fontWeight: 700, textDecoration: 'underline' }}>Try again</button>
                </div>
              ) : (
                <StaggeredEntrance>{feedRail('The most downloaded', 'Most downloaded', AppColors.warmAmber, popularRail, 'popular')}</StaggeredEntrance>
              )}
              {recError && recent.length === 0 ? (
                <div style={{ margin: '16px 20px 0', fontSize: 12.5, color: AppColors.roseQuartz }}>
                  Recently Added couldn’t load. <button type="button" className="bare-button" onClick={() => setHomeRetryKey((k) => k + 1)} style={{ fontWeight: 700, textDecoration: 'underline' }}>Try again</button>
                </div>
              ) : (
                feedRail('Fresh in the catalog', 'New arrivals', AppColors.deepRose, recentRail, 'recent')
              )}
            </>
          )}
          <div style={{ position: 'sticky', bottom: 0, height: 72, marginTop: -72, background: `linear-gradient(to bottom, transparent, ${cBlack})`, pointerEvents: 'none', zIndex: 2 }} />
          <div style={{ height: 100 }} />
        </div>
      )}

      <div style={{ position: 'absolute', inset: 0, overflowY: 'auto', paddingBottom: 100, maxWidth: isTablet ? 1180 : undefined, margin: '0 auto', display: tab === 0 ? 'none' : undefined }}>
        {tab === 1 && (
          <div style={{ padding: '14px 20px 0' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <ShelfIconButton icon="arrow_back_ios_new" label="Back" size={44} onClick={() => setTab(0)} />
              <div>
                <div style={{ fontFamily: Fonts.display, fontWeight: 800, fontSize: 28, lineHeight: 1.05, color: BookColors.white }}>Search</div>
                <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.8, color: BookColors.muted, marginTop: 2 }}>FIND YOUR NEXT OBSESSION</div>
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 16 }}>
              <div
                style={{
                  flex: 1,
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
                  ref={searchInputRef}
                  aria-label="Search books"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Title, author, ISBN..."
                  style={{ flex: 1, background: 'transparent', border: 'none', outline: 'none', color: BookColors.white, fontSize: 16 }}
                />
                {searchQuery && (
                  <button type="button" className="bare-button" onClick={() => setSearchQuery('')}>
                    <Icon name="close" size={18} color={BookColors.muted} />
                  </button>
                )}
              </div>
              <button
                ref={advTriggerRef}
                type="button"
                className="bare-button"
                aria-label="Advanced filters"
                aria-pressed={advOpen}
                onClick={() => setAdvOpen(true)}
                style={{
                  width: 54,
                  height: 54,
                  borderRadius: 18,
                  background: withAlpha(BookColors.deepRose, 0.16),
                  border: `1px solid ${withAlpha(BookColors.deepRose, 0.35)}`,
                  display: 'grid',
                  placeItems: 'center',
                  flexShrink: 0,
                }}
              >
                <Icon name="tune" size={21} color={BookColors.deepRose} />
              </button>
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 8, marginTop: 14 }}>
              <div
                style={{
                  position: 'relative',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 8,
                  height: 52,
                  padding: '0 16px',
                  borderRadius: 14,
                  background: withAlpha(BookColors.card, 0.9),
                  border: `1px solid ${withAlpha(BookColors.rose, 0.12)}`,
                }}
              >
                <select
                  value={searchOrder}
                  onChange={(e) => setSearchOrder(e.target.value as 'relevant' | 'popular' | 'newest')}
                  aria-label="Order results"
                  style={{ appearance: 'none', background: 'transparent', border: 'none', color: BookColors.white, fontSize: 12.5, fontWeight: 700, padding: '0 26px 0 0', cursor: 'pointer', outlineOffset: 3 }}
                >
                  <option style={{ background: BookColors.card }} value="relevant">Order: relevant</option>
                  <option style={{ background: BookColors.card }} value="popular">Order: popular</option>
                  <option style={{ background: BookColors.card }} value="newest">Order: newest</option>
                </select>
                <div style={{ position: 'absolute', right: 8, pointerEvents: 'none', display: 'grid', placeItems: 'center' }}>
                  <Icon name="keyboard_arrow_down" size={16} color={BookColors.muted} />
                </div>
              </div>
              {([
                ['EPUB', 'menu_book'],
                ['PDF', 'picture_as_pdf'],
                ['TXT', 'article'],
                ['MOBI', 'tablet_mac'],
                ['FB2', 'description'],
                ['HTML', 'public'],
              ] as const).slice(0, 2).map(([fmt, icon]) => {
                const active = searchFormat === fmt;
                return (
                  <button
                    key={fmt}
                    type="button"
                    className="bare-button"
                    aria-pressed={active}
                    onClick={() => setSearchFormat(active ? '' : fmt)}
                    style={{
                      height: 44,
                      padding: '0 14px',
                      borderRadius: 18,
                      background: active ? withAlpha(BookColors.deepRose, 0.22) : withAlpha(BookColors.card, 0.8),
                      border: `1px solid ${active ? withAlpha(BookColors.deepRose, 0.6) : withAlpha(BookColors.rose, 0.12)}`,
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 6,
                    }}
                  >
                    <Icon name={icon} size={14} color={active ? BookColors.deepRose : BookColors.muted} />
                    <span style={{ fontSize: 12, fontWeight: 700, color: active ? BookColors.white : BookColors.muted }}>{fmt}</span>
                  </button>
                );
              })}
              <button type="button" className="bare-button" onClick={() => setAdvOpen(true)} style={{ height: 44, padding: '0 14px', borderRadius: 18, background: withAlpha(BookColors.card, 0.8), border: `1px solid ${withAlpha(BookColors.rose, 0.12)}`, color: BookColors.white, fontSize: 12, fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <Icon name="tune" size={14} color={BookColors.deepRose} /> Filters
                {(searchLang !== 'All' || appliedAdv.title || appliedAdv.author || appliedAdv.publisher || appliedAdv.isbn || appliedAdv.yearFrom || appliedAdv.yearTo || appliedAdv.exact || Boolean(searchFormat)) && (
                  <span style={{ minWidth: 18, height: 18, padding: '0 5px', borderRadius: 9, background: BookColors.deepRose, color: '#FFF', fontSize: 10, display: 'grid', placeItems: 'center' }}>on</span>
                )}
              </button>
            </div>

            {(() => {
              const chips: { label: string; clear: () => void }[] = [];
              if (appliedAdv.title) chips.push({ label: `Title: ${appliedAdv.title}`, clear: () => setAppliedAdv({ ...appliedAdv, title: '' }) });
              if (appliedAdv.author) chips.push({ label: `Author: ${appliedAdv.author}`, clear: () => setAppliedAdv({ ...appliedAdv, author: '' }) });
              if (appliedAdv.publisher) chips.push({ label: `Publisher: ${appliedAdv.publisher}`, clear: () => setAppliedAdv({ ...appliedAdv, publisher: '' }) });
              if (appliedAdv.isbn) chips.push({ label: `ISBN: ${appliedAdv.isbn}`, clear: () => setAppliedAdv({ ...appliedAdv, isbn: '' }) });
              if (appliedAdv.yearFrom || appliedAdv.yearTo) chips.push({ label: `Years: ${appliedAdv.yearFrom || '…'}–${appliedAdv.yearTo || '…'}`, clear: () => setAppliedAdv({ ...appliedAdv, yearFrom: '', yearTo: '' }) });
              if (appliedAdv.exact) chips.push({ label: 'Exact match', clear: () => setAppliedAdv({ ...appliedAdv, exact: false }) });
              if (searchFormat) chips.push({ label: `Format: ${searchFormat}`, clear: () => setSearchFormat('') });
              if (searchLang !== 'All') chips.push({ label: `Language: ${searchLang}`, clear: () => setSearchLang('All') });
              if (chips.length === 0) return null;
              return (
                <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 6, marginTop: 12 }}>
                  <span style={{ fontSize: 11, color: BookColors.muted, marginRight: 2 }}>{chips.length} filter{chips.length > 1 ? 's' : ''}</span>
                  {chips.map((chip) => (
                    <button
                      key={chip.label}
                      type="button"
                      className="bare-button"
                      aria-label={`Clear ${chip.label}`}
                      onClick={chip.clear}
                      style={{ minHeight: 44, padding: '0 12px', borderRadius: 16, display: 'inline-flex', alignItems: 'center', gap: 4, background: withAlpha(BookColors.deepRose, 0.16), border: `1px solid ${withAlpha(BookColors.deepRose, 0.4)}`, color: BookColors.white, fontSize: 11.5, fontWeight: 700 }}
                    >
                      {chip.label}
                      <Icon name="close" size={12} color={BookColors.rose} />
                    </button>
                  ))}
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => {
                      setAppliedAdv({ title: '', author: '', publisher: '', isbn: '', yearFrom: '', yearTo: '', exact: false });
                      setSearchFormat('');
                      setSearchLang('All');
                    }}
                    style={{ minHeight: 32, padding: '0 10px', fontSize: 11.5, fontWeight: 700, color: BookColors.muted, textDecoration: 'underline' }}
                  >
                    Clear all
                  </button>
                </div>
              );
            })()}

            <div style={{ marginTop: 18 }}>
              {searching ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {Array.from({ length: 4 }, (_, i) => (
                    <div key={i} style={{ display: 'flex', gap: 12, padding: 12, borderRadius: 16, background: withAlpha(BookColors.card, 0.5) }}>
                      <div className="skeleton-pulse" style={{ width: 58, height: 87, borderRadius: 8, background: AppColors.shimmerBase, flexShrink: 0 }} />
                      <div style={{ flex: 1 }}>
                        <div className="skeleton-pulse" style={{ height: 12, borderRadius: 5, background: AppColors.shimmerBase, width: '75%' }} />
                        <div className="skeleton-pulse" style={{ height: 10, borderRadius: 5, background: AppColors.shimmerBase, width: '50%', marginTop: 8 }} />
                      </div>
                    </div>
                  ))}
                </div>
              ) : searchResults.length === 0 ? (
                searchQuery.trim() ? (
                  searchError ? (
                    <div style={{ padding: '48px 16px', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
                      <Icon name="cloud_off" size={34} color={withAlpha(AppColors.error, 0.85)} />
                      <div style={{ fontSize: 17, fontWeight: 700, color: BookColors.white, marginTop: 12 }}>Couldn't reach the catalogue.</div>
                      <div style={{ fontSize: 13, color: BookColors.muted, marginTop: 4 }}>Check your connection and try again.</div>
                      <button type="button" className="bare-button" onClick={() => setSearchRetryKey((k) => k + 1)} style={{ marginTop: 16, minHeight: 44, padding: '0 22px', borderRadius: 14, background: BookColors.deepRose, color: '#FFF', fontWeight: 700, fontSize: 13 }}>Try again</button>
                    </div>
                  ) : (
                    <div style={{ padding: '48px 16px', textAlign: 'center', color: BookColors.muted }}>
                      No results found. Try a different title or fewer filters.
                    </div>
                  )
                ) : (
                  <div style={{ padding: '140px 16px 40px', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
                    <div
                      style={{
                        width: 68,
                        height: 68,
                        borderRadius: '50%',
                        background: withAlpha(BookColors.deepRose, 0.1),
                        border: `1px solid ${withAlpha(BookColors.rose, 0.15)}`,
                        display: 'grid',
                        placeItems: 'center',
                      }}
                    >
                      <Icon name="manage_search" size={30} color={withAlpha(BookColors.rose, 0.85)} />
                    </div>
                    <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700, color: BookColors.white, marginTop: 16 }}>
                      Type to discover magic
                    </div>
                    <div style={{ fontSize: 13, color: BookColors.muted, marginTop: 6 }}>
                      Search any book, author, or subject across the full database.
                    </div>
                    {recentSearches.length > 0 && (
                      <div style={{ marginTop: 20, display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center' }}>
                        <div style={{ width: '100%', fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: AppColors.warmAmber }}>RECENT SEARCHES</div>
                        {recentSearches.map((s) => (
                          <button key={s} type="button" className="bare-button" onClick={() => setSearchQuery(s)} style={{ minHeight: 44, padding: '0 14px', borderRadius: 18, background: withAlpha(BookColors.card, 0.8), border: `1px solid ${withAlpha(BookColors.rose, 0.14)}`, color: BookColors.white, fontSize: 12.5, fontWeight: 700 }}>{s}</button>
                        ))}
                      </div>
                    )}
                    <div style={{ marginTop: 20, display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center' }}>
                      <div style={{ width: '100%', fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: AppColors.warmAmber }}>OR TRY A SHELF</div>
                      {BOOK_CATEGORIES.slice(0, 6).map((cat) => (
                        <button key={cat.query} type="button" className="bare-button" onClick={() => setSearchQuery(cat.name)} style={{ minHeight: 44, padding: '0 14px', borderRadius: 18, background: withAlpha(cat.color, 0.12), border: `1px solid ${withAlpha(cat.color, 0.3)}`, color: AppColors.petalWhite, fontSize: 12.5, fontWeight: 700 }}>{cat.name}</button>
                      ))}
                    </div>
                  </div>
                )
              ) : (
                <>
                  <div style={{ fontSize: 12, color: BookColors.muted, marginBottom: 10 }}>
                    {searchResults.length} of {searchTotal || searchResults.length} books
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: isTablet ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 10 }}>
                    {searchResults.map((r) => (
                    <button
                      key={r.workKey || r.title}
                      type="button"
                      className="bare-button"
                      aria-label={r.author ? `Open ${r.title} by ${r.author}` : `Open ${r.title}`}
                      onClick={() => openDetails(r)}
                      style={{
                        width: '100%', textAlign: 'left', padding: 12,
                        borderRadius: 16,
                        background: withAlpha(BookColors.card, 0.72),
                        border: `1px solid ${withAlpha(BookColors.rose, 0.12)}`,
                        display: 'flex',
                        gap: 12,
                        alignItems: 'center',
                        cursor: 'pointer',
                      }}
                    >
                      <BookCover width={58} imageUrl={r.coverUrl} title={r.title} author={r.author} radius={8} />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div className="clamp-2" style={{ fontSize: 15, fontWeight: 700, color: BookColors.white }}>{r.title}</div>
                        {r.author && <div style={{ fontSize: 12.5, color: BookColors.rose, marginTop: 3 }}>{r.author}</div>}
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 6, fontSize: 11, color: BookColors.muted }}>
                          {r.year && <span>{r.year}</span>}
                          {r.filetype && (
                            <span style={{ padding: '1px 6px', borderRadius: 4, background: withAlpha(BookColors.deepRose, 0.18), color: BookColors.rose, fontWeight: 700 }}>
                              {r.filetype.toUpperCase()}
                            </span>
                          )}
                          {r.sourceLabel && <span>{r.sourceLabel}</span>}
                          {r.ratingCount ? <span style={{ color: AppColors.warmAmber, fontWeight: 700 }}>{r.ratingCount >= 1000 ? `${(r.ratingCount / 1000).toFixed(0)}k` : r.ratingCount} downloads</span> : null}
                        </div>
                      </div>
                      <Icon name="chevron_right" size={18} color={BookColors.muted} />
                    </button>
                    ))}
                  </div>
                  {searchResults.length < searchTotal && (
                    <button type="button" className="bare-button" onClick={() => setSearchLimit((n) => n + 30)} style={{ display: 'block', margin: '18px auto 0', minHeight: 44, padding: '0 24px', borderRadius: 22, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.3)}`, color: AppColors.petalWhite, fontWeight: 700, fontSize: 13 }}>
                      Show more books
                    </button>
                  )}
                </>
              )}
            </div>

            {advOpen && (
              <div
                onClick={() => setAdvOpen(false)}
                style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.72)', zIndex: 90, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
              >
                <div
                  ref={advPanelRef}
                  role="dialog"
                  aria-modal="true"
                  aria-label="Advanced search"
                  tabIndex={-1}
                  onClick={(e) => e.stopPropagation()}
                  style={{
                    width: '100%', maxHeight: '88vh', overflowY: 'auto', outline: 'none',
                    maxWidth: 540,
                    background: BookColors.card,
                    borderTopLeftRadius: 28,
                    borderTopRightRadius: 28,
                    padding: '12px 20px 28px',
                  }}
                >
                  <div style={{ width: 36, height: 4, borderRadius: 2, background: withAlpha(BookColors.rose, 0.3), margin: '0 auto 16px' }} />
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ fontFamily: Fonts.display, fontSize: 24, fontWeight: 900, color: BookColors.white }}>Advanced Search</div>
                    <button
                      type="button"
                      className="bare-button"
                      onClick={() => {
                        setAdvTitle('');
                        setAdvAuthor('');
                        setAdvPublisher('');
                        setAdvIsbn('');
                        setAdvYearFrom('');
                        setAdvYearTo('');
                        setAdvExact(false);
                        setAppliedAdv({ title: '', author: '', publisher: '', isbn: '', yearFrom: '', yearTo: '', exact: false });
                      }}
                      style={{ fontSize: 12, fontWeight: 700, color: BookColors.muted }}
                    >
                      Reset fields
                    </button>
                  </div>
                  <div style={{ fontSize: 12, color: BookColors.muted, marginTop: 4, marginBottom: 14 }}>
                    Fill in anything you know — the rest can stay empty.
                  </div>
                  {([
                    ['Title', advTitle, setAdvTitle, 'e.g. Pride and Prejudice'],
                    ['Author', advAuthor, setAdvAuthor, 'e.g. Jane Austen'],
                    ['Publisher', advPublisher, setAdvPublisher, 'e.g. Penguin Classics'],
                    ['ISBN', advIsbn, setAdvIsbn, 'e.g. 9780141439518'],
                  ] as const).map(([lbl, val, setter, ph]) => (
                    <div key={lbl} style={{ marginBottom: 10 }}>
                      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: BookColors.muted, textTransform: 'uppercase', marginBottom: 4 }}>{lbl}</div>
                      <input
                        aria-label={lbl}
                        value={val}
                        onChange={(e) => setter(e.target.value)}
                        placeholder={ph}
                        style={{
                          width: '100%',
                          boxSizing: 'border-box',
                          padding: '10px 12px',
                          borderRadius: 12,
                          background: BookColors.black,
                          border: `1px solid ${withAlpha(BookColors.rose, 0.16)}`,
                          color: BookColors.white,
                          fontSize: 16,
                        }}
                      />
                    </div>
                  ))}
                  <div style={{ display: 'flex', gap: 10, marginBottom: 12 }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: BookColors.muted, textTransform: 'uppercase', marginBottom: 4 }}>YEAR FROM</div>
                      <input aria-label="Year from" value={advYearFrom} onChange={(e) => setAdvYearFrom(e.target.value)} placeholder="e.g. 1900" style={{ width: '100%', boxSizing: 'border-box', padding: '10px 12px', borderRadius: 12, background: BookColors.black, border: `1px solid ${withAlpha(BookColors.rose, 0.16)}`, color: BookColors.white, fontSize: 16 }} />
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: BookColors.muted, textTransform: 'uppercase', marginBottom: 4 }}>YEAR TO</div>
                      <input aria-label="Year to" value={advYearTo} onChange={(e) => setAdvYearTo(e.target.value)} placeholder="e.g. 1950" style={{ width: '100%', boxSizing: 'border-box', padding: '10px 12px', borderRadius: 12, background: BookColors.black, border: `1px solid ${withAlpha(BookColors.rose, 0.16)}`, color: BookColors.white, fontSize: 16 }} />
                    </div>
                  </div>
                  <div style={{ marginBottom: 14 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: BookColors.muted, textTransform: 'uppercase', marginBottom: 6 }}>Format</div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                      {['EPUB', 'PDF', 'TXT', 'MOBI', 'FB2', 'HTML'].map((fmt) => (
                        <button key={fmt} type="button" className="bare-button" onClick={() => setSearchFormat(searchFormat === fmt ? '' : fmt)} style={{ minHeight: 40, padding: '0 14px', borderRadius: 14, background: searchFormat === fmt ? withAlpha(BookColors.deepRose, 0.22) : withAlpha(BookColors.card, 0.8), border: `1px solid ${searchFormat === fmt ? withAlpha(BookColors.deepRose, 0.6) : withAlpha(BookColors.rose, 0.12)}`, color: searchFormat === fmt ? BookColors.white : BookColors.muted, fontSize: 12, fontWeight: 700 }}>{fmt}</button>
                      ))}
                    </div>
                  </div>
                  <div style={{ marginBottom: 14 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: BookColors.muted, textTransform: 'uppercase', marginBottom: 6 }}>Language</div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                      {['All', 'English', 'Spanish', 'French', 'German', 'Chinese', 'Japanese'].map((lang) => (
                        <button key={lang} type="button" className="bare-button" onClick={() => setSearchLang(lang)} style={{ minHeight: 40, padding: '0 14px', borderRadius: 14, background: searchLang === lang ? withAlpha(BookColors.amber, 0.16) : withAlpha(BookColors.card, 0.8), border: `1px solid ${searchLang === lang ? withAlpha(BookColors.amber, 0.7) : withAlpha(BookColors.rose, 0.12)}`, color: searchLang === lang ? BookColors.amber : BookColors.muted, fontSize: 12, fontWeight: 700 }}>{lang}</button>
                      ))}
                    </div>
                  </div>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => setAdvExact((v) => !v)}
                    style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, textAlign: 'left', marginBottom: 16 }}
                  >
                    <div style={{ width: 22, height: 22, borderRadius: 7, background: advExact ? BookColors.deepRose : 'rgba(255,255,255,0.06)', border: `1px solid ${advExact ? BookColors.deepRose : withAlpha(BookColors.rose, 0.3)}`, display: 'grid', placeItems: 'center' }}>
                      {advExact && <Icon name="check" size={14} color="#FFF" />}
                    </div>
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 700, color: BookColors.white }}>Exact match only</div>
                      <div style={{ fontSize: 11, color: BookColors.muted }}>Title or author must match your search word for word.</div>
                    </div>
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => {
                      const primary = [advTitle, advAuthor, advPublisher, advIsbn].map((x) => x.trim()).filter(Boolean)[0];
                      if (primary) setSearchQuery(primary);
                      setAppliedAdv({
                        title: advTitle.trim(),
                        author: advAuthor.trim(),
                        publisher: advPublisher.trim(),
                        isbn: advIsbn.trim(),
                        yearFrom: advYearFrom.trim(),
                        yearTo: advYearTo.trim(),
                        exact: advExact,
                      });
                      setAdvOpen(false);
                    }}
                    style={{ width: '100%', padding: 14, borderRadius: 16, background: BookColors.deepRose, color: '#FFF', fontWeight: 700, fontSize: 14 }}
                  >
                    Search with these filters
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {tab === 2 && (
          <div style={{ padding: '14px 20px 0' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <ShelfIconButton icon="arrow_back_ios_new" label="Back" size={44} onClick={() => setTab(0)} />
                <div>
                  <h1 style={{ fontFamily: Fonts.display, fontWeight: 900, fontSize: 28, lineHeight: 1.05, margin: 0 }}>Library</h1>
                  <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.8, color: BookColors.muted, marginTop: 2 }}>YOUR SHELVES</div>
                </div>
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

            <div style={{ margin: '14px 0', padding: 16, borderRadius: 18, background: withAlpha(BookColors.card, 0.7), border: `1px solid ${withAlpha(AppColors.warmAmber, 0.18)}` }}>
              <div style={{ ...AppTypography.outfitBold, fontSize: 11, letterSpacing: 1.4, color: AppColors.warmAmber, marginBottom: 12 }}>YOUR READING</div>
              <div style={{ display: 'flex', gap: 18 }}>
                {([
                  [readThisYear, 'books read this year'],
                  [toReadList.length, 'to read'],
                  [favorites.length, 'loved'],
                ] as const).map(([value, label]) => (
                  <div key={label}>
                    <div style={{ ...AppTypography.cormorantBlack, fontSize: 28, lineHeight: '28px', color: AppColors.petalWhite }}>{value}</div>
                    <div style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.roseQuartz, 0.82) }}>{label}</div>
                  </div>
                ))}
              </div>
              <div style={{ height: 5, borderRadius: 3, background: withAlpha(AppColors.petalWhite, 0.1), marginTop: 14, overflow: 'hidden' }}>
                <div style={{ height: '100%', width: `${Math.min(100, (readThisYear / goal) * 100)}%`, background: AppColors.warmAmber }} />
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                <span style={{ ...AppTypography.outfitWhite, fontSize: 11, color: withAlpha(AppColors.roseQuartz, 0.82), flex: 1 }}>
                  A gentle goal of {goal} books this year — no pressure.
                </span>
                <button type="button" className="bare-button" aria-label="Lower reading goal" onClick={() => setGoal(goal - 1)} style={{ width: 44, height: 44, borderRadius: 10, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.25)}`, color: AppColors.petalWhite, fontSize: 18 }}>−</button>
                <button type="button" className="bare-button" aria-label="Raise reading goal" onClick={() => setGoal(goal + 1)} style={{ width: 44, height: 44, borderRadius: 10, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.25)}`, color: AppColors.petalWhite, fontSize: 18 }}>+</button>
              </div>
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
                    aria-pressed={active}
                    onClick={() => setLibrarySegment(idx as 0 | 1 | 2 | 3)}
                    style={{
                      height: 44,
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
              <div style={{ padding: '160px 20px 40px', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
                <div
                  style={{
                    width: 68,
                    height: 68,
                    borderRadius: '50%',
                    background: withAlpha(BookColors.deepRose, 0.1),
                    border: `1px solid ${withAlpha(BookColors.rose, 0.15)}`,
                    display: 'grid',
                    placeItems: 'center',
                  }}
                >
                  <Icon
                    name={librarySegment === 0 ? 'bookmark_outline' : librarySegment === 1 ? 'done_all' : librarySegment === 2 ? 'favorite_border' : 'download'}
                    size={30}
                    color={withAlpha(BookColors.rose, 0.85)}
                  />
                </div>
                <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700, color: BookColors.white, marginTop: 16 }}>
                  {librarySegment === 0 ? 'Nothing queued yet' : librarySegment === 1 ? 'Nothing read yet' : librarySegment === 2 ? 'Nothing loved yet' : 'No downloads yet'}
                </div>
                <div style={{ fontSize: 13, color: BookColors.muted, marginTop: 6 }}>
                  {librarySegment === 0
                    ? 'Tap the bookmark on any book to add it to your reading queue.'
                    : librarySegment === 1
                      ? 'Books you finish or mark read appear on this shelf.'
                      : librarySegment === 2
                        ? 'Tap the heart on a book to keep your favorites here.'
                        : 'Downloaded files appear here.'}
                </div>
                <button type="button" className="bare-button" onClick={() => setTab(1)} style={{ marginTop: 18, minHeight: 44, padding: '0 20px', borderRadius: 14, background: BookColors.deepRose, color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                  Browse books
                </button>
              </div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: '18px 14px' }}>
                {libraryList.map((b) => (
                  <BookCoverCard
                    key={b.workKey}
                    width={Math.floor((width - 40 - (cols - 1) * 14) / cols)}
                    item={b}
                    statusBadge={librarySegment === 1 ? bookReadDisplay(b.status) : undefined}
                    progress={progressMap.get(b.workKey)?.scroll}
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
