import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { Align, linear } from '../../core/theme/paint';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { MangaReaderView, type MangaReaderParams } from './MangaReaderPage';
import {
  KatanaButton,
  KatanaCard,
  KatanaCompactCard,
  KatanaHeader,
  KatanaItemCard,
  KatanaPagination,
  KatanaSectionHeader,
  type KatanaNavKey,
} from './MangaUi';
import {
  chapterDisplayTitle,
  fetchKatanaByType,
  fetchKatanaCatalog,
  fetchKatanaDetail,
  fetchKatanaHome,
  setKatanaBookmark,
  watchKatanaBookmarks,
  type KatanaBookmark,
  type KatanaGenre,
  type KatanaHomeData,
  type KatanaManga,
} from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';

export function MangaPage() {
  const { width } = useViewport();
  const { currentUser, isCoupleUser } = useAuth();
  const navigate = useNavigate();

  const [tab, setTab] = useState<KatanaNavKey>('home');
  const [catalogMode, setCatalogMode] = useState<'directory' | 'latest' | 'new' | 'genre' | 'search'>('directory');
  const [genreSlug, setGenreSlug] = useState('');
  const [genreTitle, setGenreTitle] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [searchBy, setSearchBy] = useState<'m_name' | 'author'>('m_name');
  const [detailSlug, setDetailSlug] = useState<string | null>(null);
  const [readerParams, setReaderParams] = useState<MangaReaderParams | null>(null);

  // Home data
  const [homeData, setHomeData] = useState<KatanaHomeData | null>(null);
  const [homeLoading, setHomeLoading] = useState(true);
  const [typeFilter, setTypeFilter] = useState<'all' | 'manga' | 'manhwa' | 'manhua'>('all');
  const [typeItems, setTypeItems] = useState<KatanaManga[]>([]);
  const [typePage, setTypePage] = useState(1);
  const [typeHasNext, setTypeHasNext] = useState(false);

  // Catalog data
  const [catItems, setCatItems] = useState<KatanaManga[]>([]);
  const [catPage, setCatPage] = useState(1);
  const [catHasNext, setCatHasNext] = useState(false);
  const [catLoading, setCatLoading] = useState(false);

  // Detail data
  const [detail, setDetail] = useState<KatanaManga | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const userName = currentUser ?? '';
  const bookmarks = useSource(() => watchKatanaBookmarks(userName), [userName], []);

  useEffect(() => {
    let alive = true;
    setHomeLoading(true);
    fetchKatanaHome().then((d) => {
      if (!alive) return;
      setHomeData(d);
      setHomeLoading(false);
    });
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    if (typeFilter === 'all') return;
    let alive = true;
    fetchKatanaByType(typeFilter, typePage).then((res) => {
      if (!alive) return;
      setTypeItems(res.items);
      setTypeHasNext(res.hasNext);
    });
    return () => {
      alive = false;
    };
  }, [typeFilter, typePage]);

  useEffect(() => {
    if (!['latest', 'directory', 'newManga', 'genres'].includes(tab) && catalogMode !== 'search') return;
    let alive = true;
    setCatLoading(true);
    fetchKatanaCatalog({
      mode: catalogMode,
      key: genreSlug,
      page: catPage,
      query: searchQuery,
      searchBy,
    }).then((res) => {
      if (!alive) return;
      setCatItems(res.items);
      setCatHasNext(res.hasNext);
      setCatLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [tab, catalogMode, genreSlug, catPage, searchQuery, searchBy]);

  useEffect(() => {
    if (!detailSlug) return;
    let alive = true;
    setDetailLoading(true);
    fetchKatanaDetail(detailSlug).then((d) => {
      if (!alive) return;
      setDetail(d);
      setDetailLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [detailSlug]);

  const desktop = width >= 960;
  const compactCard = width < 720;

  const handleNav = (next: KatanaNavKey) => {
    setDetailSlug(null);
    setTab(next);
    setCatPage(1);
    if (next === 'latest') setCatalogMode('latest');
    else if (next === 'directory') setCatalogMode('directory');
    else if (next === 'newManga') setCatalogMode('new');
  };

  const handleSelectGenre = (g: KatanaGenre) => {
    setDetailSlug(null);
    setGenreSlug(g.slug);
    setGenreTitle(g.name);
    setCatalogMode('genre');
    setTab('genres');
    setCatPage(1);
  };

  const currentlyReading = useMemo(
    () => bookmarks.filter((b) => b.lastReadChapterId),
    [bookmarks],
  );
  const savedBookmarks = useMemo(
    () => bookmarks.filter((b) => b.bookmarked),
    [bookmarks],
  );

  const openChapter = (manga: KatanaManga, chapterId: string, initialPage = 1) => {
    setReaderParams({
      slug: manga.slug,
      chapterId,
      mangaTitle: manga.title,
      coverUrl: manga.coverUrl,
      chapters: manga.chapters,
      initialPage,
    });
  };

  const openBookmarkReader = (bm: KatanaBookmark) => {
    setDetailSlug(bm.slug);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: KatanaColors.background, color: KatanaColors.text }}>
      <KatanaHeader
        active={tab}
        width={width}
        userName={userName}
        showBack={isCoupleUser}
        genres={homeData?.genres ?? []}
        onBack={() => navigate('/dashboard')}
        onSelectNav={handleNav}
        onSubmitSearch={(q, by) => {
          setDetailSlug(null);
          setSearchQuery(q);
          setSearchBy(by);
          setCatalogMode('search');
          setTab('directory');
          setCatPage(1);
        }}
        onSelectManga={(slug) => setDetailSlug(slug)}
        onSelectGenre={handleSelectGenre}
      />

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 60px' }}>
        <div style={{ maxWidth: 1240, margin: '0 auto' }}>
          {detailSlug ? (
            detailLoading ? (
              <div style={{ padding: 48, textAlign: 'center', ...KatanaType.body }}>Loading manga details…</div>
            ) : !detail ? (
              <KatanaCard padding={24} style={{ textAlign: 'center' }}>
                <div style={KatanaType.body}>Could not load this manga.</div>
                <div style={{ marginTop: 14 }}>
                  <KatanaButton label="Back" icon="arrow_back" onClick={() => setDetailSlug(null)} />
                </div>
              </KatanaCard>
            ) : (
              <div>
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => setDetailSlug(null)}
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginBottom: 14, ...KatanaType.small, color: KatanaColors.accentSoft }}
                >
                  <Icon name="arrow_back" size={16} color={KatanaColors.accentSoft} />
                  Back
                </button>
                <KatanaCard padding={18}>
                  <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap' }}>
                    {detail.coverUrl && (
                      <img src={detail.coverUrl} alt={detail.title} style={{ width: 150, height: 220, borderRadius: 10, objectFit: 'cover' }} />
                    )}
                    <div style={{ flex: 1, minWidth: 220 }}>
                      <h1 style={{ ...KatanaType.heading, margin: 0 }}>{detail.title}</h1>
                      {detail.authors.length > 0 && (
                        <div style={{ ...KatanaType.small, marginTop: 6 }}>Author(s): {detail.authors.join(', ')}</div>
                      )}
                      {detail.summary && (
                        <p style={{ ...KatanaType.body, marginTop: 10 }}>{detail.summary}</p>
                      )}
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 14 }}>
                        {detail.chapters.length > 0 && (
                          <KatanaButton
                            label="Read Latest"
                            icon="menu_book"
                            onClick={() => openChapter(detail, detail.chapters[0].id)}
                          />
                        )}
                        <KatanaButton
                          label={bookmarks.some((b) => b.slug === detail.slug && b.bookmarked) ? 'Bookmarked' : 'Bookmark'}
                          icon="bookmark"
                          filled={false}
                          onClick={() =>
                            void setKatanaBookmark(
                              detail,
                              userName,
                              !bookmarks.some((b) => b.slug === detail.slug && b.bookmarked),
                            )
                          }
                        />
                      </div>
                    </div>
                  </div>
                </KatanaCard>

                <KatanaCard padding={16} style={{ marginTop: 16 }}>
                  <KatanaSectionHeader title={`Chapters (${detail.chapters.length})`} />
                  <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {detail.chapters.map((c) => (
                      <button
                        key={c.id}
                        type="button"
                        className="bare-button"
                        onClick={() => openChapter(detail, c.id)}
                        style={{
                          padding: '10px 12px',
                          borderRadius: 8,
                          background: KatanaColors.surfaceAlt,
                          border: `1px solid ${KatanaColors.border}`,
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <span style={{ ...KatanaType.title, fontSize: 13.5 }}>{chapterDisplayTitle(c)}</span>
                        <Icon name="chevron_right" size={18} color={KatanaColors.textLight} />
                      </button>
                    ))}
                  </div>
                </KatanaCard>
              </div>
            )
          ) : tab === 'bookmarks' ? (
            <div>
              <KatanaSectionHeader title="Bookmarks" />
              <div style={{ height: 12 }} />
              {savedBookmarks.length === 0 ? (
                <KatanaCard padding={24}>
                  <div style={KatanaType.body}>No bookmarks saved yet.</div>
                </KatanaCard>
              ) : (
                <div style={{ display: 'grid', gridTemplateColumns: desktop ? 'repeat(2, minmax(0, 1fr))' : '1fr', gap: 12 }}>
                  {savedBookmarks.map((bm) => (
                    <KatanaCard key={bm.slug} padding={12}>
                      <div onClick={() => openBookmarkReader(bm)} style={{ display: 'flex', gap: 12, cursor: 'pointer' }}>
                        {bm.coverUrl && <img src={bm.coverUrl} alt={bm.title} style={{ width: 64, height: 92, borderRadius: 8, objectFit: 'cover' }} />}
                        <div>
                          <div style={KatanaType.title}>{bm.title}</div>
                          {bm.lastReadChapterTitle && (
                            <div style={{ ...KatanaType.small, color: KatanaColors.accentSoft, marginTop: 4 }}>
                              Continue: {bm.lastReadChapterTitle}
                            </div>
                          )}
                        </div>
                      </div>
                    </KatanaCard>
                  ))}
                </div>
              )}
            </div>
          ) : tab === 'reading' ? (
            <div>
              <KatanaSectionHeader title="Currently Reading" />
              <div style={{ height: 12 }} />
              {currentlyReading.length === 0 ? (
                <KatanaCard padding={24}>
                  <div style={KatanaType.body}>No reading progress recorded yet.</div>
                </KatanaCard>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {currentlyReading.map((bm) => (
                    <KatanaCard key={bm.slug} padding={12}>
                      <div onClick={() => openBookmarkReader(bm)} style={{ display: 'flex', gap: 12, cursor: 'pointer', alignItems: 'center' }}>
                        {bm.coverUrl && <img src={bm.coverUrl} alt={bm.title} style={{ width: 54, height: 76, borderRadius: 8, objectFit: 'cover' }} />}
                        <div style={{ flex: 1 }}>
                          <div style={KatanaType.title}>{bm.title}</div>
                          <div style={{ ...KatanaType.small, color: KatanaColors.accentSoft, marginTop: 4 }}>
                            {bm.lastReadChapterTitle} · Page {bm.lastReadPage || 1}
                          </div>
                        </div>
                        <Icon name="play_arrow" size={20} color={KatanaColors.accent} />
                      </div>
                    </KatanaCard>
                  ))}
                </div>
              )}
            </div>
          ) : tab === 'downloads' ? (
            <KatanaCard padding={32} style={{ textAlign: 'center' }}>
              <Icon name="download_done" size={44} color={KatanaColors.textLight} />
              <div style={{ ...KatanaType.title, marginTop: 12 }}>No offline chapters yet</div>
              <div style={{ ...KatanaType.small, marginTop: 6 }}>Offline downloads are stored on the native/desktop app.</div>
            </KatanaCard>
          ) : tab !== 'home' ? (
            <div>
              <KatanaSectionHeader
                title={
                  catalogMode === 'search'
                    ? `Results for "${searchQuery}"`
                    : catalogMode === 'genre'
                      ? genreTitle || genreSlug
                      : catalogMode === 'latest'
                        ? 'Latest Update'
                        : catalogMode === 'new'
                          ? 'New Manga'
                          : 'Manga Directory'
                }
              />
              <div style={{ height: 12 }} />
              {catLoading ? (
                <div style={{ padding: 48, textAlign: 'center', ...KatanaType.body }}>Loading…</div>
              ) : catItems.length === 0 ? (
                <KatanaCard padding={20}>
                  <div style={KatanaType.small}>Nothing found yet.</div>
                </KatanaCard>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {catItems.map((m) => (
                    <KatanaItemCard
                      key={m.slug}
                      manga={m}
                      compact={compactCard}
                      onSelectManga={(slug) => setDetailSlug(slug)}
                      onSelectGenre={handleSelectGenre}
                    />
                  ))}
                  <div style={{ height: 6 }} />
                  <KatanaPagination page={catPage} hasPrev={catPage > 1} hasNext={catHasNext} onPageChange={setCatPage} />
                </div>
              )}
            </div>
          ) : homeLoading && !homeData ? (
            <div style={{ padding: 48, textAlign: 'center', ...KatanaType.body }}>Loading MangaCelestia…</div>
          ) : (
            <div>
              <div className="no-scrollbar" style={{ display: 'flex', gap: 8, overflowX: 'auto', marginBottom: 14 }}>
                {(['all', 'manga', 'manhwa', 'manhua'] as const).map((t) => {
                  const selected = typeFilter === t;
                  return (
                    <button
                      key={t}
                      type="button"
                      className="bare-button"
                      onClick={() => { setTypeFilter(t); setTypePage(1); }}
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                        padding: '8px 15px',
                        borderRadius: 99,
                        background: selected
                          ? linear([KatanaColors.accent, KatanaColors.accentDark], { begin: Align.topLeft, end: Align.bottomRight })
                          : KatanaColors.surfaceAlt,
                        border: `1px solid ${selected ? KatanaColors.accentSoft : KatanaColors.border}`,
                        flexShrink: 0,
                      }}
                    >
                      <Icon name={t === 'all' ? 'all_inclusive' : 'menu_book'} size={15} color={selected ? '#FFFFFF' : KatanaColors.accentSoft} />
                      <span style={{ ...KatanaType.title, fontSize: 12.5, color: selected ? '#FFFFFF' : KatanaColors.text }}>
                        {t === 'all' ? 'All' : t[0].toUpperCase() + t.slice(1)}
                      </span>
                    </button>
                  );
                })}
              </div>

              {desktop && typeFilter === 'all' && (homeData?.hotUpdates.length ?? 0) > 0 && (
                <KatanaCard padding={14} style={{ marginBottom: 14 }}>
                  <KatanaSectionHeader title="Hot Updates" trailing={<Icon name="whatshot" size={20} color={KatanaColors.orange} />} />
                  <div className="no-scrollbar" style={{ display: 'flex', gap: 10, overflowX: 'auto', marginTop: 10 }}>
                    {homeData!.hotUpdates.map((m) => (
                      <KatanaCompactCard key={m.slug} manga={m} width={120} onSelect={() => setDetailSlug(m.slug)} />
                    ))}
                  </div>
                </KatanaCard>
              )}

              <div style={{ display: desktop ? 'flex' : 'block', gap: 16, alignItems: 'flex-start' }}>
                <div style={{ flex: 7, minWidth: 0 }}>
                  <KatanaSectionHeader title={typeFilter === 'all' ? 'Latest Updates' : typeFilter[0].toUpperCase() + typeFilter.slice(1)} />
                  <div style={{ height: 12 }} />
                  {(typeFilter === 'all' ? homeData?.latest ?? [] : typeItems).length === 0 ? (
                    <KatanaCard padding={20}>
                      <div style={KatanaType.small}>Nothing updated yet.</div>
                    </KatanaCard>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                      {(typeFilter === 'all' ? homeData!.latest : typeItems).map((m) => (
                        <KatanaItemCard
                          key={m.slug}
                          manga={m}
                          compact={compactCard}
                          onSelectManga={(slug) => setDetailSlug(slug)}
                          onSelectGenre={handleSelectGenre}
                        />
                      ))}
                      {typeFilter !== 'all' && (
                        <KatanaPagination page={typePage} hasPrev={typePage > 1} hasNext={typeHasNext} onPageChange={setTypePage} />
                      )}
                    </div>
                  )}
                </div>

                {desktop && (
                  <div style={{ width: 330, flexShrink: 0, display: 'flex', flexDirection: 'column', gap: 16 }}>
                    {(homeData?.genres.length ?? 0) > 0 && (
                      <KatanaCard padding={14}>
                        <KatanaSectionHeader title="Genres" />
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7, marginTop: 12 }}>
                          {homeData!.genres.map((g) => (
                            <button
                              key={g.slug}
                              type="button"
                              className="bare-button"
                              onClick={() => handleSelectGenre(g)}
                              style={{
                                padding: '5px 10px',
                                borderRadius: 4,
                                background: KatanaColors.surfaceAlt,
                                border: `1px solid ${KatanaColors.border}`,
                                fontSize: 12,
                                color: KatanaColors.text,
                                fontWeight: 600,
                              }}
                            >
                              {g.name}
                            </button>
                          ))}
                        </div>
                      </KatanaCard>
                    )}
                    {typeFilter === 'all' && (homeData?.hot.length ?? 0) > 0 && (
                      <KatanaCard padding={14}>
                        <KatanaSectionHeader title="Hot Manga" trailing={<Icon name="local_fire_department" size={20} color={KatanaColors.orange} />} />
                        <div className="no-scrollbar" style={{ display: 'flex', gap: 10, overflowX: 'auto', marginTop: 10 }}>
                          {homeData!.hot.map((m) => (
                            <KatanaCompactCard key={m.slug} manga={m} width={96} onSelect={() => setDetailSlug(m.slug)} />
                          ))}
                        </div>
                      </KatanaCard>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {readerParams && <MangaReaderView params={readerParams} onClose={() => setReaderParams(null)} />}
    </div>
  );
}
