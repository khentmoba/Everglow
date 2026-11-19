import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { WebTts } from '../../core/system/webTts';
import { AppColors, ReaderPaper, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
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
  fetchBookDetails,
  fetchBooksBySubject,
  fetchBookText,
  fetchPopularBooks,
  fetchRecentBooks,
  recordBookDownload,
  removeFromOurBooks,
  saveToReadList,
  toggleBookFavorite,
  watchBookFavorites,
  watchOurBooks,
  watchReadList,
} from './booksService';
import { BookCover, BookCoverCard } from './BookCover';
import {
  DEFAULT_READER_SETTINGS,
  loadProgress,
  loadSettings,
  saveProgress,
  saveSettings,
  type ReaderFont,
  type ReaderSettings,
  type ReaderTheme,
} from './readerPrefs';

export function BookDetailPage() {
  const { currentUser, isCoupleUser } = useAuth();
  const { width } = useViewport();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { result?: BookSearchResult; saved?: BookItem } | null) ?? null;

  const [result, setResult] = useState<BookSearchResult | null>(state?.result ?? null);
  const [similar, setSimilar] = useState<BookSearchResult[]>([]);
  const [addedToast, setAddedToast] = useState(false);
  const userName = currentUser ?? '';
  const readlist = useSource(() => watchReadList(userName), [userName], []);
  const favorites = useSource(() => watchBookFavorites(userName), [userName], []);
  const ourBooks = useSource(() => watchOurBooks(300), [], []);

  useEffect(() => {
    if (!state?.result) return;
    let alive = true;
    fetchBookDetails(state.result).then((enriched) => {
      if (alive) setResult(enriched);
    });
    const subj = state.result.subjects[0] || 'fiction';
    fetchBooksBySubject(subj, 12).then((list) => {
      if (alive) setSimilar(list.filter((b) => b.workKey !== state.result?.workKey).slice(0, 10));
    });
    return () => {
      alive = false;
    };
  }, [state?.result]);

  if (!result) {
    return (
      <div style={{ height: '100%', background: BookColors.black, color: BookColors.white, display: 'grid', placeItems: 'center' }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontFamily: Fonts.display, fontSize: 22 }}>Pick a book from the shelf first</div>
          <button type="button" className="bare-button" onClick={() => navigate('/books')} style={{ marginTop: 14, padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>
            Back to Books
          </button>
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
    ['Type', 'Book'],
    ['Language', result.language],
    ['File', (result.filetype || (hasReadable ? 'EPUB' : '')).toUpperCase()],
    ['Source', result.sourceLabel],
    ['Year', result.year],
    ['Gutenberg ID', result.gutenbergId > 0 ? String(result.gutenbergId) : ''],
  ].filter(([, v]) => Boolean(v)) as [string, string][];

  const copyShare = () => {
    const url = result.gutenbergId > 0
      ? `https://www.gutenberg.org/ebooks/${result.gutenbergId}`
      : result.iaId
        ? `https://archive.org/details/${result.iaId}`
        : `https://openlibrary.org${item.workKey}`;
    void navigator.clipboard?.writeText(`${url}\n${item.title}`);
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
                    void removeFromOurBooks(ourBooksKey);
                  } else {
                    void addToOurBooks(item, userName);
                    setAddedToast(true);
                    window.setTimeout(() => setAddedToast(false), 2600);
                  }
                }}
              />
            </>
          )}
          <DetailActionCircle icon="ios_share" label="Share" onClick={copyShare} />
        </div>

        {result.description && (
          <p style={{ marginTop: 22, fontSize: 14, lineHeight: 1.65, color: withAlpha(BookColors.white, 0.85) }}>
            {result.description}
          </p>
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

export function BookReaderPage({ startListening = false }: { startListening?: boolean }) {
  const navigate = useNavigate();
  const location = useLocation();
  const book = (location.state as { book?: BookItem } | null)?.book ?? null;

  const [settings, setSettings] = useState<ReaderSettings>(() => loadSettings());
  const [chapters, setChapters] = useState<BookChapter[]>([]);
  const [chapterIdx, setChapterIdx] = useState(0);
  const [tocOpen, setTocOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [speaking, setSpeaking] = useState(false);
  const [paused, setPaused] = useState(false);
  const [followChar, setFollowChar] = useState(-1);
  const [sleepMinutes, setSleepMinutes] = useState(0);

  const scrollRef = useRef<HTMLDivElement>(null);
  const settingsPanelRef = useRef<HTMLDivElement>(null);
  const settingsTriggerRef = useRef<HTMLButtonElement>(null);
  const chapterRef = useRef(0);
  const scrollFracRef = useRef(0);
  const lastScrollSaveRef = useRef(0);
  const sleepTimerRef = useRef<number | null>(null);

  const patchSettings = (patch: Partial<ReaderSettings>) => {
    setSettings((prev) => {
      const next = { ...prev, ...patch };
      saveSettings(next);
      return next;
    });
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
        window.requestAnimationFrame(() => {
          if (!alive || !saved || saved.scroll <= 0 || !scrollRef.current) return;
          const el = scrollRef.current;
          el.scrollTop = saved.scroll * Math.max(0, el.scrollHeight - el.clientHeight);
          scrollFracRef.current = saved.scroll;
        });
        if (startListening && WebTts.isSupported && list[initial]) {
          startSpeech(list[initial].body, loadSettings().ttsRate);
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

  useEffect(() => {
    if (!settingsOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setSettingsOpen(false);
        settingsTriggerRef.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    window.requestAnimationFrame(() => settingsPanelRef.current?.focus());
    return () => window.removeEventListener('keydown', onKey);
  }, [settingsOpen]);

  if (!book) {
    return (
      <div style={{ height: '100%', background: BookColors.black, color: BookColors.white, display: 'grid', placeItems: 'center' }}>
        <button type="button" className="bare-button" onClick={() => navigate('/books')} style={{ padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>
          Back to Books
        </button>
      </div>
    );
  }

  const currentChapter = chapters[chapterIdx] ?? null;
  const theme = THEME_TOKENS[settings.theme];

  const selectChapter = (nextIdx: number) => {
    if (nextIdx < 0 || nextIdx >= chapters.length) return;
    setChapterIdx(nextIdx);
    chapterRef.current = nextIdx;
    setTocOpen(false);
    if (scrollRef.current) scrollRef.current.scrollTop = 0;
    scrollFracRef.current = 0;
    saveProgressNow(nextIdx, 0);
    if (speaking && chapters[nextIdx]) startSpeech(chapters[nextIdx].body, settings.ttsRate);
  };

  const toggleSpeech = () => {
    if (!speaking) {
      if (currentChapter) startSpeech(currentChapter.body, settings.ttsRate);
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
    const now = Date.now();
    if (now - lastScrollSaveRef.current > 700) {
      lastScrollSaveRef.current = now;
      saveProgressNow(chapterRef.current, scrollFracRef.current);
    }
  };

  const paragraphs = currentChapter ? toParagraphs(currentChapter.body) : [];
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
              {currentChapter.title} ({chapterIdx + 1}/{chapters.length})
            </div>
          )}
        </div>
        {chapters.length > 1 && (
          <button type="button" className="bare-button" title="Chapters" aria-label="Chapters" onClick={() => setTocOpen((o) => !o)} style={{ width: 44, height: 44, flexShrink: 0, display: 'grid', placeItems: 'center' }}>
            <Icon name="format_list_bulleted" size={21} color={theme.fg} />
          </button>
        )}
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

      {tocOpen && chapters.length > 1 && (
        <div style={{ maxHeight: 240, overflowY: 'auto', borderBottom: `1px solid ${withAlpha(theme.fg, 0.12)}`, background: withAlpha(theme.fg, 0.04), padding: '8px 16px' }}>
          {chapters.map((ch, i) => (
            <button
              key={`${ch.title}-${i}`}
              type="button"
              className="bare-button"
              onClick={() => selectChapter(i)}
              style={{
                width: '100%', minHeight: 42, textAlign: 'left', padding: '8px', borderRadius: 10,
                fontSize: 13, fontWeight: i === chapterIdx ? 700 : 500,
                color: i === chapterIdx ? AppColors.deepRose : theme.fg,
                background: i === chapterIdx ? withAlpha(AppColors.deepRose, 0.12) : 'transparent',
              }}
            >
              {ch.title}
            </button>
          ))}
        </div>
      )}

      <div ref={scrollRef} onScroll={onScroll} style={{ flex: 1, overflowY: 'auto', padding: `22px ${Math.round(settings.margin * 22) + 12}px 36px` }}>
        {loading ? (
          <div style={{ padding: 64, textAlign: 'center', fontFamily: Fonts.display, fontSize: 18 }}>Opening the pages…</div>
        ) : currentChapter ? (
          <div style={{ maxWidth: 680, margin: '0 auto' }}>
            {chapters.length > 1 && (
              <h2 style={{ fontFamily: Fonts.display, fontSize: settings.fontSize + 6, fontWeight: 700, margin: '0 0 18px' }}>
                {currentChapter.title}
              </h2>
            )}
            <article aria-label={currentChapter.title}>
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
                    {text}
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

  const fetchPage = (start: number): Promise<BookSearchResult[]> =>
    state.category
      ? fetchBooksBySubject(state.category.query, PAGE, start)
      : state.kind === 'recent'
        ? fetchRecentBooks(PAGE, start)
        : fetchPopularBooks(PAGE, start);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setOffset(0);
    setHasMore(true);
    void fetchPage(0).then((res) => {
      if (!alive) return;
      setResults(res);
      setHasMore(res.length >= PAGE);
      setLoading(false);
    });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.kind, state.category]);

  const loadMore = async () => {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    const next = offset + PAGE;
    const res = await fetchPage(next);
    setResults((prev) => {
      const seen = new Set(prev.map((r) => r.workKey));
      return [...prev, ...res.filter((r) => !seen.has(r.workKey))];
    });
    setOffset(next);
    setHasMore(res.length >= PAGE);
    setLoadingMore(false);
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
                    color: BookColors.white,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
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
