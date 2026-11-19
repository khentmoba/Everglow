import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { WebTts } from '../../core/system/webTts';
import { AppColors, ReaderPaper, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
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
  fetchBookText,
  fetchPopularBooks,
  fetchRecentBooks,
  recordBookDownload,
  removeFromOurBooks,
  resolveBookByWorkKey,
  saveReaderState,
  saveToReadList,
  toggleBookFavorite,
  watchBookFavorites,
  watchReaderState,
  watchOurBooks,
  watchReadList,
} from './booksService';
import { BookCover, BookCoverCard } from './BookCover';
import {
  DEFAULT_READER_SETTINGS,
  loadBookmarks,
  loadHighlights,
  loadProgress,
  loadSettings,
  removeHighlight,
  replaceBookmarks,
  replaceHighlights,
  saveHighlight,
  saveProgress,
  saveSettings,
  toggleBookmark,
  type ReaderFont,
  type ReaderHighlight,
  type ReaderSettings,
  type ReaderTheme,
} from './readerPrefs';

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
  const [descExpanded, setDescExpanded] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const userName = currentUser ?? '';
  const readlist = useSource(() => watchReadList(userName), [userName], []);
  const favorites = useSource(() => watchBookFavorites(userName), [userName], []);
  const ourBooks = useSource(() => watchOurBooks(300), [], []);

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
    });
    const subj = result.subjects[0] || 'fiction';
    void fetchBooksBySubject(subj, 12).then((list) => {
      if (alive) setSimilar(list.filter((b) => b.workKey !== result.workKey).slice(0, 10));
    });
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
    ['Source ID', result.gutenbergId > 0 ? String(result.gutenbergId) : ''],
  ].filter(([, v]) => Boolean(v)) as [string, string][];

  const copyShare = () => {
    const url = result.gutenbergId > 0
      ? `https://www.gutenberg.org/ebooks/${result.gutenbergId}`
      : result.iaId
        ? `https://archive.org/details/${result.iaId}`
        : `https://openlibrary.org${item.workKey}`;
    void navigator.clipboard?.writeText(`${url}\n${item.title}`).then(() => {
      setShareToast(true);
      window.setTimeout(() => setShareToast(false), 2200);
    });
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
      {confirmRemove && (
        <div onClick={() => setConfirmRemove(false)} style={{ position: 'fixed', inset: 0, zIndex: 96, background: 'rgba(0,0,0,0.72)', display: 'grid', placeItems: 'center', padding: 24 }}>
          <div role="dialog" aria-modal="true" aria-label="Remove from Our Books" tabIndex={-1} onClick={(e) => e.stopPropagation()} style={{ width: '100%', maxWidth: 380, padding: 22, borderRadius: 20, background: AppColors.shimmerBase, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.18)}` }}>
            <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700, color: AppColors.petalWhite }}>Remove from Our Books?</div>
            <div style={{ fontSize: 13.5, color: AppColors.mutedPurple, marginTop: 8 }}>“{result.title}” will leave the shelf you share.</div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>
              <button type="button" className="bare-button" onClick={() => setConfirmRemove(false)} style={{ flex: 1, minHeight: 46, borderRadius: 14, border: `1px solid ${withAlpha(AppColors.roseQuartz, 0.25)}`, color: AppColors.petalWhite, fontWeight: 700 }}>Keep it</button>
              <button type="button" className="bare-button" onClick={() => { void removeFromOurBooks(ourBooksKey); setConfirmRemove(false); }} style={{ flex: 1, minHeight: 46, borderRadius: 14, background: AppColors.error, color: '#FFF', fontWeight: 700 }}>Remove</button>
            </div>
          </div>
        </div>
      )}
      <div style={{ position: 'relative', padding: '14px 20px 0' }}>
        <ShelfIconButton icon="arrow_back_ios_new" label="Back" size={40} onClick={() => (canPop() ? navigate(-1) : navigate('/books'))} />

        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginTop: 10 }}>
          <BookCover width={168} imageUrl={result.coverUrl} title={result.title} author={result.author} radius={10} />
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
          {result.ratingCount ? (
            <div style={{ fontSize: 12, fontWeight: 700, color: BookColors.amber, marginTop: 8 }}>{result.ratingCount} readers</div>
          ) : null}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 22 }}>
          {hasReadable && (
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="button"
                className="bare-button"
                onClick={() => navigate('/books/reader', { state: { book: item } })}
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
                onClick={() => navigate('/books/listen', { state: { book: item, listen: true } })}
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
          {isCoupleUser && (
            <>
              <DetailActionCircle
                icon={inReadlist ? 'bookmark' : 'bookmark_outline'}
                label={isBookRead(inReadlist?.status ?? '') ? 'Read' : inReadlist ? 'Saved' : 'Save'}
                active={Boolean(inReadlist)}
                onClick={() => void saveToReadList(item, inReadlist?.status === 'to-read' ? 'read-self' : 'to-read', userName)}
              />
              <DetailActionCircle
                icon={isLoved ? 'favorite' : 'favorite_border'}
                label={isLoved ? 'Loved' : 'Love'}
                active={isLoved}
                onClick={() => void toggleBookFavorite(item, userName, !isLoved)}
              />
              <DetailActionCircle
                icon={inOurBooks ? 'check' : 'volunteer_activism'}
                label={inOurBooks ? 'In Our Books' : 'Our Books'}
                active={inOurBooks}
                onClick={() => {
                  if (inOurBooks) {
                    setConfirmRemove(true);
                  } else {
                    void addToOurBooks(item, userName).then(() => {
                      setAddedToast(true);
                      window.setTimeout(() => setAddedToast(false), 2600);
                    });
                  }
                }}
              />
            </>
          )}
          <DetailActionCircle icon="ios_share" label="Share" onClick={copyShare} />
        </div>

        {result.description && (
          <div style={{ marginTop: 22 }}>
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
                  onClick={() => navigate('/books/detail', { state: { result: b } })}
                />
              ))}
            </div>
          </div>
        )}
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

type BookChapter = { title: string; body: string };

function stripGutenbergBoilerplate(raw: string): string {
  const startMatch = /\*\*\*\s*START OF (?:THE|THIS)?\s*PROJECT[^\n]*\n?/i.exec(raw);
  const endMatch = /\*\*\*\s*END OF (?:THE|THIS)?\s*PROJECT/i.exec(raw);
  if (!startMatch || !endMatch || endMatch.index <= startMatch.index) return raw;
  return raw.slice(startMatch.index + startMatch[0].length, endMatch.index);
}

function splitBookChapters(raw: string, fallbackTitle: string): BookChapter[] {
  const cleaned = stripGutenbergBoilerplate(raw).replace(/\r\n/g, '\n');
  const explicitRe = /^(?:CHAPTER|Chapter|PART|Part|BOOK|Book|PROLOGUE|EPILOGUE|Act|ACT)\s+(?:[IVXLCDM]+|\d+|[A-Za-z]+)(?:[.: \t]+[^\n]*)?$/gm;
  const matches = [...cleaned.matchAll(explicitRe)];
  if (matches.length >= 2) {
    const out: BookChapter[] = [];
    for (let i = 0; i < matches.length; i++) {
      const start = matches[i].index ?? 0;
      const end = i + 1 < matches.length ? (matches[i + 1].index ?? cleaned.length) : cleaned.length;
      const slice = cleaned.slice(start, end);
      const nl = slice.indexOf('\n');
      const title = (nl >= 0 ? slice.slice(0, nl) : slice).trim();
      const body = (nl >= 0 ? slice.slice(nl + 1) : '').trim();
      if (body) out.push({ title, body });
    }
    if (out.length >= 2) return out;
  }
  const starParts = cleaned.split(/^\s*\*{3,}\s*$/m).map((s) => s.trim()).filter(Boolean);
  if (starParts.length >= 2) {
    return starParts.map((body, idx) => {
      const firstLine = body.split('\n').find((l) => l.trim() !== '')?.trim() ?? `Section ${idx + 1}`;
      return { title: firstLine.length > 64 ? `${firstLine.slice(0, 64)}…` : firstLine, body };
    });
  }
  return [{ title: fallbackTitle, body: cleaned.trim() }];
}

const TTS_RATES = [0.85, 1, 1.25, 1.5, 1.75, 2] as const;

const FONT_FAMILIES: Record<ReaderFont, string> = {
  classic: Fonts.display,
  modern: Fonts.reading,
  soft: Fonts.body,
};

const THEME_TOKENS: Record<ReaderTheme, { bg: string; fg: string }> = {
  dark: { bg: ReaderPaper.dark, fg: ReaderPaper.darkText },
  sepia: { bg: ReaderPaper.sepia, fg: ReaderPaper.sepiaText },
  light: { bg: ReaderPaper.light, fg: ReaderPaper.lightText },
};

/** Reflow Gutenberg's hard-wrapped lines into paragraphs that can be read. */
function toParagraphs(body: string): string[] {
  return body
    .split(/\n\s*\n/)
    .map((part) => part.replace(/\s*\n\s*/g, ' ').replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

function renderHighlighted(text: string, marks: ReaderHighlight[], accent: string, onPick: (h: ReaderHighlight) => void): ReactNode {
  const found = marks
    .map((h) => ({ h, idx: text.indexOf(h.text) }))
    .filter((x) => x.idx >= 0)
    .sort((a, b) => a.idx - b.idx);
  if (found.length === 0) return text;
  const first = found[0];
  return (
    <>
      {text.slice(0, first.idx)}
      <mark
        onClick={() => onPick(first.h)}
        style={{ background: withAlpha(accent, 0.32), color: 'inherit', borderRadius: 3, padding: '0 2px', cursor: 'pointer' }}
        title={first.h.note || 'Highlight — tap to add a note'}
      >
        {first.h.text}
      </mark>
      {renderHighlighted(text.slice(first.idx + first.h.text.length), marks, accent, onPick)}
    </>
  );
}

export function BookReaderPage({ startListening = false }: { startListening?: boolean }) {
  const navigate = useNavigate();
  const location = useLocation();
  const workKeyParam = new URLSearchParams(location.search).get('workKey');
  const [book, setBook] = useState<BookItem | null>((location.state as { book?: BookItem } | null)?.book ?? null);
  const [readerResolveError, setReaderResolveError] = useState(false);
  const [readerRetryKey, setReaderRetryKey] = useState(0);
  const { currentUser } = useAuth();
  const synced = useSource(
    () => watchReaderState(currentUser ?? '', book?.workKey ?? ''),
    [currentUser ?? '', book?.workKey ?? ''],
    { progress: null, bookmarks: [], highlights: [] },
  );

  const [settings, setSettings] = useState<ReaderSettings>(() => loadSettings());
  const [chapters, setChapters] = useState<BookChapter[]>([]);
  const [chapterIdx, setChapterIdx] = useState(0);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [speaking, setSpeaking] = useState(false);
  const [paused, setPaused] = useState(false);
  const [followChar, setFollowChar] = useState(-1);
  const [sleepMinutes, setSleepMinutes] = useState(0);
  const [scrollPct, setScrollPct] = useState(0);
  const [bookmarks, setBookmarks] = useState<ReturnType<typeof loadBookmarks>>([]);
  const [highlights, setHighlights] = useState<ReturnType<typeof loadHighlights>>([]);
  const [selectionText, setSelectionText] = useState('');
  const [noteFor, setNoteFor] = useState<string | null>(null);
  const [noteDraft, setNoteDraft] = useState('');
  const [searchOpen, setSearchOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [chromeHidden, setChromeHidden] = useState(false);
  const [bookSearch, setBookSearch] = useState('');
  const [pendingJump, setPendingJump] = useState('');

  const scrollRef = useRef<HTMLDivElement>(null);
  const settingsPanelRef = useRef<HTMLDivElement>(null);
  const settingsTriggerRef = useRef<HTMLButtonElement>(null);
  const searchPanelRef = useRef<HTMLDivElement>(null);
  const notePanelRef = useRef<HTMLDivElement>(null);
  const menuPanelRef = useRef<HTMLDivElement>(null);
  const chapterRef = useRef(0);
  const scrollFracRef = useRef(0);
  const lastScrollSaveRef = useRef(0);
  const sleepTimerRef = useRef<number | null>(null);
  const syncedOnceRef = useRef('');
  const remoteSaveRef = useRef<number | null>(null);

  const patchSettings = (patch: Partial<ReaderSettings>) => {
    setSettings((prev) => {
      const next = { ...prev, ...patch };
      saveSettings(next);
      return next;
    });
  };

  const syncState = () => {
    if (!book) return;
    const user = currentUser ?? '';
    const key = book.workKey;
    if (remoteSaveRef.current != null) window.clearTimeout(remoteSaveRef.current);
    remoteSaveRef.current = window.setTimeout(() => {
      void saveReaderState(user, key, {
        progress: loadProgress(key),
        bookmarks: loadBookmarks(key),
        highlights: loadHighlights(key),
      });
    }, 1200);
  };

  const saveProgressNow = (chapter: number, scroll: number) => {
    if (!book) return;
    saveProgress({
      workKey: book.workKey,
      chapter,
      scroll,
      updatedAt: Date.now(),
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      iaId: book.iaId,
      readCandidates: buildReadCandidates(book),
    });
    syncState();
  };

  const stopSpeech = () => {
    WebTts.stop();
    if (sleepTimerRef.current != null) window.clearTimeout(sleepTimerRef.current);
    sleepTimerRef.current = null;
    setSleepMinutes(0);
    setSpeaking(false);
    setPaused(false);
    setFollowChar(-1);
  };

  const startSpeech = (body: string, rate: number) => {
    if (!WebTts.isSupported || body.trim() === '') return;
    WebTts.speak(body, {
      rate,
      onBoundary: (index) => setFollowChar(index),
      onComplete: () => {
        setSpeaking(false);
        setPaused(false);
        setFollowChar(-1);
      },
    });
    setSpeaking(true);
    setPaused(false);
  };

  useEffect(() => {
    if (book || !workKeyParam) return;
    let alive = true;
    setReaderResolveError(false);
    void resolveBookByWorkKey(workKeyParam).then((found) => {
      if (!alive) return;
      if (found) setBook(searchResultToBookItem(found));
      else setReaderResolveError(true);
    });
    return () => {
      alive = false;
    };
  }, [book, workKeyParam, readerRetryKey]);

  useEffect(() => {
    if (!book) return;
    let alive = true;
    const saved = loadProgress(book.workKey);
    const candidates = buildReadCandidates(book);
    if (candidates.length === 0) {
      setLoading(false);
      setError(book.iaId ? null : 'No plain-text source available for this book.');
      return;
    }
    setLoading(true);
    fetchBookText(candidates).then((res) => {
      if (!alive) return;
      if (res.text) {
        const list = splitBookChapters(res.text, book.title);
        const initial = saved && saved.chapter < list.length ? saved.chapter : 0;
        setChapters(list);
        setChapterIdx(initial);
        chapterRef.current = initial;
        setBookmarks(loadBookmarks(book.workKey));
        setHighlights(loadHighlights(book.workKey));
        window.requestAnimationFrame(() => {
          if (!alive || !saved || saved.scroll <= 0 || !scrollRef.current) return;
          const el = scrollRef.current;
          el.scrollTop = saved.scroll * Math.max(0, el.scrollHeight - el.clientHeight);
          scrollFracRef.current = saved.scroll;
        });
        if (startListening && WebTts.isSupported && list[initial]) {
          startSpeech(toParagraphs(list[initial].body).join('\n'), loadSettings().ttsRate);
        }
      } else {
        setError(res.error ?? 'Could not load book text.');
      }
      setLoading(false);
    });
    return () => {
      alive = false;
      WebTts.stop();
      if (sleepTimerRef.current != null) window.clearTimeout(sleepTimerRef.current);
      saveProgressNow(chapterRef.current, scrollFracRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [book, startListening]);

  useDialogFocus(settingsOpen, settingsPanelRef, () => setSettingsOpen(false), settingsTriggerRef);
  useDialogFocus(searchOpen, searchPanelRef, () => setSearchOpen(false));
  useDialogFocus(noteFor != null, notePanelRef, () => setNoteFor(null));
  useDialogFocus(menuOpen, menuPanelRef, () => setMenuOpen(false));

  if (!book) {
    return (
      <div style={{ height: '100%', background: BookColors.black, color: BookColors.white, display: 'grid', placeItems: 'center', padding: 24 }}>
        <div style={{ textAlign: 'center' }}>
          {readerResolveError ? (
            <>
              <Icon name="cloud_off" size={34} color={withAlpha(AppColors.roseQuartz, 0.8)} />
              <div style={{ fontFamily: Fonts.display, fontSize: 21, marginTop: 12 }}>We couldn’t open that book</div>
              <div style={{ fontSize: 13, color: BookColors.muted, marginTop: 6 }}>The catalogue may be offline right now.</div>
              <div style={{ display: 'flex', gap: 8, justifyContent: 'center', marginTop: 18 }}>
                <button type="button" className="bare-button" onClick={() => setReaderRetryKey((k) => k + 1)} style={{ padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>Try again</button>
                <button type="button" className="bare-button" onClick={() => navigate('/books')} style={{ padding: '10px 20px', borderRadius: 20, border: `1px solid ${withAlpha(BookColors.rose, 0.3)}`, color: BookColors.white, fontWeight: 700 }}>Browse Books</button>
              </div>
            </>
          ) : workKeyParam ? (
            <>
              <div style={{ width: 34, height: 34, borderRadius: '50%', border: `3px solid ${withAlpha(AppColors.roseQuartz, 0.25)}`, borderTopColor: AppColors.roseQuartz, margin: '0 auto 14px', animation: 'spin 900ms linear infinite' }} />
              <div style={{ fontFamily: Fonts.display, fontSize: 21 }}>Opening this book…</div>
            </>
          ) : (
            <button type="button" className="bare-button" onClick={() => (canPop() ? navigate(-1) : navigate('/books'))} style={{ padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>Back to Books</button>
          )}
        </div>
      </div>
    );
  }

  const currentChapter = chapters[chapterIdx] ?? null;
  const paragraphs = currentChapter ? toParagraphs(currentChapter.body) : [];
  const speechText = paragraphs.join('\n');
  const theme = THEME_TOKENS[settings.theme];
  const { width: readerWidth } = useViewport();
  const measure = readerWidth >= 820 ? 840 : 680;

  const selectChapter = (nextIdx: number) => {
    if (nextIdx < 0 || nextIdx >= chapters.length) return;
    setChapterIdx(nextIdx);
    chapterRef.current = nextIdx;
    setMenuOpen(false);
    if (scrollRef.current) scrollRef.current.scrollTop = 0;
    scrollFracRef.current = 0;
    saveProgressNow(nextIdx, 0);
    if (speaking && chapters[nextIdx]) startSpeech(toParagraphs(chapters[nextIdx].body).join('\n'), settings.ttsRate);
  };

  const toggleSpeech = () => {
    if (!speaking) {
      if (currentChapter) startSpeech(speechText, settings.ttsRate);
      return;
    }
    if (paused) {
      WebTts.resume();
      setPaused(false);
    } else {
      WebTts.pause();
      setPaused(true);
    }
  };

  const onScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    const max = el.scrollHeight - el.clientHeight;
    scrollFracRef.current = max > 0 ? Math.min(1, el.scrollTop / max) : 0;
    setScrollPct(scrollFracRef.current);
    const now = Date.now();
    if (now - lastScrollSaveRef.current > 700) {
      lastScrollSaveRef.current = now;
      saveProgressNow(chapterRef.current, scrollFracRef.current);
    }
  };

  const overallPct = chapters.length > 0 ? Math.round(((chapterIdx + scrollPct) / chapters.length) * 100) : 0;
  const bookmarked = bookmarks.some((b) => b.chapter === chapterIdx);

  const toggleThisBookmark = () => {
    if (!book) return;
    setBookmarks(toggleBookmark(book.workKey, { chapter: chapterIdx, scroll: scrollFracRef.current, createdAt: Date.now() }));
    syncState();
  };

  const captureSelection = () => {
    const text = window.getSelection()?.toString().replace(/\s+/g, ' ').trim() ?? '';
    if (text.length > 1 && text.length < 500) setSelectionText(text);
  };

  const addHighlight = (note: string) => {
    if (!book || !selectionText) return;
    const highlight: ReaderHighlight = { id: `${Date.now()}`, chapter: chapterIdx, text: selectionText, note, createdAt: Date.now() };
    setHighlights(saveHighlight(book.workKey, highlight));
    syncState();
    setSelectionText('');
    setNoteFor(null);
    setNoteDraft('');
    window.getSelection()?.removeAllRanges();
  };

  const updateNote = (id: string, note: string) => {
    if (!book) return;
    const existing = highlights.find((h) => h.id === id);
    if (!existing) return;
    setHighlights(saveHighlight(book.workKey, { ...existing, note }));
    syncState();
    setNoteFor(null);
    setNoteDraft('');
  };

  const deleteHighlight = (id: string) => {
    if (!book) return;
    setHighlights(removeHighlight(book.workKey, id));
    syncState();
  };

  useEffect(() => {
    if (!pendingJump) return;
    const id = window.requestAnimationFrame(() => {
      const el = Array.from(scrollRef.current?.querySelectorAll('article p') ?? []).find((p) => p.textContent?.includes(pendingJump));
      el?.scrollIntoView({ block: 'center' });
      setPendingJump('');
    });
    return () => window.cancelAnimationFrame(id);
  }, [pendingJump, chapterIdx]);

  useEffect(() => {
    if (!book || !synced.progress || syncedOnceRef.current === book.workKey) return;
    const remote = synced.progress;
    if (remote.workKey !== book.workKey) return;
    syncedOnceRef.current = book.workKey;
    const local = loadProgress(book.workKey);
    if (local && local.updatedAt >= remote.updatedAt) return;
    const idx = chapters.length ? Math.min(remote.chapter, chapters.length - 1) : remote.chapter;
    setChapterIdx(idx);
    chapterRef.current = idx;
    setScrollPct(remote.scroll);
    scrollFracRef.current = remote.scroll;
    saveProgress({ ...remote, workKey: book.workKey });
    if (synced.bookmarks.length) replaceBookmarks(book.workKey, synced.bookmarks);
    if (synced.highlights.length) replaceHighlights(book.workKey, synced.highlights);
    setBookmarks(loadBookmarks(book.workKey));
    setHighlights(loadHighlights(book.workKey));
    window.requestAnimationFrame(() => {
      const el = scrollRef.current;
      if (el) el.scrollTop = remote.scroll * Math.max(0, el.scrollHeight - el.clientHeight);
    });
  }, [synced, book, chapters.length]);

  const bookMatches = bookSearch.trim()
    ? chapters.flatMap((ch, i) => {
        const at = ch.body.toLowerCase().indexOf(bookSearch.trim().toLowerCase());
        return at >= 0 ? [{ chapter: i, title: ch.title, snippet: ch.body.slice(Math.max(0, at - 50), at + 120) }] : [];
      })
    : [];

  let runningOffset = 0;
  const paragraphOffsets = paragraphs.map((text) => {
    const start = runningOffset;
    runningOffset += text.length + 1;
    return start;
  });
  const fontFamily = FONT_FAMILIES[settings.font];

  function segmented<T extends string | number>(
    label: string,
    options: { value: T; label: string }[],
    active: T,
    onPick: (value: T) => void,
  ) {
    return (
      <div style={{ marginBottom: 18 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.1, color: withAlpha(theme.fg, 0.55), marginBottom: 8 }}>{label}</div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
          {options.map((o) => (
            <button
              key={String(o.value)}
              type="button"
              className="bare-button"
              onClick={() => onPick(o.value)}
              style={{
                padding: '8px 14px', borderRadius: 12, fontSize: 13, fontWeight: 700, color: theme.fg,
                background: o.value === active ? withAlpha(AppColors.deepRose, 0.3) : withAlpha(theme.fg, 0.06),
                border: `1px solid ${o.value === active ? withAlpha(AppColors.deepRose, 0.75) : withAlpha(theme.fg, 0.14)}`,
              }}
            >
              {o.label}
            </button>
          ))}
        </div>
      </div>
    );
  }

  function stepper(label: string, display: string, onMinus: () => void, onPlus: () => void, canMinus: boolean, canPlus: boolean) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <div style={{ flex: 1, fontSize: 13, fontWeight: 700, color: theme.fg }}>{label}</div>
        <button type="button" className="bare-button" aria-label={`Decrease ${label}`} disabled={!canMinus} onClick={onMinus} style={{ width: 42, height: 42, borderRadius: 12, border: `1px solid ${withAlpha(theme.fg, 0.18)}`, color: theme.fg, fontSize: 20, opacity: canMinus ? 1 : 0.35 }}>−</button>
        <div style={{ minWidth: 52, textAlign: 'center', fontSize: 13, fontWeight: 700, color: withAlpha(theme.fg, 0.8) }}>{display}</div>
        <button type="button" className="bare-button" aria-label={`Increase ${label}`} disabled={!canPlus} onClick={onPlus} style={{ width: 42, height: 42, borderRadius: 12, border: `1px solid ${withAlpha(theme.fg, 0.18)}`, color: theme.fg, fontSize: 20, opacity: canPlus ? 1 : 0.35 }}>+</button>
      </div>
    );
  }

  return (
    <div style={{ position: 'relative', height: '100%', background: theme.bg, color: theme.fg, display: 'flex', flexDirection: 'column' }}>
      {!chromeHidden && <>
      <div style={{ padding: '8px 12px', borderBottom: `1px solid ${withAlpha(theme.fg, 0.12)}`, display: 'flex', alignItems: 'center', gap: 2 }}>
        <button type="button" className="bare-button" aria-label="Back" onClick={() => (canPop() ? navigate(-1) : navigate('/books'))} style={{ width: 44, height: 44, flexShrink: 0, display: 'grid', placeItems: 'center' }}>
          <Icon name="arrow_back" size={22} color={theme.fg} />
        </button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: Fonts.display, fontWeight: 700, fontSize: 17, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {book.title}
          </div>
          {chapters.length > 1 && currentChapter && (
            <div style={{ fontSize: 11, opacity: 0.65, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {currentChapter.title} ({chapterIdx + 1}/{chapters.length}) · {overallPct}%
            </div>
          )}
        </div>
        <button type="button" className="bare-button" title="Reading menu" aria-label="Reading menu" onClick={() => setMenuOpen(true)} style={{ width: 44, height: 44, flexShrink: 0, display: 'grid', placeItems: 'center' }}>
          <Icon name="menu" size={21} color={theme.fg} />
        </button>
        <button
          type="button"
          className="bare-button"
          title={speaking ? (paused ? 'Resume' : 'Pause') : 'Listen'}
          aria-label={speaking ? (paused ? 'Resume' : 'Pause') : 'Listen'}
          onClick={toggleSpeech}
          style={{ width: 44, height: 44, flexShrink: 0, display: 'grid', placeItems: 'center' }}
        >
          <Icon name={speaking ? (paused ? 'play_arrow' : 'pause') : 'headphones'} size={21} color={speaking ? AppColors.deepRose : theme.fg} />
        </button>
        <button ref={settingsTriggerRef} type="button" className="bare-button" title="Reading settings" aria-label="Reading settings" onClick={() => setSettingsOpen(true)} style={{ width: 44, height: 44, flexShrink: 0, display: 'grid', placeItems: 'center' }}>
          <Icon name="text_fields" size={21} color={theme.fg} />
        </button>
      </div>
      <div style={{ height: 3, background: withAlpha(theme.fg, 0.1) }} aria-label={`${overallPct}% read`}>
        <div style={{ height: '100%', width: `${overallPct}%`, background: AppColors.warmAmber, transition: 'width 240ms ease' }} />
      </div>
      </>}
      {chromeHidden && (
        <button type="button" className="bare-button" aria-label="Show reading controls" onClick={() => setChromeHidden(false)} style={{ position: 'absolute', top: 10, right: 12, zIndex: 4, width: 40, height: 40, borderRadius: 20, background: withAlpha(theme.fg, 0.08), border: `1px solid ${withAlpha(theme.fg, 0.14)}`, color: theme.fg, fontSize: 18 }}>⋯</button>
      )}

      <div ref={scrollRef} onScroll={onScroll} style={{ flex: 1, overflowY: 'auto', padding: `22px ${Math.round(settings.margin * 22) + 12}px 36px` }}>
        {loading ? (
          <div style={{ maxWidth: measure, margin: '0 auto', paddingTop: 8 }} aria-label="Opening the pages">
            {[90, 100, 96, 98, 70, 100, 94, 88].map((w, i) => (
              <div key={i} style={{ height: 12, borderRadius: 6, background: withAlpha(theme.fg, 0.08), marginBottom: 14, width: `${w}%` }} />
            ))}
          </div>
        ) : currentChapter ? (
          <div style={{ maxWidth: measure, margin: '0 auto' }}>
            {chapters.length > 1 && (
              <h2 style={{ fontFamily: Fonts.display, fontSize: settings.fontSize + 6, fontWeight: 700, margin: '0 0 18px' }}>
                {currentChapter.title}
              </h2>
            )}
            <article
              aria-label={currentChapter.title}
              onMouseUp={captureSelection}
              onTouchEnd={captureSelection}
              onClick={(e) => {
                if (selectionText) return;
                const rect = e.currentTarget.getBoundingClientRect();
                const rel = (e.clientX - rect.left) / rect.width;
                if (settings.pageTurn && chapters.length > 1) {
                  if (rel < 0.2) { selectChapter(chapterIdx - 1); return; }
                  if (rel > 0.8) { selectChapter(chapterIdx + 1); return; }
                }
                if (rel >= 0.2 && rel <= 0.8) setChromeHidden((v) => !v);
              }}
            >
              {paragraphs.map((text, i) => {
                const start = paragraphOffsets[i];
                const active = speaking && followChar >= start && followChar < start + text.length;
                return (
                  <p
                    key={i}
                    style={{
                      fontFamily, fontSize: settings.fontSize, lineHeight: settings.lineHeight,
                      margin: `0 0 ${Math.round(settings.fontSize * 0.9)}px`,
                      padding: active ? '2px 6px' : '2px 0',
                      borderRadius: 6,
                      background: active ? withAlpha(AppColors.warmAmber, settings.theme === 'dark' ? 0.16 : 0.28) : 'transparent',
                      transition: 'background 180ms ease',
                    }}
                  >
                    {renderHighlighted(text, highlights.filter((h) => h.chapter === chapterIdx), AppColors.warmAmber, (h) => { setNoteFor(h.id); setNoteDraft(h.note); })}
                  </p>
                );
              })}
            </article>
            {chapters.length > 1 && (
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 32, paddingTop: 16, borderTop: `1px solid ${withAlpha(theme.fg, 0.12)}` }}>
                <button
                  type="button"
                  className="bare-button"
                  disabled={chapterIdx === 0}
                  onClick={() => selectChapter(chapterIdx - 1)}
                  style={{ minHeight: 44, padding: '8px 14px', borderRadius: 10, border: `1px solid ${withAlpha(theme.fg, 0.2)}`, opacity: chapterIdx === 0 ? 0.35 : 1, fontSize: 13, color: theme.fg }}
                >
                  ← Previous
                </button>
                <button
                  type="button"
                  className="bare-button"
                  disabled={chapterIdx >= chapters.length - 1}
                  onClick={() => selectChapter(chapterIdx + 1)}
                  style={{ minHeight: 44, padding: '8px 14px', borderRadius: 10, border: `1px solid ${withAlpha(theme.fg, 0.2)}`, opacity: chapterIdx >= chapters.length - 1 ? 0.35 : 1, fontSize: 13, color: theme.fg }}
                >
                  Next →
                </button>
              </div>
            )}
          </div>
        ) : book.iaId ? (
          <iframe
            src={`https://archive.org/embed/${book.iaId}`}
            title={book.title}
            sandbox="allow-scripts allow-same-origin allow-presentation"
            allowFullScreen
            style={{ width: '100%', height: '82vh', border: 'none', borderRadius: 12 }}
          />
        ) : (
          <div style={{ padding: 48, textAlign: 'center' }}>
            <div>{error || 'No readable text found.'}</div>
            <button type="button" className="bare-button" onClick={() => navigate('/books')} style={{ marginTop: 16, padding: '10px 18px', borderRadius: 14, background: AppColors.deepRose, color: '#FFF', fontWeight: 700 }}>
              Back to Books
            </button>
          </div>
        )}
      </div>

      {settings.brightness < 1 && (
        <div aria-hidden="true" style={{ position: 'absolute', inset: 0, zIndex: 3, pointerEvents: 'none', background: `rgba(0,0,0,${1 - settings.brightness})` }} />
      )}

      {selectionText && !noteFor && !settingsOpen && !searchOpen && (
        <div
          style={{
            position: 'fixed', bottom: 20, left: '50%', transform: 'translateX(-50%)', zIndex: 60,
            display: 'flex', alignItems: 'center', gap: 6, padding: 8, borderRadius: 18,
            background: settings.theme === 'dark' ? AppColors.inkDeep : ReaderPaper.sepia,
            border: `1px solid ${withAlpha(theme.fg, 0.2)}`, boxShadow: '0 10px 30px rgba(0,0,0,0.4)',
          }}
        >
          <button type="button" className="bare-button" onClick={() => addHighlight('')} style={{ padding: '8px 12px', borderRadius: 12, color: theme.fg, fontSize: 12, fontWeight: 700 }}>Highlight</button>
          <button type="button" className="bare-button" onClick={() => { setNoteFor('new'); setNoteDraft(''); }} style={{ padding: '8px 12px', borderRadius: 12, color: theme.fg, fontSize: 12, fontWeight: 700 }}>Note</button>
          <button type="button" className="bare-button" onClick={() => { startSpeech(selectionText, settings.ttsRate); setSelectionText(''); }} style={{ padding: '8px 12px', borderRadius: 12, color: theme.fg, fontSize: 12, fontWeight: 700 }}>Read from here</button>
          <button type="button" className="bare-button" aria-label="Dismiss" onClick={() => setSelectionText('')} style={{ width: 36, height: 36, color: theme.fg, fontSize: 18 }}>×</button>
        </div>
      )}

      {noteFor && (
        <div onClick={() => setNoteFor(null)} style={{ position: 'fixed', inset: 0, zIndex: 95, background: 'rgba(0,0,0,0.7)', display: 'grid', placeItems: 'center', padding: 20 }}>
          <div ref={notePanelRef} role="dialog" aria-modal="true" aria-label="Add a note" tabIndex={-1} onClick={(e) => e.stopPropagation()} style={{ width: '100%', maxWidth: 420, padding: 20, borderRadius: 20, background: settings.theme === 'dark' ? AppColors.inkDeep : ReaderPaper.sepia, color: theme.fg }}>
            <div style={{ fontFamily: Fonts.display, fontSize: 22, fontWeight: 700 }}>Add a note</div>
            <div style={{ fontSize: 12, color: withAlpha(theme.fg, 0.6), margin: '6px 0 12px' }}>{selectionText.slice(0, 140) || highlights.find((h) => h.id === noteFor)?.text.slice(0, 140)}</div>
            <textarea aria-label="Note" value={noteDraft} onChange={(e) => setNoteDraft(e.target.value)} placeholder="What stood out to you?" style={{ width: '100%', boxSizing: 'border-box', minHeight: 110, padding: 12, borderRadius: 12, background: withAlpha(theme.fg, 0.06), border: `1px solid ${withAlpha(theme.fg, 0.18)}`, color: theme.fg, fontSize: 14, fontFamily: Fonts.body }} />
            <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
              <button type="button" className="bare-button" onClick={() => setNoteFor(null)} style={{ flex: 1, minHeight: 44, borderRadius: 12, border: `1px solid ${withAlpha(theme.fg, 0.2)}`, color: theme.fg, fontWeight: 700 }}>Cancel</button>
              <button type="button" className="bare-button" onClick={() => (noteFor === 'new' ? addHighlight(noteDraft) : updateNote(noteFor, noteDraft))} style={{ flex: 1, minHeight: 44, borderRadius: 12, background: AppColors.deepRose, color: '#FFF', fontWeight: 700 }}>Save note</button>
            </div>
          </div>
        </div>
      )}

      {searchOpen && (
        <div onClick={() => setSearchOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 94, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'flex-start', justifyContent: 'center', padding: '8vh 16px 16px' }}>
          <div ref={searchPanelRef} role="dialog" aria-modal="true" aria-label="Search in book" tabIndex={-1} onClick={(e) => e.stopPropagation()} style={{ width: '100%', maxWidth: 520, maxHeight: '82vh', overflowY: 'auto', padding: 20, borderRadius: 20, background: settings.theme === 'dark' ? AppColors.inkDeep : ReaderPaper.sepia, color: theme.fg }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ fontFamily: Fonts.display, fontSize: 24, fontWeight: 700 }}>Search in this book</div>
              <button type="button" className="bare-button" aria-label="Close search" onClick={() => setSearchOpen(false)} style={{ width: 40, height: 40, fontSize: 22, color: theme.fg }}>×</button>
            </div>
            <input aria-label="Search in book" value={bookSearch} onChange={(e) => setBookSearch(e.target.value)} placeholder="A word or phrase…" style={{ width: '100%', boxSizing: 'border-box', marginTop: 12, padding: '12px 14px', borderRadius: 12, background: withAlpha(theme.fg, 0.06), border: `1px solid ${withAlpha(theme.fg, 0.18)}`, color: theme.fg, fontSize: 15 }} />
            <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
              {bookMatches.map((m) => (
                <button key={m.chapter} type="button" className="bare-button" onClick={() => { setSearchOpen(false); selectChapter(m.chapter); setPendingJump(bookSearch.trim()); }} style={{ textAlign: 'left', padding: 12, borderRadius: 12, background: withAlpha(theme.fg, 0.05), border: `1px solid ${withAlpha(theme.fg, 0.12)}`, color: theme.fg }}>
                  <div style={{ fontSize: 11, fontWeight: 700, color: AppColors.warmAmber }}>{m.title}</div>
                  <div className="clamp-2" style={{ fontSize: 12.5, marginTop: 4, opacity: 0.8 }}>…{m.snippet}…</div>
                </button>
              ))}
              {!bookSearch.trim() && <div style={{ fontSize: 12.5, opacity: 0.65 }}>Type a word or phrase to find it anywhere in the book.</div>}
              {bookSearch.trim() && bookMatches.length === 0 && <div style={{ fontSize: 12.5, opacity: 0.65 }}>No matches in this book.</div>}
            </div>
          </div>
        </div>
      )}

      {menuOpen && (
        <div onClick={() => setMenuOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 92, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
          <div
            ref={menuPanelRef}
            role="dialog"
            aria-modal="true"
            aria-label="Reading menu"
            tabIndex={-1}
            onClick={(e) => e.stopPropagation()}
            style={{ width: '100%', maxWidth: 540, maxHeight: '82vh', overflowY: 'auto', outline: 'none', padding: '14px 20px 28px', borderRadius: '26px 26px 0 0', background: settings.theme === 'dark' ? AppColors.inkDeep : settings.theme === 'sepia' ? ReaderPaper.sepia : ReaderPaper.light, color: theme.fg }}
          >
            <div style={{ width: 38, height: 4, borderRadius: 2, background: withAlpha(theme.fg, 0.2), margin: '0 auto 14px' }} />
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <div style={{ fontFamily: Fonts.display, fontSize: 26, fontWeight: 700 }}>Reading menu</div>
              <button type="button" className="bare-button" aria-label="Close menu" onClick={() => setMenuOpen(false)} style={{ width: 44, height: 44, fontSize: 22, color: theme.fg }}>×</button>
            </div>
            <div style={{ display: 'flex', gap: 8, marginBottom: 18 }}>
              <button type="button" className="bare-button" onClick={() => { setMenuOpen(false); setSearchOpen(true); }} style={{ flex: 1, minHeight: 48, borderRadius: 14, background: withAlpha(theme.fg, 0.06), border: `1px solid ${withAlpha(theme.fg, 0.14)}`, color: theme.fg, fontSize: 12.5, fontWeight: 700 }}>
                <Icon name="search" size={17} color={theme.fg} /> Search in book
              </button>
              <button type="button" className="bare-button" onClick={toggleThisBookmark} style={{ flex: 1, minHeight: 48, borderRadius: 14, background: bookmarked ? withAlpha(AppColors.warmAmber, 0.16) : withAlpha(theme.fg, 0.06), border: `1px solid ${bookmarked ? withAlpha(AppColors.warmAmber, 0.5) : withAlpha(theme.fg, 0.14)}`, color: theme.fg, fontSize: 12.5, fontWeight: 700 }}>
                <Icon name={bookmarked ? 'bookmark' : 'bookmark_border'} size={17} color={bookmarked ? AppColors.warmAmber : theme.fg} /> {bookmarked ? 'Bookmarked' : 'Bookmark'}
              </button>
            </div>
            {chapters.length > 1 && (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: withAlpha(theme.fg, 0.55), marginBottom: 8 }}>CHAPTERS</div>
                {chapters.map((ch, i) => (
                  <button key={`${ch.title}-${i}`} type="button" className="bare-button" onClick={() => selectChapter(i)} style={{ width: '100%', minHeight: 44, textAlign: 'left', padding: '8px 10px', borderRadius: 10, fontSize: 13, fontWeight: i === chapterIdx ? 700 : 500, color: i === chapterIdx ? AppColors.deepRose : theme.fg, background: i === chapterIdx ? withAlpha(AppColors.deepRose, 0.12) : 'transparent' }}>
                    {ch.title}
                  </button>
                ))}
              </div>
            )}
            {bookmarks.length > 0 && (
              <div>
                <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.2, color: withAlpha(theme.fg, 0.55), marginBottom: 8 }}>YOUR BOOKMARKS</div>
                {bookmarks.map((b) => (
                  <button key={b.createdAt} type="button" className="bare-button" onClick={() => selectChapter(b.chapter)} style={{ width: '100%', minHeight: 44, textAlign: 'left', padding: '8px 10px', borderRadius: 10, fontSize: 13, color: theme.fg }}>
                    <Icon name="bookmark" size={14} color={AppColors.warmAmber} /> Chapter {b.chapter + 1}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {settingsOpen && (
        <div
          onClick={() => { setSettingsOpen(false); settingsTriggerRef.current?.focus(); }}
          style={{ position: 'fixed', inset: 0, zIndex: 90, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
        >
          <div
            ref={settingsPanelRef}
            role="dialog"
            aria-modal="true"
            aria-label="Reading settings"
            tabIndex={-1}
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%', maxWidth: 540, maxHeight: '85vh', overflowY: 'auto', outline: 'none',
              background: settings.theme === 'dark' ? AppColors.inkDeep : settings.theme === 'sepia' ? ReaderPaper.sepia : ReaderPaper.light,
              color: theme.fg, borderTopLeftRadius: 26, borderTopRightRadius: 26, padding: '14px 20px 30px',
            }}
          >
            <div style={{ width: 38, height: 4, borderRadius: 2, background: withAlpha(theme.fg, 0.2), margin: '0 auto 14px' }} />
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <div style={{ fontFamily: Fonts.display, fontSize: 26, fontWeight: 700 }}>Reading settings</div>
              <button type="button" className="bare-button" onClick={() => setSettingsOpen(false)} style={{ minWidth: 44, minHeight: 44, fontSize: 22, color: theme.fg }} aria-label="Close settings">×</button>
            </div>

            {stepper(
              'Text size',
              `${settings.fontSize}px`,
              () => patchSettings({ fontSize: Math.max(14, settings.fontSize - 1) }),
              () => patchSettings({ fontSize: Math.min(28, settings.fontSize + 1) }),
              settings.fontSize > 14,
              settings.fontSize < 28,
            )}
            {segmented<ReaderFont>(
              'Typeface',
              [
                { value: 'classic', label: 'Classic' },
                { value: 'modern', label: 'Modern' },
                { value: 'soft', label: 'Soft' },
              ],
              settings.font,
              (value) => patchSettings({ font: value }),
            )}
            {segmented<ReaderTheme>(
              'Page',
              [
                { value: 'dark', label: 'Night' },
                { value: 'sepia', label: 'Sepia' },
                { value: 'light', label: 'Day' },
              ],
              settings.theme,
              (value) => patchSettings({ theme: value }),
            )}
            {segmented<'scroll' | 'tap'>(
              'Turn pages',
              [
                { value: 'scroll', label: 'Scroll' },
                { value: 'tap', label: 'Tap edges for chapter' },
              ],
              settings.pageTurn ? 'tap' : 'scroll',
              (value) => patchSettings({ pageTurn: value === 'tap' }),
            )}
            {segmented<number>(
              'Line spacing',
              [
                { value: 1.45, label: 'Tight' },
                { value: 1.7, label: 'Comfy' },
                { value: 2, label: 'Airy' },
              ],
              settings.lineHeight,
              (value) => patchSettings({ lineHeight: value }),
            )}
            {stepper(
              'Brightness',
              `${Math.round(settings.brightness * 100)}%`,
              () => patchSettings({ brightness: Math.max(0.5, Math.round((settings.brightness - 0.1) * 10) / 10) }),
              () => patchSettings({ brightness: Math.min(1, Math.round((settings.brightness + 0.1) * 10) / 10) }),
              settings.brightness > 0.5,
              settings.brightness < 1,
            )}
            {stepper(
              'Margins',
              settings.margin === 0 ? 'Narrow' : settings.margin === 0.5 ? 'Comfy' : 'Wide',
              () => patchSettings({ margin: Math.max(0, settings.margin - 0.5) }),
              () => patchSettings({ margin: Math.min(1, settings.margin + 0.5) }),
              settings.margin > 0,
              settings.margin < 1,
            )}
            {segmented<number>(
              'Narration speed',
              TTS_RATES.map((r) => ({ value: r as number, label: `${r}x` })),
              settings.ttsRate,
              (value) => { patchSettings({ ttsRate: value }); WebTts.setRate(value); },
            )}
            {segmented<number>(
              'Sleep timer',
              [
                { value: 0, label: 'Off' },
                { value: 5, label: '5 min' },
                { value: 15, label: '15 min' },
                { value: 30, label: '30 min' },
              ],
              sleepMinutes,
              (value) => {
                setSleepMinutes(value);
                if (sleepTimerRef.current != null) window.clearTimeout(sleepTimerRef.current);
                sleepTimerRef.current = value > 0 ? window.setTimeout(stopSpeech, value * 60_000) : null;
              },
            )}
            <div style={{ marginBottom: 18 }}>
              <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.1, color: withAlpha(theme.fg, 0.55), marginBottom: 8 }}>
                YOUR MARKS · {bookmarks.length} bookmark{bookmarks.length === 1 ? '' : 's'} · {highlights.length} highlight{highlights.length === 1 ? '' : 's'}
              </div>
              {highlights.length === 0 && bookmarks.length === 0 && (
                <div style={{ fontSize: 12.5, opacity: 0.65 }}>Select text in the book to highlight it or add a note. Tap the ribbon to bookmark a page.</div>
              )}
              {highlights.slice(0, 10).map((h) => (
                <div key={h.id} style={{ padding: '10px 0', borderBottom: `1px solid ${withAlpha(theme.fg, 0.1)}` }}>
                  <div style={{ fontSize: 12.5, lineHeight: 1.4 }}>“{h.text.slice(0, 110)}{h.text.length > 110 ? '…' : ''}”</div>
                  {h.note && <div style={{ fontSize: 11.5, opacity: 0.7, marginTop: 4 }}>{h.note}</div>}
                  <div style={{ display: 'flex', gap: 8, marginTop: 6 }}>
                    <button type="button" className="bare-button" onClick={() => { setNoteFor(h.id); setNoteDraft(h.note); setSettingsOpen(false); }} style={{ fontSize: 11.5, fontWeight: 700, color: AppColors.warmAmber }}>Edit note</button>
                    <button type="button" className="bare-button" onClick={() => deleteHighlight(h.id)} style={{ fontSize: 11.5, fontWeight: 700, color: AppColors.error }}>Delete</button>
                  </div>
                </div>
              ))}
            </div>
            <button
              type="button"
              className="bare-button"
              onClick={() => { patchSettings({ ...DEFAULT_READER_SETTINGS }); setSleepMinutes(0); }}
              style={{ width: '100%', minHeight: 46, borderRadius: 14, border: `1px solid ${withAlpha(theme.fg, 0.18)}`, fontSize: 13, fontWeight: 700, color: theme.fg }}
            >
              Reset to defaults
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

export function BookListPage() {
  const { width } = useViewport();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { kind?: 'popular' | 'recent' | 'category'; title?: string; category?: BookCategory; initialResults?: BookSearchResult[] } | null) ?? {};

  const PAGE = 30;
  const [results, setResults] = useState<BookSearchResult[]>(state.initialResults ?? []);
  const [loading, setLoading] = useState(!state.initialResults?.length);
  const [loadingMore, setLoadingMore] = useState(false);
  const [offset, setOffset] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [listError, setListError] = useState(false);
  const [listRetryKey, setListRetryKey] = useState(0);

  const fetchPage = (start: number): Promise<BookSearchResult[]> =>
    state.category
      ? fetchBooksBySubject(state.category.query, PAGE, start)
      : state.kind === 'recent'
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
  }, [state.kind, state.category, state.initialResults, listRetryKey]);

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

  const title = state.category?.name ?? state.title ?? (state.kind === 'recent' ? 'Recently Added' : 'Most Popular');
  const eyebrow =
    state.category != null
      ? 'BROWSE BY CATEGORY'
      : state.kind === 'recent'
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
            <div style={{ padding: 48, textAlign: 'center', color: BookColors.muted }}>Loading…</div>
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
                onClick={() => navigate('/books/category', { state: { category: cat } })}
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
