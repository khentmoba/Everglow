import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { just, useSource } from '../../core/utils/liveSource';
import { useDialogFocus } from '../../shared/utils/focusTrap';
import { Icon } from '../../shared/widgets/Icon';
import { canPop } from '../../shared/widgets/MaterialFields';
import { ShelfAtmosphericBackdrop, ShelfIconButton } from '../../shared/widgets/shelf/Shelf';
import {
  BOOK_CATEGORIES,
  BookColors,
  buildReadCandidates,
  isBookRead,
  searchResultToBookItem,
  type BookCategory,
  type BookItem,
  type BookSearchResult,
} from './bookTypes';
import {
  addToOurBooks,
  catalogFailedRecently,
  fetchBookDetails,
  fetchBooksBySubject,
  fetchPopularBooks,
  fetchRecentBooks,
  recordBookDownload,
  removeFromOurBooks,
  removeFromReadList,
  resolveBookByWorkKey,
  saveToReadList,
  toggleBookFavorite,
  watchBookFavorites,
  watchOurBooks,
  watchReadList,
} from './booksService';
import { BookCover, BookCoverCard } from './BookCover';


export function BookDetailPage() {
  const { currentUser, isCoupleUser } = useAuth();
  const { width } = useViewport();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { result?: BookSearchResult; saved?: BookItem } | null) ?? null;

  const workKeyParam = new URLSearchParams(location.search).get('workKey');
  const [result, setResult] = useState<BookSearchResult | null>(state?.result ?? null);
  const [resolving, setResolving] = useState(Boolean(workKeyParam) && !state?.result);
  const [resolveError, setResolveError] = useState(false);
  const [resolveRetryKey, setResolveRetryKey] = useState(0);
  const [similar, setSimilar] = useState<BookSearchResult[]>([]);
  const [addedToast, setAddedToast] = useState(false);
  const [shareToast, setShareToast] = useState(false);
  const [actionError, setActionError] = useState(false);
  const [descExpanded, setDescExpanded] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const confirmRemoveRef = useRef<HTMLDivElement>(null);

  useDialogFocus(confirmRemove, confirmRemoveRef, () => setConfirmRemove(false));
  const userName = currentUser ?? '';
  const readlist = useSource(() => watchReadList(userName), [userName], []);
  const favorites = useSource(() => watchBookFavorites(userName), [userName], []);
  const ourBooks = useSource(
    () => (isCoupleUser ? watchOurBooks(300) : just([])),
    [isCoupleUser],
    [],
  );

  useEffect(() => {
    if (state?.result || !workKeyParam) return;
    let alive = true;
    setResolveError(false);
    void resolveBookByWorkKey(workKeyParam).then((found) => {
      if (!alive) return;
      setResult(found);
      setResolving(false);
      if (!found) setResolveError(true);
    });
    return () => {
      alive = false;
    };
  }, [state?.result, workKeyParam, resolveRetryKey]);

  useEffect(() => {
    if (!result) return;
    let alive = true;
    void fetchBookDetails(result).then((enriched) => {
      if (alive) setResult(enriched);
    }).catch(() => { /* keep the un-enriched result */ });
    const subj = result.subjects[0] || 'fiction';
    void fetchBooksBySubject(subj, 12).then((list) => {
      if (alive) setSimilar(list.filter((b) => b.workKey !== result.workKey).slice(0, 10));
    }).catch(() => { /* no similar books available offline */ });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [result?.workKey]);

  if (!result) {
    return (
      <div style={{ height: '100%', background: BookColors.black, color: BookColors.white, display: 'grid', placeItems: 'center' }}>
        <div style={{ textAlign: 'center', padding: 24 }}>
          {resolving ? (
            <>
              <div style={{ width: 34, height: 34, borderRadius: '50%', border: `3px solid ${withAlpha(AppColors.roseQuartz, 0.25)}`, borderTopColor: AppColors.roseQuartz, margin: '0 auto 14px', animation: 'spin 900ms linear infinite' }} />
              <div style={{ fontFamily: Fonts.display, fontSize: 21 }}>Opening this book…</div>
            </>
          ) : (
            <>
              <Icon name={resolveError ? 'cloud_off' : 'menu_book'} size={34} color={withAlpha(AppColors.roseQuartz, 0.8)} />
              <div style={{ fontFamily: Fonts.display, fontSize: 21, marginTop: 12 }}>
                {resolveError ? 'We couldn’t open that book' : 'Pick a book from the shelf first'}
              </div>
              <div style={{ fontSize: 13, color: BookColors.muted, marginTop: 6 }}>
                {resolveError ? 'The catalogue may be offline. Try again or browse the shelves.' : 'Find a book in the library and open its page.'}
              </div>
              {resolveError && (
                <button type="button" className="bare-button" onClick={() => setResolveRetryKey((k) => k + 1)} style={{ marginTop: 16, padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>
                  Try again
                </button>
              )}
              <button type="button" className="bare-button" onClick={() => (canPop() ? navigate(-1) : navigate('/books'))} style={{ marginTop: resolveError ? 8 : 16, padding: '10px 20px', borderRadius: 20, background: withAlpha(BookColors.card, 0.8), border: `1px solid ${withAlpha(BookColors.rose, 0.25)}`, color: BookColors.white, fontWeight: 700 }}>
                Browse Books
              </button>
            </>
          )}
        </div>
      </div>
    );
  }

  const item = state?.saved ?? searchResultToBookItem(result);
  const inReadlist = readlist.find((b) => b.workKey === item.workKey);
  const isLoved = favorites.some((b) => b.workKey === item.workKey);
  const ourBooksKey = item.workKey || (item.iaId ? `ia:${item.iaId}` : '');
  const inOurBooks = Boolean(ourBooksKey) && ourBooks.some((b) => b.workKey === ourBooksKey);
  const hasReadable = buildReadCandidates(item).length > 0 || Boolean(item.iaId) || result.gutenbergId > 0;
  const metaLine = [result.filetype || result.year, result.language || result.sourceLabel].filter(Boolean).join(' · ');
  const downloads = Object.entries(result.downloadUrls ?? {});
  const detailRows: [string, string][] = [
    ['Category', result.categories[0] || result.subjects.slice(0, 2).join(' · ')],
    ['Reading', hasReadable ? 'Available in app' : 'External edition'],
    ['Language', result.language],
    ['File', (result.filetype || (hasReadable ? 'EPUB' : '')).toUpperCase()],
    ['Source', result.sourceLabel],
    ['Year', result.year],
  ].filter(([, v]) => Boolean(v)) as [string, string][];

  const runAction = (work: Promise<unknown>) => {
    setActionError(false);
    void work.catch(() => {
      setActionError(true);
      window.setTimeout(() => setActionError(false), 3000);
    });
  };

  const copyShare = () => {
    const url = result.gutenbergId > 0
      ? `https://www.gutenberg.org/ebooks/${result.gutenbergId}`
      : result.iaId
        ? `https://archive.org/details/${result.iaId}`
        : `https://openlibrary.org${item.workKey}`;
    if (navigator.clipboard?.writeText) {
      void navigator.clipboard.writeText(`${url}\n${item.title}`).then(() => {
        setShareToast(true);
        window.setTimeout(() => setShareToast(false), 2200);
      });
    }
  };

  return (
    <div style={{ position: 'relative', height: '100%', overflowY: 'auto', background: BookColors.black, color: BookColors.white, paddingBottom: 80 }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: BookColors.amber, alignment: [0, -0.3], size: 0.9, opacity: 0.16 },
          { color: BookColors.deepRose, alignment: [0, 0.2], size: 0.9, opacity: 0.06 },
        ]}
      />
      {addedToast && (
        <div
          role="status"
          aria-live="polite"
          style={{
            position: 'absolute', top: 12, left: '50%', transform: 'translateX(-50%)', zIndex: 5,
            padding: '10px 18px', borderRadius: 22, background: withAlpha(AppColors.success, 0.18),
            border: `1px solid ${withAlpha(AppColors.success, 0.5)}`, color: AppColors.petalWhite,
            fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap',
          }}
        >
          Added to Our Books
        </div>
      )}
      {shareToast && (
        <div role="status" aria-live="polite" style={{ position: 'absolute', top: 12, left: '50%', transform: 'translateX(-50%)', zIndex: 5, padding: '10px 18px', borderRadius: 22, background: withAlpha(AppColors.deepRose, 0.9), color: '#FFF', fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap' }}>
          Link copied
        </div>
      )}
      {actionError && (
        <div role="alert" style={{ position: 'absolute', top: 12, left: '50%', transform: 'translateX(-50%)', zIndex: 6, padding: '10px 18px', borderRadius: 22, background: withAlpha(AppColors.error, 0.9), color: '#FFF', fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap' }}>
          Couldn’t save that change — try again
        </div>
      )}
      {confirmRemove && (
        <div onClick={() => setConfirmRemove(false)} style={{ position: 'fixed', inset: 0, zIndex: 96, background: 'rgba(0,0,0,0.72)', display: 'grid', placeItems: 'center', padding: 24 }}>
          <div ref={confirmRemoveRef} role="dialog" aria-modal="true" aria-label="Remove from Our Books" tabIndex={-1} onClick={(e) => e.stopPropagation()} style={{ width: '100%', maxWidth: 380, padding: 22, borderRadius: 20, background: AppColors.shimmerBase, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.18)}` }}>
            <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700, color: AppColors.petalWhite }}>Remove from Our Books?</div>
            <div style={{ fontSize: 13.5, color: AppColors.mutedPurple, marginTop: 8 }}>“{result.title}” will leave the shelf you share.</div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>
              <button type="button" className="bare-button" onClick={() => setConfirmRemove(false)} style={{ flex: 1, minHeight: 46, borderRadius: 14, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.25)}`, color: AppColors.petalWhite, fontWeight: 700 }}>Keep it</button>
              <button type="button" className="bare-button" onClick={() => { runAction(removeFromOurBooks(ourBooksKey)); setConfirmRemove(false); }} style={{ flex: 1, minHeight: 46, borderRadius: 14, background: AppColors.error, color: '#FFF', fontWeight: 700 }}>Remove</button>
            </div>
          </div>
        </div>
      )}
      <div style={{ position: 'relative', padding: '14px 20px 0', paddingTop: 'calc(14px + env(safe-area-inset-top, 0px))' }}>
        <ShelfIconButton icon="arrow_back_ios_new" label="Back" size={40} onClick={() => (canPop() ? navigate(-1) : navigate('/books'))} />

        <div style={{ display: width >= 900 ? 'grid' : 'block', gridTemplateColumns: width >= 900 ? '300px minmax(0, 1fr)' : undefined, gap: 32, maxWidth: 1180, margin: '0 auto' }}>
        <div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginTop: 10 }}>
          <BookCover width={168} imageUrl={result.coverUrl} title={result.title} author={result.author} radius={10} eager />
          <h1 style={{ fontFamily: Fonts.display, fontSize: 28, fontWeight: 900, lineHeight: 1.1, margin: '22px 0 0' }}>{result.title}</h1>
          {result.author && (
            <button
              type="button"
              className="bare-button"
              onClick={() => navigate('/books', { state: { query: result.author } })}
              style={{ marginTop: 8, fontSize: 14, color: withAlpha(BookColors.rose, 0.9), textDecoration: 'underline', textDecorationColor: withAlpha(BookColors.rose, 0.35) }}
            >
              {result.author}
            </button>
          )}
          {metaLine && <div style={{ fontSize: 12, color: BookColors.muted, marginTop: 8 }}>{metaLine}</div>}
          {(result.rating || result.ratingCount) && (
            <div style={{ fontSize: 12, fontWeight: 700, color: BookColors.amber, marginTop: 8 }}>
              {result.rating ? `★ ${result.rating.toFixed(1)} · ` : ''}{result.ratingCount ? `${result.ratingCount.toLocaleString()} downloads` : `${result.ratingsCount?.toLocaleString() ?? ''} ratings`}
            </div>
          )}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 22 }}>
          {hasReadable && (
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => navigate(`/books/reader?workKey=${encodeURIComponent(item.workKey)}`, { state: { book: item } })}
                style={{
                  flex: 3,
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                  padding: '13px 16px',
                  borderRadius: 14,
                  background: BookColors.white,
                  color: BookColors.black,
                  fontWeight: 700,
                  fontSize: 15,
                }}
              >
                <Icon name="auto_stories" size={19} color={BookColors.black} /> Read
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={() => navigate(`/books/listen?workKey=${encodeURIComponent(item.workKey)}`, { state: { book: item, listen: true } })}
                style={{
                  flex: 2,
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                  padding: '13px 16px',
                  borderRadius: 14,
                  background: 'rgba(255,255,255,0.03)',
                  border: `1px solid ${withAlpha(BookColors.rose, 0.25)}`,
                  color: BookColors.white,
                  fontWeight: 700,
                  fontSize: 14.5,
                }}
              >
                <Icon name="headphones" size={18} color={BookColors.white} /> Listen
              </button>
            </div>
          )}
          {downloads.length > 0 && (
            <button
              type="button"
              className="bare-button"
              onClick={() => {
                void recordBookDownload(item, downloads[0][0], userName);
                window.open(downloads[0][1], '_blank', 'noopener');
              }}
              style={{
                width: '100%',
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 8,
                padding: '12px 16px',
                borderRadius: 14,
                background: hasReadable ? 'rgba(255,255,255,0.03)' : BookColors.deepRose,
                border: `1px solid ${withAlpha(BookColors.rose, hasReadable ? 0.25 : 0.6)}`,
                color: BookColors.white,
                fontWeight: 700,
                fontSize: 14,
              }}
            >
              <Icon name="download" size={18} color={BookColors.white} /> Download {downloads[0][0].toUpperCase()}
            </button>
          )}
          {hasReadable && (
            <button type="button" className="bare-button" onClick={() => navigate(`/books/reader?workKey=${encodeURIComponent(item.workKey)}&sample=1`, { state: { book: item, sample: true } })} style={{ minHeight: 44, borderRadius: 14, border: `1px solid ${withAlpha(BookColors.rose, 0.3)}`, color: BookColors.white, fontWeight: 700, fontSize: 13 }}>
              Read a sample
            </button>
          )}
          {!hasReadable && downloads.length === 0 && (
            <div style={{ padding: 16, borderRadius: 16, background: withAlpha(BookColors.card, 0.6), border: `1px solid ${withAlpha(BookColors.rose, 0.12)}`, textAlign: 'center' }}>
              <div style={{ fontSize: 13.5, fontWeight: 700, color: BookColors.white }}>Not readable in the app yet</div>
              <div style={{ fontSize: 12, color: BookColors.muted, marginTop: 4 }}>This edition has no free text or download we can open.</div>
              <button type="button" className="bare-button" onClick={() => navigate('/books', { state: { query: item.title } })} style={{ marginTop: 12, minHeight: 42, padding: '0 18px', borderRadius: 14, background: withAlpha(BookColors.deepRose, 0.22), border: `1px solid ${withAlpha(BookColors.rose, 0.35)}`, color: BookColors.white, fontWeight: 700, fontSize: 12.5 }}>
                Find another edition
              </button>
            </div>
          )}
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-evenly', alignItems: 'center', marginTop: 22 }}>
          <DetailActionCircle
            icon={inReadlist ? 'bookmark' : 'bookmark_outline'}
            label={inReadlist ? 'Saved' : 'Save'}
            active={Boolean(inReadlist)}
            onClick={() => {
              if (inReadlist) runAction(removeFromReadList(item.workKey, userName));
              else runAction(saveToReadList(item, 'to-read', userName));
            }}
          />
          {inReadlist && (
            <DetailActionCircle
              icon="check_circle"
              label={isBookRead(inReadlist.status) ? 'Read' : 'Mark read'}
              active={isBookRead(inReadlist.status)}
              onClick={() => runAction(saveToReadList(item, isBookRead(inReadlist.status) ? 'to-read' : 'read-self', userName))}
            />
          )}
          <DetailActionCircle
            icon={isLoved ? 'favorite' : 'favorite_border'}
            label={isLoved ? 'Loved' : 'Love'}
            active={isLoved}
            onClick={() => runAction(toggleBookFavorite(item, userName, !isLoved))}
          />
          {isCoupleUser && (
            <DetailActionCircle
              icon={inOurBooks ? 'check' : 'volunteer_activism'}
              label={inOurBooks ? 'In Our Books' : 'Our Books'}
              active={inOurBooks}
              onClick={() => {
                if (inOurBooks) {
                  setConfirmRemove(true);
                } else {
                  runAction(addToOurBooks(item, userName).then(() => {
                    setAddedToast(true);
                    window.setTimeout(() => setAddedToast(false), 2600);
                  }));
                }
              }}
            />
          )}
          <DetailActionCircle icon="ios_share" label="Share" onClick={copyShare} />
        </div>

        </div>
        <div>
        {result.description && (
          <div style={{ marginTop: 22, maxWidth: '66ch' }}>
            <p className={descExpanded ? '' : 'clamp-3'} style={{ fontSize: 14, lineHeight: 1.65, color: withAlpha(BookColors.white, 0.85), margin: 0 }}>
              {result.description}
            </p>
            {result.description.length > 180 && (
              <button type="button" className="bare-button" onClick={() => setDescExpanded((v) => !v)} style={{ marginTop: 6, fontSize: 12.5, fontWeight: 700, color: BookColors.rose }}>
                {descExpanded ? 'Show less' : 'Read more'}
              </button>
            )}
          </div>
        )}

        {(detailRows.length > 0 || result.subjects.length > 0) && (
          <div
            style={{
              marginTop: 22,
              padding: '14px 16px',
              borderRadius: 16,
              background: withAlpha(BookColors.card, 0.6),
              border: `1px solid ${withAlpha(BookColors.rose, 0.1)}`,
            }}
          >
            <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: 1.6, color: BookColors.muted, marginBottom: 10 }}>DETAILS</div>
            {detailRows.map(([k, v]) => (
              <div key={k} style={{ display: 'flex', alignItems: 'flex-start', padding: '5px 0' }}>
                <span style={{ width: 96, flexShrink: 0, fontSize: 12.5, color: BookColors.muted }}>{k}</span>
                <span style={{ flex: 1, fontSize: 12.5, fontWeight: 700, color: BookColors.white }}>{v}</span>
              </div>
            ))}
            {result.subjects.length > 0 && (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
                {result.subjects.map((s) => (
                  <span key={s} style={{ padding: '4px 10px', borderRadius: 99, background: BookColors.black, border: `1px solid ${withAlpha(BookColors.rose, 0.14)}`, fontSize: 11.5, color: BookColors.muted }}>
                    {s}
                  </span>
                ))}
              </div>
            )}
          </div>
        )}

        {similar.length > 0 && (
          <div style={{ marginTop: 28 }}>
            <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 800, color: BookColors.white, marginBottom: 14 }}>More like this</div>
            <div className="no-scrollbar" style={{ display: 'flex', gap: 14, overflowX: 'auto' }}>
              {similar.map((b) => (
                <BookCoverCard
                  key={b.workKey || b.title}
                  width={width >= 700 ? 132 : 112}
                  result={b}
                  onClick={() => navigate(`/books/detail?workKey=${encodeURIComponent(b.workKey)}`, { state: { result: b } })}
                />
              ))}
            </div>
          </div>
        )}
        </div>
        </div>
      </div>
    </div>
  );
}

function DetailActionCircle({ icon, label, active, onClick }: { icon: string; label: string; active?: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}
    >
      <div
        style={{
          width: 46,
          height: 46,
          borderRadius: '50%',
          background: active ? withAlpha(BookColors.deepRose, 0.22) : withAlpha(BookColors.card, 0.8),
          border: `1px solid ${active ? BookColors.deepRose : withAlpha(BookColors.rose, 0.2)}`,
          display: 'grid',
          placeItems: 'center',
        }}
      >
        <Icon name={icon} size={20} color={active ? BookColors.deepRose : BookColors.white} />
      </div>
      <span style={{ fontSize: 11.5, color: active ? BookColors.rose : BookColors.muted, fontWeight: 600 }}>{label}</span>
    </button>
  );
}

export function BookListPage() {
  const { width } = useViewport();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { kind?: 'popular' | 'recent' | 'category'; title?: string; category?: BookCategory; initialResults?: BookSearchResult[] } | null) ?? {};
  const params = new URLSearchParams(location.search);
  const subjectParam = params.get('subject');
  const kindParam = params.get('kind') as 'popular' | 'recent' | null;
  const effectiveCategory: BookCategory | undefined = state.category ?? (subjectParam ? { name: subjectParam, query: subjectParam, icon: 'menu_book', color: AppColors.warmAmber } : undefined);
  const effectiveKind = state.kind ?? kindParam ?? 'popular';

  const PAGE = 30;
  const [results, setResults] = useState<BookSearchResult[]>(state.initialResults ?? []);
  const [loading, setLoading] = useState(!state.initialResults?.length);
  const [loadingMore, setLoadingMore] = useState(false);
  const [offset, setOffset] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [listError, setListError] = useState(false);
  const [listRetryKey, setListRetryKey] = useState(0);

  const fetchPage = (start: number): Promise<BookSearchResult[]> =>
    effectiveCategory
      ? fetchBooksBySubject(effectiveCategory.query, PAGE, start)
      : effectiveKind === 'recent'
        ? fetchRecentBooks(PAGE, start)
        : fetchPopularBooks(PAGE, start);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setListError(false);
    setOffset(0);
    setHasMore(true);
    if (state.initialResults?.length) {
      setResults(state.initialResults);
      setHasMore(false);
      setLoading(false);
      return;
    }
    void fetchPage(0)
      .then((res) => {
        if (!alive) return;
        setResults(res);
        setHasMore(res.length >= PAGE);
        setListError(res.length === 0 && catalogFailedRecently());
        setLoading(false);
      })
      .catch(() => {
        if (!alive) return;
        setListError(true);
        setLoading(false);
      });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [effectiveKind, effectiveCategory, state.initialResults, listRetryKey]);

  const loadMore = async () => {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    const next = offset + PAGE;
    try {
      const res = await fetchPage(next);
      setResults((prev) => {
        const seen = new Set(prev.map((r) => r.workKey));
        return [...prev, ...res.filter((r) => !seen.has(r.workKey))];
      });
      setOffset(next);
      setHasMore(res.length >= PAGE);
      setListError(false);
    } catch {
      setListError(true);
    } finally {
      setLoadingMore(false);
    }
  };

  const title = effectiveCategory?.name ?? state.title ?? (effectiveKind === 'recent' ? 'Recently Added' : 'Most Popular');
  const eyebrow =
    effectiveCategory != null
      ? 'BROWSE BY CATEGORY'
      : effectiveKind === 'recent'
        ? 'FRESH IN THE CATALOG'
        : 'TRENDING THIS WEEK';
  const cols = width >= 1024 ? 7 : width >= 600 ? 5 : 3;

  return (
    <div style={{ position: 'relative', height: '100%', background: BookColors.black, color: BookColors.white, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: AppColors.warmAmber, alignment: [-0.7, -0.85], size: 0.85, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.85, 0.95], size: 0.8, opacity: 0.10 },
        ]}
      />
      <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '14px 20px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <ShelfIconButton icon="arrow_back_ios_new" label="Back" tooltip="Back" onClick={() => (canPop() ? navigate(-1) : navigate('/books'))} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <h1 style={{ fontFamily: Fonts.display, fontSize: 26, fontWeight: 700, margin: 0, color: BookColors.white, lineHeight: 1.1 }}>{title}</h1>
            <div style={{ fontFamily: Fonts.body, fontWeight: 700, fontSize: 11, color: BookColors.muted, letterSpacing: 1.8, marginTop: 2 }}>
              {eyebrow}
            </div>
          </div>
          {results.length > 0 && (
            <span
              style={{
                padding: '6px 12px',
                borderRadius: 20,
                background: withAlpha(BookColors.deepRose, 0.15),
                border: `1px solid ${withAlpha(BookColors.deepRose, 0.3)}`,
                fontFamily: Fonts.body,
                color: BookColors.deepRose,
                fontWeight: 800,
                fontSize: 14,
              }}
            >
              {results.length}
            </span>
          )}
        </div>

        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 20px 40px' }}>
          {loading && results.length === 0 ? (
            <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: '18px 14px' }}>
              {Array.from({ length: 9 }, (_, i) => (
                <div key={i}>
                  <div className="skeleton-pulse" style={{ width: '100%', aspectRatio: '2 / 3', borderRadius: 10, background: AppColors.shimmerBase }} />
                  <div className="skeleton-pulse" style={{ height: 11, borderRadius: 5, background: AppColors.shimmerBase, marginTop: 10, width: '85%' }} />
                  <div className="skeleton-pulse" style={{ height: 9, borderRadius: 5, background: AppColors.shimmerBase, marginTop: 6, width: '60%' }} />
                </div>
              ))}
            </div>
          ) : results.length === 0 ? (
            <div style={{ padding: '72px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
              <div style={{ width: 68, height: 68, borderRadius: '50%', background: withAlpha(AppColors.deepRose, 0.12), border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.15)}`, display: 'grid', placeItems: 'center' }}>
                <Icon name={listError ? 'cloud_off' : 'menu_book'} size={30} color={withAlpha(AppColors.roseQuartz, 0.8)} />
              </div>
              <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700, color: BookColors.white, marginTop: 16 }}>
                {listError ? 'Couldn’t reach the catalogue' : 'Nothing on this shelf yet'}
              </div>
              <div style={{ fontSize: 13, color: BookColors.muted, marginTop: 6 }}>
                {listError ? 'Check your connection and try again.' : 'Try another shelf or search for a book.'}
              </div>
              <button type="button" className="bare-button" onClick={() => (listError ? setListRetryKey((k) => k + 1) : navigate('/books'))} style={{ marginTop: 18, minHeight: 44, padding: '0 20px', borderRadius: 14, background: AppColors.deepRose, color: '#FFF', fontWeight: 700, fontSize: 13 }}>
                {listError ? 'Try again' : 'Back to Books'}
              </button>
            </div>
          ) : (
            <>
              <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: '18px 14px' }}>
                {results.map((r) => (
                  <BookCoverCard
                    key={r.workKey || r.title}
                    width={Math.floor((width - 40 - (cols - 1) * 14) / cols)}
                    result={r}
                    onClick={() => navigate('/books/detail', { state: { result: r } })}
                  />
                ))}
              </div>
              {hasMore && results.length > 0 && (
                <button
                  type="button"
                  className="bare-button"
                  disabled={loadingMore}
                  onClick={() => void loadMore()}
                  style={{ display: 'block', margin: '24px auto 0', minHeight: 46, padding: '0 26px', borderRadius: 24, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.3)}`, color: AppColors.petalWhite, fontWeight: 700, fontSize: 13, opacity: loadingMore ? 0.6 : 1 }}
                >
                  {loadingMore ? 'Loading…' : 'Load more'}
                </button>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export function BookCategoriesPage() {
  const { width } = useViewport();
  const navigate = useNavigate();
  const cols = width >= 1024 ? 4 : width >= 600 ? 3 : 2;

  return (
    <div style={{ position: 'relative', height: '100%', background: BookColors.black, color: BookColors.white, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <ShelfAtmosphericBackdrop
        glows={[
          { color: AppColors.warmAmber, alignment: [-0.7, -0.85], size: 0.85, opacity: 0.14 },
          { color: AppColors.deepRose, alignment: [0.85, 0.95], size: 0.8, opacity: 0.10 },
        ]}
      />
      <div style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '14px 20px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <ShelfIconButton icon="arrow_back_ios_new" label="Back" tooltip="Back" onClick={() => (canPop() ? navigate(-1) : navigate('/books'))} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <h1 style={{ fontFamily: Fonts.display, fontSize: 26, fontWeight: 700, margin: 0, color: BookColors.white, lineHeight: lineHeight(26) }}>
              Categories
            </h1>
            <div style={{ fontFamily: Fonts.body, fontWeight: 700, fontSize: 11, color: BookColors.muted, letterSpacing: 1.8, marginTop: 2 }}>
              PICK A SHELF
            </div>
          </div>
        </div>
        <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 20px 40px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 12 }}>
            {BOOK_CATEGORIES.map((cat) => (
              <button
                key={cat.query}
                type="button"
                className="bare-button"
                onClick={() => navigate(`/books/category?subject=${encodeURIComponent(cat.query)}`, { state: { category: cat } })}
                style={{
                  aspectRatio: '1.15',
                  borderRadius: 20,
                  background: withAlpha(BookColors.card, 0.6),
                  border: `1px solid ${withAlpha(cat.color, 0.25)}`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  padding: '0 8px',
                }}
              >
                <div
                  style={{
                    width: 48,
                    height: 48,
                    borderRadius: '50%',
                    background: withAlpha(cat.color, 0.15),
                    border: `1px solid ${withAlpha(cat.color, 0.4)}`,
                    display: 'grid',
                    placeItems: 'center',
                  }}
                >
                  <Icon name={cat.icon} size={22} color={cat.color} />
                </div>
                <div
                  style={{
                    marginTop: 10,
                    fontFamily: Fonts.body,
                    fontWeight: 600,
                    fontSize: 13,
                    lineHeight: 1.2,
                    textAlign: 'center',
                    color: BookColors.white,
                    whiteSpace: 'normal',
                    overflow: 'hidden',
                    maxWidth: '100%',
                  }}
                >
                  {cat.name}
                </div>
                <div style={{ marginTop: 2, fontFamily: Fonts.body, fontSize: 10, color: BookColors.muted }}>
                  Browse
                </div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
