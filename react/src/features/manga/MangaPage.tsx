import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useRememberedScroll } from '../../core/router/scrollMemory';
import { useAuth } from '../../core/services/auth';
import { formattedSize, offlineMedia, useOfflineMedia, type OfflineMediaItem } from '../../core/services/offlineMedia';
import { useViewport } from '../../core/system/viewport';
import { useSource } from '../../core/utils/liveSource';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { MangaHome } from './MangaHome';
import { MangaReaderView, type MangaReaderParams } from './MangaReaderPage';
import {
  KatanaBreadcrumb,
  KatanaButton,
  KatanaCard,
  KatanaCoverImage,
  KatanaHeader,
  KatanaItemCard,
  KatanaPagination,
  KatanaSectionHeader,
  type KatanaNavKey,
} from './MangaUi';
import {
  chapterDisplayTitle,
  clearKatanaReadingProgress,
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
import { clearResumeAnchor } from './readerSettings';

export function MangaPage() {
  const { width } = useViewport();
  const { currentUser, isCoupleUser, partnerUsername } = useAuth();
  const navigate = useNavigate();
  const offline = useOfflineMedia();

  const [tab, setTab] = useState<KatanaNavKey>('home');
  const [catalogMode, setCatalogMode] = useState<'directory' | 'latest' | 'new' | 'genre' | 'search'>('directory');
  const [genreSlug, setGenreSlug] = useState('');
  const [genreTitle, setGenreTitle] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [searchBy, setSearchBy] = useState<'m_name' | 'author'>('m_name');
  const [detailSlug, setDetailSlug] = useState<string | null>(null);
  const [readerParams, setReaderParams] = useState<MangaReaderParams | null>(null);
  const [showPartnerReading, setShowPartnerReading] = useState(false);
  const [resumingSlug, setResumingSlug] = useState<string | null>(null);

  // Home data
  const [homeData, setHomeData] = useState<KatanaHomeData | null>(null);
  const [homeLoading, setHomeLoading] = useState(true);
  const [typeFilter, setTypeFilter] = useState<'all' | 'manga' | 'manhwa' | 'manhua'>('all');
  const [typeItems, setTypeItems] = useState<KatanaManga[]>([]);
  const [typePage, setTypePage] = useState(1);
  const [typeHasNext, setTypeHasNext] = useState(false);
  const [typeLoading, setTypeLoading] = useState(false);

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
  const partnerBookmarks = useSource(
    () => (partnerUsername ? watchKatanaBookmarks(partnerUsername) : null),
    [partnerUsername],
    [],
  );

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
    setTypeLoading(true);
    fetchKatanaByType(typeFilter, typePage).then((res) => {
      if (!alive) return;
      setTypeItems(res.items);
      setTypeHasNext(res.hasNext);
      setTypeLoading(false);
    });
    return () => {
      alive = false;
    };
  }, [typeFilter, typePage]);

  useEffect(() => {
    const isCatalogTab = ['latest', 'directory', 'newManga'].includes(tab) || (tab === 'genres' && genreSlug !== '') || catalogMode === 'search';
    if (!isCatalogTab) return;
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
  const isHome = !detailSlug && tab === 'home' && homeData != null;
  const homeScrollRef = useRef<HTMLDivElement>(null);
  useRememberedScroll('manga:home', homeScrollRef, isHome);

  const handleNav = (next: KatanaNavKey) => {
    setDetailSlug(null);
    setTab(next);
    setCatPage(1);
    if (next === 'latest') setCatalogMode('latest');
    else if (next === 'directory') setCatalogMode('directory');
    else if (next === 'newManga') setCatalogMode('new');
    else if (next === 'genres') {
      setGenreSlug('');
      setGenreTitle('');
    }
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
    () => (showPartnerReading ? partnerBookmarks : bookmarks).filter((b) => b.lastReadChapterId),
    [bookmarks, partnerBookmarks, showPartnerReading],
  );
  const savedBookmarks = useMemo(
    () => bookmarks.filter((b) => b.bookmarked),
    [bookmarks],
  );

  const openChapter = (manga: KatanaManga, chapterId: string, initialPage = 1) => {
    const bm = bookmarks.find((b) => b.slug === manga.slug);
    setReaderParams({
      slug: manga.slug,
      chapterId,
      mangaTitle: manga.title,
      coverUrl: manga.coverUrl,
      chapters: manga.chapters,
      initialPage,
      mangaStatus: manga.status,
      finalChapterId: manga.chapters[0]?.id ?? manga.latestChapter?.id,
      readChapterIds: bm?.readChapterIds,
    });
  };

  const resumeBookmark = async (bm: KatanaBookmark) => {
    if (!bm.lastReadChapterId) {
      setDetailSlug(bm.slug);
      return;
    }
    if (resumingSlug) return;
    setResumingSlug(bm.slug);
    try {
      const loaded = await fetchKatanaDetail(bm.slug);
      if (loaded && loaded.chapters.length > 0) {
        const match = loaded.chapters.find((c) => c.id === bm.lastReadChapterId) ?? loaded.chapters[loaded.chapters.length - 1];
        openChapter(loaded, match.id, Math.max(1, bm.lastReadPage || 1));
      } else {
        setDetailSlug(bm.slug);
      }
    } catch {
      showSnackBar('Could not resume chapter — opening details');
      setDetailSlug(bm.slug);
    } finally {
      setResumingSlug(null);
    }
  };

  const openOfflineMangaChapter = (item: OfflineMediaItem) => {
    const chapterId = item.chapterId ?? '1';
    setReaderParams({
      slug: item.mediaId,
      chapterId,
      mangaTitle: item.title,
      coverUrl: item.coverUrl,
      chapters: [{ id: chapterId, num: '', title: item.subtitle || chapterId }],
      initialPage: item.lastPositionSeconds && item.lastPositionSeconds > 0 ? item.lastPositionSeconds : 1,
    });
  };

  const openBookmarkReader = (bm: KatanaBookmark) => {
    setDetailSlug(bm.slug);
  };

  const removeFromReading = async (slug: string, title: string) => {
    if (!userName || !slug) return;
    try {
      await clearKatanaReadingProgress(slug, userName);
      clearResumeAnchor(slug);
      showSnackBar(`Removed ${title || 'manga'} from Currently Reading`);
    } catch {
      showSnackBar('Could not update reading status — try again');
    }
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

      {isHome ? (
        <div ref={homeScrollRef} style={{ flex: 1, overflowY: 'auto' }}>
          <MangaHome
            width={width}
            data={homeData!}
            currentlyReading={isCoupleUser ? currentlyReading : []}
            type={typeFilter}
            typeItems={typeItems}
            typeLoading={typeLoading}
            typePage={typePage}
            typeHasNext={typeHasNext}
            onSelectType={(t) => {
              if (t === typeFilter) return;
              setTypeFilter(t);
              setTypePage(1);
              setTypeItems([]);
            }}
            onTypePage={setTypePage}
            onSelectManga={(slug) => setDetailSlug(slug)}
            onSelectGenre={handleSelectGenre}
            onOpenChapter={(m, chapterId) => openChapter(m, chapterId)}
            onViewAllReading={() => handleNav('reading')}
          />
        </div>
      ) : (
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
                <KatanaBreadcrumb
                  items={['Manga', detail.title]}
                  onHome={() => {
                    setDetailSlug(null);
                    setTab('home');
                  }}
                />
                <KatanaCard padding={16}>
                  <div style={{ display: 'flex', gap: desktop ? 20 : 14, flexWrap: desktop ? 'nowrap' : 'wrap', alignItems: 'flex-start' }}>
                    <div
                      style={{
                        position: 'relative',
                        width: desktop ? 200 : 120,
                        height: desktop ? 285 : 170,
                        borderRadius: 10,
                        border: `1px solid ${KatanaColors.borderStrong}`,
                        overflow: 'hidden',
                        flexShrink: 0,
                        background: KatanaColors.surfaceAlt,
                      }}
                    >
                      <KatanaCoverImage url={detail.coverUrl} iconSize={34} />
                    </div>
                    <div style={{ flex: 1, minWidth: 220 }}>
                      <h1 style={{ ...KatanaType.heading, fontSize: 22, margin: 0 }}>{detail.title}</h1>
                      <div style={{ height: 10 }} />
                      {detail.altNames.length > 0 && (
                        <div style={{ display: 'flex', alignItems: 'flex-start', marginBottom: 8 }}>
                          <span style={{ width: 132, flexShrink: 0, ...KatanaType.small, color: KatanaColors.textMuted }}>Alt name(s):</span>
                          <span style={{ flex: 1, ...KatanaType.body, fontSize: 13, fontWeight: 600, color: KatanaColors.text }}>{detail.altNames.join(' ; ')}</span>
                        </div>
                      )}
                      {(detail.authors.length > 0 || detail.artists.length > 0) && (
                        <div style={{ display: 'flex', alignItems: 'flex-start', marginBottom: 8 }}>
                          <span style={{ width: 132, flexShrink: 0, ...KatanaType.small, color: KatanaColors.textMuted }}>Author(s) / Artist(s):</span>
                          <span style={{ flex: 1, ...KatanaType.body, fontSize: 13, fontWeight: 600, color: KatanaColors.accent }}>{[...detail.authors, ...detail.artists].join(', ')}</span>
                        </div>
                      )}
                      {detail.genres.length > 0 && (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 10 }}>
                          {detail.genres.map((g) => (
                            <button
                              key={g.slug}
                              type="button"
                              className="bare-button"
                              onClick={() => handleSelectGenre(g)}
                              style={{
                                padding: '3px 10px',
                                borderRadius: 99,
                                border: `1px solid ${KatanaColors.border}`,
                                background: 'rgba(255,255,255,0.03)',
                                ...KatanaType.small,
                                color: KatanaColors.textMuted,
                              }}
                            >
                              {g.name}
                            </button>
                          ))}
                        </div>
                      )}
                      <div style={{ display: 'flex', alignItems: 'flex-start', marginBottom: 6 }}>
                        <span style={{ width: 132, flexShrink: 0, ...KatanaType.small, color: KatanaColors.textMuted }}>Status:</span>
                        <span style={{ flex: 1, fontSize: 13, fontWeight: 700, color: detail.status === 'completed' ? KatanaColors.green : KatanaColors.accent }}>
                          {detail.status === 'completed' ? 'Completed' : 'Ongoing'}
                        </span>
                      </div>
                      {detail.latestChapter && (
                        <div style={{ display: 'flex', alignItems: 'flex-start', marginBottom: 6 }}>
                          <span style={{ width: 132, flexShrink: 0, ...KatanaType.small, color: KatanaColors.textMuted }}>Latest chapter(s):</span>
                          <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: KatanaColors.text }}>{chapterDisplayTitle(detail.latestChapter)}</span>
                        </div>
                      )}
                      {detail.updateText && (
                        <div style={{ display: 'flex', alignItems: 'flex-start', marginBottom: 6 }}>
                          <span style={{ width: 132, flexShrink: 0, ...KatanaType.small, color: KatanaColors.textMuted }}>Update at:</span>
                          <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: KatanaColors.text }}>{detail.updateText}</span>
                        </div>
                      )}
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 14 }}>
                        {(() => {
                          const detailBm = bookmarks.find((b) => b.slug === detail.slug);
                          const isBookmarked = Boolean(detailBm?.bookmarked);
                          const hasReadingProgress = Boolean(detailBm?.lastReadChapterId);
                          return (
                            <>
                              {detail.chapters.length > 0 && (
                                <KatanaButton
                                  label={hasReadingProgress ? 'Continue' : 'First Chapter'}
                                  icon="play_arrow"
                                  onClick={() => {
                                    const target =
                                      detailBm?.lastReadChapterId || detail.chapters[detail.chapters.length - 1].id;
                                    openChapter(detail, target, detailBm?.lastReadPage || 0);
                                  }}
                                />
                              )}
                              <KatanaButton
                                label={isBookmarked ? 'Bookmarked' : 'Bookmark'}
                                icon="bookmark"
                                filled={false}
                                onClick={() => void setKatanaBookmark(detail, userName, !isBookmarked)}
                              />
                              {isCoupleUser && hasReadingProgress && (
                                <KatanaButton
                                  label="Remove from Reading"
                                  icon="close"
                                  filled={false}
                                  onClick={() => void removeFromReading(detail.slug, detail.title)}
                                />
                              )}
                            </>
                          );
                        })()}
                      </div>
                    </div>
                  </div>
                </KatanaCard>

                {detail.summary && (
                  <KatanaCard padding={16} style={{ marginTop: 14 }}>
                    <KatanaSectionHeader title="Description" />
                    <p style={{ ...KatanaType.body, marginTop: 10, marginBottom: 0 }}>{detail.summary}</p>
                  </KatanaCard>
                )}

                <KatanaCard padding={16} style={{ marginTop: 14 }}>
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
              <KatanaBreadcrumb items={['Bookmarks']} onHome={() => setTab('home')} />
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
                        <div style={{ position: 'relative', width: 64, height: 92, borderRadius: 8, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                          <KatanaCoverImage url={bm.coverUrl} iconSize={22} />
                        </div>
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
              <KatanaBreadcrumb items={['Currently Reading']} onHome={() => setTab('home')} />
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                <KatanaSectionHeader title="Currently Reading" />
                {partnerUsername && (
                  <div style={{ display: 'inline-flex', gap: 6, padding: 3, borderRadius: 99, background: KatanaColors.surfaceAlt, border: `1px solid ${KatanaColors.border}` }}>
                    {[false, true].map((partner) => {
                      const active = showPartnerReading === partner;
                      const label = partner ? (partnerUsername === 'khentsgdz' ? 'Khent' : 'Clair') : 'Mine';
                      return (
                        <button
                          key={label}
                          type="button"
                          className="bare-button"
                          onClick={() => setShowPartnerReading(partner)}
                          style={{
                            padding: '5px 12px',
                            borderRadius: 99,
                            background: active ? KatanaColors.accent : 'transparent',
                            color: active ? '#FFF' : KatanaColors.textMuted,
                            fontSize: 12,
                            fontWeight: 600,
                          }}
                        >
                          {label}
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>
              <div style={{ height: 12 }} />
              {currentlyReading.length === 0 ? (
                <KatanaCard padding={24}>
                  <div style={KatanaType.body}>
                    {showPartnerReading ? 'No reading progress recorded yet.' : 'No reading progress recorded yet.'}
                  </div>
                </KatanaCard>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {currentlyReading.map((bm) => (
                    <KatanaCard key={bm.slug} padding={12}>
                      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                        <div
                          onClick={() => openBookmarkReader(bm)}
                          style={{ display: 'flex', gap: 12, cursor: 'pointer', alignItems: 'center', flex: 1, minWidth: 0 }}
                        >
                          <div style={{ position: 'relative', width: 54, height: 76, borderRadius: 8, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                            <KatanaCoverImage url={bm.coverUrl} iconSize={20} />
                          </div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={KatanaType.title}>{bm.title}</div>
                            <div style={{ ...KatanaType.small, color: KatanaColors.accentSoft, marginTop: 4 }}>
                              {bm.lastReadChapterTitle} · Page {bm.lastReadPage || 1}
                            </div>
                          </div>
                        </div>
                        <button
                          type="button"
                          className="bare-button"
                          aria-label={`Resume ${bm.title}`}
                          onClick={() => void resumeBookmark(bm)}
                          style={{
                            width: 38,
                            height: 38,
                            borderRadius: '50%',
                            background: KatanaColors.surfaceAlt,
                            border: `1px solid ${KatanaColors.border}`,
                            display: 'grid',
                            placeItems: 'center',
                            flexShrink: 0,
                          }}
                        >
                          <Icon name={resumingSlug === bm.slug ? 'hourglass_top' : 'play_arrow'} size={20} color={KatanaColors.accent} />
                        </button>
                        {!showPartnerReading && (
                          <button
                            type="button"
                            className="bare-button"
                            aria-label={`Remove ${bm.title} from reading`}
                            title="Remove from Currently Reading"
                            onClick={() => void removeFromReading(bm.slug, bm.title)}
                            style={{
                              width: 38,
                              height: 38,
                              borderRadius: '50%',
                              background: KatanaColors.surfaceAlt,
                              border: `1px solid ${KatanaColors.border}`,
                              display: 'grid',
                              placeItems: 'center',
                              flexShrink: 0,
                            }}
                          >
                            <Icon name="close" size={18} color={KatanaColors.textMuted} />
                          </button>
                        )}
                      </div>
                    </KatanaCard>
                  ))}
                </div>
              )}
            </div>
          ) : tab === 'downloads' ? (
            <KatanaDownloadsView
              items={offline.mangaItems}
              storage={offline.formattedMangaStorage}
              onOpen={openOfflineMangaChapter}
              onDelete={(id) => void offlineMedia.deleteDownload(id)}
              onClearAll={() =>
                void showDialog<void>((close) => (
                  <AlertDialog
                    background={KatanaColors.surface}
                    title={<div style={KatanaType.title}>Clear Manga Downloads</div>}
                    content={<div style={KatanaType.small}>Remove all offline manga chapters from this device?</div>}
                    actions={[
                      <TextButton key="cancel" onPressed={() => close(null)} color={KatanaColors.textMuted}>Cancel</TextButton>,
                      <TextButton
                        key="clear"
                        color="#FF453A"
                        onPressed={() => {
                          close(null);
                          void offlineMedia.clearAll('manga');
                        }}
                      >
                        Clear All
                      </TextButton>,
                    ]}
                  />
                ))
              }
              onBrowse={() => handleNav('home')}
            />
          ) : tab === 'genres' && !genreSlug ? (
            <div>
              <KatanaBreadcrumb items={['Genres']} onHome={() => setTab('home')} />
              <KatanaSectionHeader title="Genres" trailing={<span style={KatanaType.small}>{(homeData?.genres ?? []).length} genres</span>} />
              <div style={{ height: 12 }} />
              <div style={{ display: 'grid', gridTemplateColumns: desktop ? 'repeat(3, minmax(0, 1fr))' : 'repeat(2, minmax(0, 1fr))', gap: 10 }}>
                {(homeData?.genres ?? []).map((g) => (
                  <KatanaCard key={g.slug} padding={12}>
                    <button
                      type="button"
                      className="bare-button"
                      onClick={() => handleSelectGenre(g)}
                      style={{ width: '100%', textAlign: 'left', display: 'flex', flexDirection: 'column', gap: 6 }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span style={{ ...KatanaType.title, color: KatanaColors.link, fontSize: 14, flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {g.name}
                        </span>
                        {g.count > 0 && (
                          <span style={{ padding: '2px 7px', borderRadius: 10, background: 'rgba(194,24,91,0.12)', ...KatanaType.accent, fontSize: 11 }}>
                            {g.count}
                          </span>
                        )}
                      </div>
                      {g.description && <div className="clamp-2" style={{ ...KatanaType.small, fontSize: 11 }}>{g.description}</div>}
                    </button>
                  </KatanaCard>
                ))}
              </div>
            </div>
          ) : tab !== 'home' ? (
            <div>
              <KatanaBreadcrumb
                items={[
                  catalogMode === 'search'
                    ? `Search: "${searchQuery}"`
                    : catalogMode === 'genre'
                      ? genreTitle || genreSlug
                      : catalogMode === 'latest'
                        ? 'Latest Update'
                        : catalogMode === 'new'
                          ? 'New Manga'
                          : 'Manga Directory',
                ]}
                onHome={() => setTab('home')}
              />
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
          ) : null}
        </div>
      </div>
      )}

      {readerParams && <MangaReaderView params={readerParams} onClose={() => setReaderParams(null)} />}
    </div>
  );
}

function KatanaDownloadsView({
  items,
  storage,
  onOpen,
  onDelete,
  onClearAll,
  onBrowse,
}: {
  items: OfflineMediaItem[];
  storage: string;
  onOpen: (item: OfflineMediaItem) => void;
  onDelete: (id: string) => void;
  onClearAll: () => void;
  onBrowse: () => void;
}) {
  const groups = new Map<string, OfflineMediaItem[]>();
  for (const it of items) {
    const list = groups.get(it.mediaId) ?? [];
    list.push(it);
    groups.set(it.mediaId, list);
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <KatanaSectionHeader
          title="Downloads"
          badge={items.length > 0 ? String(items.length) : undefined}
        />
        {items.length > 0 && (
          <button
            type="button"
            className="bare-button"
            onClick={onClearAll}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '6px 10px' }}
          >
            <Icon name="delete_sweep" variant="outlined" size={18} color={KatanaColors.textLight} />
            <span style={KatanaType.small}>Clear All</span>
          </button>
        )}
      </div>
      <div style={{ height: 14 }} />
      {items.length === 0 ? (
        <KatanaCard padding={32} style={{ textAlign: 'center' }}>
          <Icon name="download_done" size={44} color={KatanaColors.textLight} />
          <div style={{ ...KatanaType.title, marginTop: 12 }}>No offline chapters yet</div>
          <div style={{ ...KatanaType.small, marginTop: 6 }}>Chapters saved for offline reading will appear here.</div>
          <div style={{ marginTop: 16, display: 'flex', justifyContent: 'center' }}>
            <KatanaButton label="Browse Manga" icon="home" onClick={onBrowse} />
          </div>
        </KatanaCard>
      ) : (
        <>
          <KatanaCard padding={14} style={{ marginBottom: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="storage" size={18} color={KatanaColors.accent} />
                <span style={KatanaType.small}>Offline storage used</span>
              </div>
              <span style={{ ...KatanaType.title, fontSize: 13.5 }}>{storage}</span>
            </div>
          </KatanaCard>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[...groups.values()].map((chapters) => {
              const head = chapters[0];
              return (
                <KatanaCard key={head.mediaId} padding={0} style={{ overflow: 'hidden' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderBottom: `1px solid ${KatanaColors.border}` }}>
                    <div style={{ position: 'relative', width: 44, height: 62, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                      <KatanaCoverImage url={head.coverUrl} iconSize={18} />
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={KatanaType.title}>{head.title}</div>
                      <div style={KatanaType.small}>
                        {chapters.length} {chapters.length === 1 ? 'chapter' : 'chapters'} offline
                      </div>
                    </div>
                  </div>
                  {chapters.map((ch, idx) => (
                    <div
                      key={ch.id}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 10,
                        padding: '10px 12px',
                        borderTop: idx > 0 ? `1px solid ${KatanaColors.border}` : undefined,
                      }}
                    >
                      <button
                        type="button"
                        className="bare-button"
                        onClick={() => onOpen(ch)}
                        style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 10, textAlign: 'left' }}
                      >
                        <Icon name="menu_book" size={18} color={KatanaColors.accentSoft} />
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ ...KatanaType.title, fontSize: 13 }}>{ch.subtitle || `Chapter ${ch.chapterId ?? ''}`}</div>
                          <div style={KatanaType.small}>{formattedSize(ch)}</div>
                        </div>
                      </button>
                      <button
                        type="button"
                        className="bare-button"
                        aria-label={`Delete ${ch.subtitle || ch.title}`}
                        onClick={() => onDelete(ch.id)}
                        style={{ width: 32, height: 32, display: 'grid', placeItems: 'center' }}
                      >
                        <Icon name="delete_outline" size={18} color={KatanaColors.textLight} />
                      </button>
                    </div>
                  ))}
                </KatanaCard>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
