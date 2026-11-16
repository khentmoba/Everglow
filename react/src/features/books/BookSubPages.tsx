import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
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
  saveToReadList,
  toggleBookFavorite,
  watchBookFavorites,
  watchReadList,
} from './booksService';
import { BookCoverCard } from './BookCover';

export function BookDetailPage() {
  const { currentUser, isCoupleUser } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { result?: BookSearchResult; saved?: BookItem } | null) ?? null;

  const [result, setResult] = useState<BookSearchResult | null>(state?.result ?? null);
  const userName = currentUser ?? '';
  const readlist = useSource(() => watchReadList(userName), [userName], []);
  const favorites = useSource(() => watchBookFavorites(userName), [userName], []);

  useEffect(() => {
    if (!state?.result) return;
    let alive = true;
    fetchBookDetails(state.result).then((enriched) => {
      if (alive) setResult(enriched);
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
  const hasReadable = buildReadCandidates(item).length > 0 || Boolean(item.iaId);

  return (
    <div style={{ height: '100%', overflowY: 'auto', background: BookColors.black, color: BookColors.white, padding: '16px 20px 80px' }}>
      <div style={{ maxWidth: 820, margin: '0 auto' }}>
        <button
          type="button"
          className="bare-button"
          onClick={() => navigate(-1)}
          style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 16, color: BookColors.rose }}
        >
          <Icon name="arrow_back_ios_new" size={16} color={BookColors.rose} />
          <span style={{ fontSize: 13, fontWeight: 600 }}>Back</span>
        </button>

        <div style={{ display: 'flex', gap: 20, flexWrap: 'wrap' }}>
          <div style={{ width: 156, aspectRatio: '2 / 3', borderRadius: 14, overflow: 'hidden', background: BookColors.card, flexShrink: 0 }}>
            {result.coverUrl && <img src={result.coverUrl} alt={result.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
          </div>
          <div style={{ flex: 1, minWidth: 230 }}>
            <h1 style={{ fontFamily: Fonts.display, fontSize: 30, fontWeight: 900, lineHeight: 1.1, margin: 0 }}>{result.title}</h1>
            {result.author && <div style={{ fontSize: 14.5, color: BookColors.rose, marginTop: 6 }}>{result.author}</div>}
            <div style={{ fontSize: 12.5, color: BookColors.muted, marginTop: 6 }}>
              {[result.year, result.publisher, result.sourceLabel].filter(Boolean).join(' · ')}
            </div>

            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 18 }}>
              {hasReadable && (
                <>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => navigate('/books/reader', { state: { book: item } })}
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '10px 18px', borderRadius: 20, background: BookColors.white, color: BookColors.black, fontWeight: 700, fontSize: 13 }}
                  >
                    <Icon name="auto_stories" size={17} color={BookColors.black} /> Read
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => navigate('/books/listen', { state: { book: item, listen: true } })}
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '10px 18px', borderRadius: 20, background: withAlpha(BookColors.amber, 0.16), border: `1px solid ${withAlpha(BookColors.amber, 0.35)}`, color: BookColors.amber, fontWeight: 700, fontSize: 13 }}
                  >
                    <Icon name="headphones" size={17} color={BookColors.amber} /> Listen
                  </button>
                </>
              )}
              {isCoupleUser && (
                <>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => void saveToReadList(item, inReadlist?.status === 'to-read' ? 'read-self' : 'to-read', userName)}
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '10px 16px', borderRadius: 20, background: withAlpha(BookColors.deepRose, 0.18), border: `1px solid ${withAlpha(BookColors.deepRose, 0.4)}`, color: BookColors.white, fontWeight: 600, fontSize: 12.5 }}
                  >
                    <Icon name="bookmark" size={16} color={BookColors.rose} />
                    {isBookRead(inReadlist?.status ?? '') ? 'Read' : inReadlist ? 'To Read' : 'Save to Read List'}
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => void toggleBookFavorite(item, userName, !isLoved)}
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '10px 14px', borderRadius: 20, background: 'rgba(255,255,255,0.06)', color: isLoved ? BookColors.deepRose : BookColors.muted, fontSize: 12.5, fontWeight: 600 }}
                  >
                    <Icon name="favorite" size={16} color={isLoved ? BookColors.deepRose : BookColors.muted} />
                    {isLoved ? 'Loved' : 'Love'}
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => void addToOurBooks(item, userName)}
                    style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '10px 14px', borderRadius: 20, background: 'rgba(255,255,255,0.06)', color: BookColors.rose, fontSize: 12.5, fontWeight: 600 }}
                  >
                    <Icon name="people" size={16} color={BookColors.rose} /> Our Books
                  </button>
                </>
              )}
            </div>

            {result.description && (
              <p style={{ marginTop: 18, fontSize: 14, lineHeight: 1.65, color: withAlpha(BookColors.white, 0.85) }}>
                {result.description}
              </p>
            )}

            {result.subjects.length > 0 && (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 14 }}>
                {result.subjects.map((s) => (
                  <span key={s} style={{ padding: '4px 10px', borderRadius: 99, background: BookColors.card, border: `1px solid ${withAlpha(BookColors.rose, 0.14)}`, fontSize: 11.5, color: BookColors.muted }}>
                    {s}
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export function BookReaderPage({ startListening = false }: { startListening?: boolean }) {
  const navigate = useNavigate();
  const location = useLocation();
  const book = (location.state as { book?: BookItem } | null)?.book ?? null;

  const [text, setText] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [themeMode, setThemeMode] = useState<'dark' | 'sepia' | 'light'>('dark');
  const [fontSize, setFontSize] = useState(17);
  const [speaking, setSpeaking] = useState(false);

  useEffect(() => {
    if (!book) return;
    let alive = true;
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
        setText(res.text);
        if (startListening && 'speechSynthesis' in window) {
          const u = new SpeechSynthesisUtterance(res.text.slice(0, 6000));
          u.onend = () => setSpeaking(false);
          window.speechSynthesis.speak(u);
          setSpeaking(true);
        }
      } else {
        setError(res.error ?? 'Could not load book text.');
      }
      setLoading(false);
    });
    return () => {
      alive = false;
      if ('speechSynthesis' in window) window.speechSynthesis.cancel();
    };
  }, [book, startListening]);

  if (!book) {
    return (
      <div style={{ height: '100%', background: BookColors.black, color: BookColors.white, display: 'grid', placeItems: 'center' }}>
        <button type="button" className="bare-button" onClick={() => navigate('/books')} style={{ padding: '10px 20px', borderRadius: 20, background: BookColors.deepRose, color: '#FFF', fontWeight: 700 }}>
          Back to Books
        </button>
      </div>
    );
  }

  const toggleSpeech = () => {
    if (!('speechSynthesis' in window)) return;
    if (speaking) {
      window.speechSynthesis.cancel();
      setSpeaking(false);
    } else if (text) {
      const u = new SpeechSynthesisUtterance(text.slice(0, 10000));
      u.onend = () => setSpeaking(false);
      window.speechSynthesis.speak(u);
      setSpeaking(true);
    }
  };

  const bg = themeMode === 'dark' ? '#0D0B12' : themeMode === 'sepia' ? '#F4ECD8' : '#FAFAFA';
  const fg = themeMode === 'dark' ? '#EAE4EE' : '#1E1B18';

  return (
    <div style={{ height: '100%', background: bg, color: fg, display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '10px 16px', borderBottom: `1px solid ${withAlpha(fg, 0.12)}`, display: 'flex', alignItems: 'center', gap: 10 }}>
        <button type="button" className="bare-button" onClick={() => navigate(-1)} style={{ padding: 6 }}>
          <Icon name="arrow_back" size={20} color={fg} />
        </button>
        <div style={{ flex: 1, fontFamily: Fonts.display, fontWeight: 700, fontSize: 18, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {book.title}
        </div>
        <button type="button" className="bare-button" onClick={toggleSpeech} style={{ padding: 6 }} title={speaking ? 'Pause' : 'Listen'}>
          <Icon name={speaking ? 'stop' : 'headphones'} size={20} color={speaking ? BookColors.deepRose : fg} />
        </button>
        <button type="button" className="bare-button" onClick={() => setFontSize((f) => Math.max(13, f - 2))} style={{ padding: '4px 8px', fontSize: 13 }}>A-</button>
        <button type="button" className="bare-button" onClick={() => setFontSize((f) => Math.min(26, f + 2))} style={{ padding: '4px 8px', fontSize: 13 }}>A+</button>
        <button
          type="button"
          className="bare-button"
          onClick={() => setThemeMode((t) => (t === 'dark' ? 'sepia' : t === 'sepia' ? 'light' : 'dark'))}
          style={{ padding: '4px 10px', borderRadius: 10, border: `1px solid ${withAlpha(fg, 0.2)}`, fontSize: 12 }}
        >
          {themeMode}
        </button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '24px 20px' }}>
        {loading ? (
          <div style={{ padding: 64, textAlign: 'center', fontFamily: Fonts.display, fontSize: 18 }}>Opening the pages…</div>
        ) : text ? (
          <pre style={{ maxWidth: 680, margin: '0 auto', whiteSpace: 'pre-wrap', fontFamily: Fonts.display, fontSize, lineHeight: 1.75 }}>
            {text.slice(0, 120000)}
          </pre>
        ) : book.iaId ? (
          <iframe
            src={`https://archive.org/embed/${book.iaId}`}
            title={book.title}
            allowFullScreen
            style={{ width: '100%', height: '82vh', border: 'none', borderRadius: 12 }}
          />
        ) : (
          <div style={{ padding: 48, textAlign: 'center' }}>{error || 'No readable text found.'}</div>
        )}
      </div>
    </div>
  );
}

export function BookListPage() {
  const { width } = useViewport();
  const navigate = useNavigate();
  const location = useLocation();
  const state = (location.state as { kind?: 'popular' | 'recent' | 'category'; title?: string; category?: BookCategory; initialResults?: BookSearchResult[] } | null) ?? {};

  const [results, setResults] = useState<BookSearchResult[]>(state.initialResults ?? []);
  const [loading, setLoading] = useState(!state.initialResults?.length);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    const load = async () => {
      const res = state.category
        ? await fetchBooksBySubject(state.category.query, 30)
        : state.kind === 'recent'
          ? await fetchRecentBooks(30)
          : await fetchPopularBooks(30);
      if (alive) {
        setResults(res);
        setLoading(false);
      }
    };
    void load();
    return () => {
      alive = false;
    };
  }, [state.kind, state.category]);

  const title = state.category?.name ?? state.title ?? 'Books';
  const cols = width >= 1024 ? 7 : width >= 600 ? 5 : 3;

  return (
    <div style={{ height: '100%', overflowY: 'auto', background: BookColors.black, color: BookColors.white, padding: '16px 20px 64px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
        <button type="button" className="bare-button" onClick={() => navigate(-1)} style={{ width: 38, height: 38, borderRadius: 12, background: 'rgba(255,255,255,0.06)', display: 'grid', placeItems: 'center' }}>
          <Icon name="arrow_back_ios_new" size={16} color={BookColors.white} />
        </button>
        <h1 style={{ fontFamily: Fonts.display, fontSize: 28, fontWeight: 900, margin: 0 }}>{title}</h1>
      </div>

      {loading && results.length === 0 ? (
        <div style={{ padding: 48, textAlign: 'center', color: BookColors.muted }}>Loading…</div>
      ) : (
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
      )}
    </div>
  );
}

export function BookCategoriesPage() {
  const { width } = useViewport();
  const navigate = useNavigate();
  const cols = width >= 900 ? 4 : width >= 600 ? 3 : 2;

  return (
    <div style={{ height: '100%', overflowY: 'auto', background: BookColors.black, color: BookColors.white, padding: '16px 20px 64px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <button type="button" className="bare-button" onClick={() => navigate(-1)} style={{ width: 38, height: 38, borderRadius: 12, background: 'rgba(255,255,255,0.06)', display: 'grid', placeItems: 'center' }}>
          <Icon name="arrow_back_ios_new" size={16} color={BookColors.white} />
        </button>
        <h1 style={{ fontFamily: Fonts.display, fontSize: 28, fontWeight: 900, margin: 0 }}>Shelves</h1>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: 12 }}>
        {BOOK_CATEGORIES.map((cat) => (
          <button
            key={cat.query}
            type="button"
            className="bare-button"
            onClick={() => navigate('/books/category', { state: { category: cat } })}
            style={{
              padding: 16,
              borderRadius: 16,
              background: withAlpha(cat.color, 0.14),
              border: `1px solid ${withAlpha(cat.color, 0.3)}`,
              display: 'flex',
              alignItems: 'center',
              gap: 10,
            }}
          >
            <Icon name={cat.icon} size={22} color={cat.color} />
            <span style={{ fontSize: 14, fontWeight: 700, color: AppColors.petalWhite }}>{cat.name}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
