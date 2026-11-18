import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { OfflineIds, offlineMedia } from '../../core/services/offlineMedia';
import { Icon } from '../../shared/widgets/Icon';
import { canPop } from '../../shared/widgets/MaterialFields';
import {
  chapterDisplayTitle,
  fetchKatanaChapterPages,
  katanaCdnFallback,
  proxyKatanaImageUrl,
  saveKatanaReadingProgress,
  type KatanaChapter,
} from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';

export interface MangaReaderParams {
  slug: string;
  chapterId: string;
  mangaTitle: string;
  coverUrl: string;
  chapters: KatanaChapter[];
  initialPage?: number;
  /** The series status; a finished read needs `completed`. */
  mangaStatus?: string;
}

function normalizeAssetUrl(src: string): string {
  if (src.startsWith('assets/')) return `/${src.slice('assets/'.length)}`;
  return src;
}

function ReaderPageImage({ src, alt }: { src: string; alt: string }) {
  const [step, setStep] = useState(0);
  const resolved = src.startsWith('blob:') || src.startsWith('/') ? normalizeAssetUrl(src) : proxyKatanaImageUrl(katanaCdnFallback(src, step));
  return (
    <img
      src={resolved}
      alt={alt}
      loading="lazy"
      onError={() => setStep((s) => (s < 4 ? s + 1 : s))}
      style={{ display: 'block', width: '100%', height: 'auto' }}
    />
  );
}

export function MangaReaderView({
  params,
  onClose,
}: {
  params: MangaReaderParams;
  onClose: () => void;
}) {
  const { currentUser } = useAuth();
  const [chapterId, setChapterId] = useState(params.chapterId);
  const [pages, setPages] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [mode, setMode] = useState<'webtoon' | 'paged'>('webtoon');
  const [pageIdx, setPageIdx] = useState(Math.max(0, (params.initialPage ?? 1) - 1));
  const [server, setServer] = useState('');
  const [showUi, setShowUi] = useState(true);
  const saveTimer = useRef(0);
  const scrollRef = useRef<HTMLDivElement>(null);

  const chapter = params.chapters.find((c) => c.id === chapterId) ?? { id: chapterId, num: '', title: chapterId };
  const chapterIndex = params.chapters.findIndex((c) => c.id === chapterId);

  const persistProgress = (page: number) => {
    const safePage = Math.max(1, page);
    const finished = params.mangaStatus === 'completed' && chapterIndex === 0 && pages.length > 0 && safePage >= pages.length;
    const offlineId = OfflineIds.mangaChapterId(params.slug, chapterId);
    window.clearTimeout(saveTimer.current);
    saveTimer.current = window.setTimeout(() => {
      if (offlineMedia.getItem(offlineId)) {
        offlineMedia.updatePlaybackPosition(offlineId, safePage, true);
      }
      if (!currentUser) return;
      void saveKatanaReadingProgress({
        slug: params.slug,
        userName: currentUser,
        chapterId,
        chapterTitle: chapterDisplayTitle(chapter),
        page: safePage,
        title: params.mangaTitle,
        coverUrl: params.coverUrl,
        finished,
      });
    }, 350);
  };

  useEffect(() => () => window.clearTimeout(saveTimer.current), []);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    offlineMedia.init();
    const offlineItem = offlineMedia.getItem(OfflineIds.mangaChapterId(params.slug, chapterId));
    const loadPages = async (): Promise<string[]> => {
      if (offlineItem && offlineItem.pageUrls.length > 0) {
        const resolved = await Promise.all(
          offlineItem.pageUrls.map(async (raw, i) => {
            const cached = await offlineMedia.getMangaPageUrl(offlineItem.id, i + 1);
            return normalizeAssetUrl(cached ?? raw);
          }),
        );
        return resolved.filter(Boolean);
      }
      return fetchKatanaChapterPages(params.slug, chapterId, server);
    };
    void loadPages().then((urls) => {
      if (!alive) return;
      setPages(urls);
      setLoading(false);
    });
    if (currentUser) {
      void saveKatanaReadingProgress({
        slug: params.slug,
        userName: currentUser,
        chapterId,
        chapterTitle: chapterDisplayTitle(chapter),
        page: Math.max(1, params.initialPage ?? 1),
        title: params.mangaTitle,
        coverUrl: params.coverUrl,
      });
    }
    return () => {
      alive = false;
    };
  }, [params.slug, chapterId, server, currentUser]);

  useEffect(() => {
    if (mode === 'paged' && pages.length > 0) {
      persistProgress(pageIdx + 1);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, pageIdx]);

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 90, background: '#050508', color: KatanaColors.text, display: 'flex', flexDirection: 'column' }}>
      {showUi && (
        <div
          style={{
            padding: '10px 16px',
            background: KatanaColors.headerDark,
            borderBottom: `1px solid ${KatanaColors.border}`,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            flexWrap: 'wrap',
          }}
        >
          <button type="button" className="bare-button" onClick={onClose} style={{ padding: 6 }}>
            <Icon name="arrow_back" size={20} color={KatanaColors.accentSoft} />
          </button>
          <div style={{ flex: 1, minWidth: 160 }}>
            <div style={{ ...KatanaType.title, fontSize: 14.5 }}>{params.mangaTitle}</div>
            <div style={KatanaType.small}>{chapterDisplayTitle(chapter)}</div>
          </div>
          <select
            value={chapterId}
            onChange={(e) => { setChapterId(e.target.value); setPageIdx(0); }}
            style={{ background: KatanaColors.surfaceAlt, color: KatanaColors.text, border: `1px solid ${KatanaColors.border}`, borderRadius: 8, padding: '6px 10px', fontSize: 12.5 }}
          >
            {params.chapters.map((c) => (
              <option key={c.id} value={c.id}>{chapterDisplayTitle(c)}</option>
            ))}
          </select>
          <select
            value={server}
            onChange={(e) => setServer(e.target.value)}
            style={{ background: KatanaColors.surfaceAlt, color: KatanaColors.text, border: `1px solid ${KatanaColors.border}`, borderRadius: 8, padding: '6px 10px', fontSize: 12.5 }}
          >
            <option value="">Server 1</option>
            <option value="?sv=mk">Server 2</option>
            <option value="?sv=3">Server 3</option>
          </select>
          <button
            type="button"
            className="bare-button"
            onClick={() => setMode((m) => (m === 'webtoon' ? 'paged' : 'webtoon'))}
            style={{
              padding: '6px 12px',
              borderRadius: 8,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.border}`,
              color: KatanaColors.accentSoft,
              fontSize: 12,
              fontWeight: 600,
            }}
          >
            {mode === 'webtoon' ? 'Webtoon' : 'Paged'}
          </button>
        </div>
      )}

      <div
        ref={scrollRef}
        onScroll={() => {
          if (mode !== 'webtoon' || pages.length === 0 || !scrollRef.current) return;
          const el = scrollRef.current;
          const ratio = el.scrollHeight > el.clientHeight ? el.scrollTop / (el.scrollHeight - el.clientHeight) : 0;
          const page = Math.min(pages.length, Math.max(1, Math.round(ratio * (pages.length - 1)) + 1));
          persistProgress(page);
        }}
        onClick={() => setShowUi((s) => !s)}
        style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', alignItems: 'center' }}
      >
        {loading ? (
          <div style={{ padding: 64, textAlign: 'center' }}>
            <div style={{ ...KatanaType.title, fontSize: 14 }}>Loading {chapterDisplayTitle(chapter)}...</div>
            <div style={{ ...KatanaType.small, marginTop: 8 }}>
              Fetching pages from the source — this can take a few seconds.
            </div>
          </div>
        ) : pages.length === 0 ? (
          <div style={{ padding: 64, textAlign: 'center', ...KatanaType.body }}>
            Could not load chapter pages. Try switching servers above.
          </div>
        ) : mode === 'webtoon' ? (
          <div style={{ width: '100%', maxWidth: 850 }}>
            {pages.map((url, idx) => (
              <ReaderPageImage key={url} src={url} alt={`Page ${idx + 1}`} />
            ))}
          </div>
        ) : (
          <div style={{ width: '100%', maxWidth: 850, padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            {pages[pageIdx] && <ReaderPageImage src={pages[pageIdx]} alt={`Page ${pageIdx + 1}`} />}
            <div style={{ display: 'flex', gap: 12, alignItems: 'center' }} onClick={(e) => e.stopPropagation()}>
              <button
                type="button"
                className="bare-button"
                onClick={() => setPageIdx((p) => Math.max(0, p - 1))}
                style={{ padding: '6px 14px', borderRadius: 8, background: KatanaColors.surfaceAlt }}
              >
                Prev Page
              </button>
              <span style={KatanaType.small}>{pageIdx + 1} / {pages.length}</span>
              <button
                type="button"
                className="bare-button"
                onClick={() => setPageIdx((p) => Math.min(pages.length - 1, p + 1))}
                style={{ padding: '6px 14px', borderRadius: 8, background: KatanaColors.surfaceAlt }}
              >
                Next Page
              </button>
            </div>
          </div>
        )}
      </div>

      {showUi && (
        <div
          style={{
            padding: '10px 16px',
            background: KatanaColors.headerDark,
            borderTop: `1px solid ${KatanaColors.border}`,
            display: 'flex',
            justifyContent: 'space-between',
          }}
        >
          <button
            type="button"
            className="bare-button"
            disabled={chapterIndex >= params.chapters.length - 1}
            onClick={() => {
              const prev = params.chapters[chapterIndex + 1];
              if (prev) setChapterId(prev.id);
            }}
            style={{ ...KatanaType.small, color: KatanaColors.text }}
          >
            ← Prev Chapter
          </button>
          <button
            type="button"
            className="bare-button"
            disabled={chapterIndex <= 0}
            onClick={() => {
              const next = params.chapters[chapterIndex - 1];
              if (next) setChapterId(next.id);
            }}
            style={{ ...KatanaType.small, color: KatanaColors.accentSoft }}
          >
            Next Chapter →
          </button>
        </div>
      )}
    </div>
  );
}

export function MangaReaderPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const params = (location.state as MangaReaderParams | null) ?? null;
  if (!params) {
    return (
      <div style={{ height: '100%', display: 'grid', placeItems: 'center', background: KatanaColors.background, color: KatanaColors.text }}>
        <div style={{ textAlign: 'center' }}>
          <div style={KatanaType.heading}>Open a chapter from Mangacelestia</div>
          <button
            type="button"
            className="bare-button"
            onClick={() => navigate('/manga')}
            style={{ marginTop: 14, padding: '8px 18px', borderRadius: 99, background: KatanaColors.accent, color: '#FFF' }}
          >
            Go to Mangacelestia
          </button>
        </div>
      </div>
    );
  }
  return <MangaReaderView params={params} onClose={() => (canPop() ? navigate(-1) : navigate('/manga'))} />;
}
