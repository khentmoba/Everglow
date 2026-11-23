import { useEffect, useMemo, useState } from 'react';
import { formattedSize, offlineMedia, type OfflineMediaItem } from '../../core/services/offlineMedia';
import { withAlpha } from '../../core/theme/colors';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { chapterDisplayTitle, proxyKatanaImageUrl, type KatanaChapter, type KatanaManga } from './katanaService';
import { estimateMangaBatchMegabytes } from './mangaSearchAndTrust';
import { KatanaColors, KatanaFonts as Fonts, KatanaType } from './katanaTokens';
import {
  KatanaButton,
  KatanaCard,
  KatanaCoverImage,
  KatanaEmptyState,
  KatanaSectionHeader,
} from './MangaUi';

export type UnknownNetworkWifiPolicy = 'ask' | 'allow' | 'block';
const UNKNOWN_NETWORK_WIFI_POLICY_KEY = 'katana_unknown_network_wifi_policy_v1';

export function loadUnknownNetworkWifiPolicy(): UnknownNetworkWifiPolicy {
  try {
    const raw = localStorage.getItem(UNKNOWN_NETWORK_WIFI_POLICY_KEY);
    if (raw === 'allow' || raw === 'block' || raw === 'ask') return raw;
  } catch {
    // ignore storage errors
  }
  return 'ask';
}

export function saveUnknownNetworkWifiPolicy(policy: UnknownNetworkWifiPolicy): void {
  try {
    localStorage.setItem(UNKNOWN_NETWORK_WIFI_POLICY_KEY, policy);
  } catch {
    // ignore storage errors
  }
}

export function supportsNetworkConnectionApi(): boolean {
  if (typeof navigator === 'undefined') return false;
  const nav = navigator as Navigator & { connection?: { type?: string; saveData?: boolean } };
  return Boolean(nav.connection);
}

export function isOnMeteredCellular(): boolean {
  const nav = navigator as Navigator & { connection?: { type?: string; saveData?: boolean } };
  if (nav.connection) {
    return nav.connection.type === 'cellular' || nav.connection.saveData === true;
  }
  return loadUnknownNetworkWifiPolicy() === 'block';
}

export function KatanaDownloadsView({
  items,
  storage,
  readChapterIdsBySlug,
  wifiOnly,
  onToggleWifiOnly,
  autoDownloadNext,
  onChangeAutoDownloadNext,
  autoDownloadCategories,
  allCategories,
  onToggleAutoDownloadCategory,
  batchProgress,
  downloadQueue,
  failedDownloads,
  onMoveQueueItem,
  onRemoveQueueItem,
  onCancelQueue,
  onRetryFailed,
  onRetrySingleFailed,
  onClearFailed,
  onOpen,
  onOpenSeries,
  onDelete,
  onDeleteMany,
  onClearAll,
  onBrowse,
}: {
  items: OfflineMediaItem[];
  storage: string;
  readChapterIdsBySlug: Record<string, Set<string>>;
  wifiOnly: boolean;
  onToggleWifiOnly: () => void;
  autoDownloadNext: number;
  onChangeAutoDownloadNext: (count: number) => void;
  autoDownloadCategories: string[];
  allCategories: string[];
  onToggleAutoDownloadCategory: (category: string) => void;
  batchProgress: { done: number; total: number; currentTitle?: string } | null;
  downloadQueue: Array<{ manga: KatanaManga; chapter: KatanaChapter }>;
  failedDownloads: Array<{ manga: KatanaManga; chapter: KatanaChapter }>;
  onMoveQueueItem: (index: number, delta: -1 | 1) => void;
  onRemoveQueueItem: (index: number) => void;
  onCancelQueue: () => void;
  onRetryFailed: () => void;
  onRetrySingleFailed: (index: number) => void;
  onClearFailed: () => void;
  onOpen: (item: OfflineMediaItem) => void;
  onOpenSeries: (slug: string) => void;
  onDelete: (id: string) => void;
  onDeleteMany: (ids: string[]) => void;
  onClearAll: () => void;
  onBrowse: () => void;
}) {
  const [sortBy, setSortBy] = useState<'recent' | 'title' | 'chapters'>('recent');
  const [dlSelectMode, setDlSelectMode] = useState(false);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set());
  const [quotaInfo, setQuotaInfo] = useState<{ usage: number; quota: number } | null>(null);
  const [persisted, setPersisted] = useState<boolean | null>(null);
  const [verifyingCache, setVerifyingCache] = useState(false);
  const [repairingAll, setRepairingAll] = useState(false);
  const [unknownWifiPolicy, setUnknownWifiPolicy] = useState<UnknownNetworkWifiPolicy>(() =>
    loadUnknownNetworkWifiPolicy(),
  );

  useEffect(() => {
    if (items.length === 0) return;
    void offlineMedia.verifyAllMangaChaptersCache();
  }, [items.length]);

  const evictedItems = useMemo(
    () => items.filter((it) => it.status === 'completed' && (it.cacheMissingPages ?? 0) > 0),
    [items],
  );

  const handleVerifyCache = async () => {
    if (verifyingCache) return;
    setVerifyingCache(true);
    try {
      const res = await offlineMedia.verifyAllMangaChaptersCache();
      if (res.evictedChapters > 0) {
        showSnackBar(
          `Found ${res.missingPages} evicted page(s) across ${res.evictedChapters} chapter(s) — tap Repair to restore`,
        );
      } else {
        showSnackBar(`Verified ${res.checked} offline chapter(s) — all cached pages intact`);
      }
    } finally {
      setVerifyingCache(false);
    }
  };

  const handleRepairAllEvicted = async () => {
    if (repairingAll || evictedItems.length === 0) return;
    setRepairingAll(true);
    try {
      const count = await offlineMedia.repairAllEvictedMangaChapters(proxyKatanaImageUrl);
      showSnackBar(`Repaired ${count} chapter(s) in offline cache`);
    } finally {
      setRepairingAll(false);
    }
  };

  const onChangeUnknownWifiPolicy = (nextPolicy: UnknownNetworkWifiPolicy) => {
    setUnknownWifiPolicy(nextPolicy);
    saveUnknownNetworkWifiPolicy(nextPolicy);
    showSnackBar(
      nextPolicy === 'allow'
        ? 'Unverified connections (e.g. iOS Safari) will be treated as Wi-Fi'
        : nextPolicy === 'block'
          ? 'Unverified connections will block downloads to save cellular data'
          : 'Unverified connections will ask for confirmation before downloading',
    );
  };

  useEffect(() => {
    let active = true;
    navigator.storage?.persisted?.()
      .then((v) => {
        if (active) setPersisted(v);
      })
      .catch(() => {});
    return () => {
      active = false;
    };
  }, []);

  const keepOffline = () => {
    if (!navigator.storage?.persist) return;
    navigator.storage
      .persist()
      .then((ok) => {
        setPersisted(ok);
        showSnackBar(ok ? 'Offline chapters are protected from cleanup' : 'This browser may still clear them when space runs low');
      })
      .catch(() => showSnackBar('Could not change storage protection'));
  };

  const seriesBytes = (chapters: OfflineMediaItem[]) => {
    const bytes = chapters.reduce((sum, c) => sum + (c.downloadedBytes > 0 ? c.downloadedBytes : c.totalBytes || 0), 0);
    if (bytes <= 0) return '';
    return bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : bytes >= 1e6 ? `${(bytes / 1e6).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;
  };

  useEffect(() => {
    let active = true;
    if (typeof navigator !== 'undefined' && navigator.storage?.estimate) {
      navigator.storage
        .estimate()
        .then((est) => {
          if (active && typeof est.usage === 'number' && typeof est.quota === 'number' && est.quota > 0) {
            setQuotaInfo({ usage: est.usage, quota: est.quota });
          }
        })
        .catch(() => {});
    }
    return () => {
      active = false;
    };
  }, [items.length]);

  const grouped = useMemo(() => {
    const groups = new Map<string, OfflineMediaItem[]>();
    for (const it of items) {
      const list = groups.get(it.mediaId) ?? [];
      list.push(it);
      groups.set(it.mediaId, list);
    }
    const entries = [...groups.values()];
    if (sortBy === 'title') {
      entries.sort((a, b) => a[0].title.localeCompare(b[0].title));
    } else if (sortBy === 'chapters') {
      entries.sort((a, b) => b.length - a.length || a[0].title.localeCompare(b[0].title));
    }
    return entries;
  }, [items, sortBy]);

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const readDownloadIds = useMemo(
    () => items.filter((it) => it.chapterId && readChapterIdsBySlug[it.mediaId]?.has(it.chapterId)).map((it) => it.id),
    [items, readChapterIdsBySlug],
  );

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
        <KatanaSectionHeader title="Downloads" badge={items.length > 0 ? String(items.length) : undefined} />
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <label
            title="Import one or multiple .cbz chapter archives"
            style={{
              minHeight: 40,
              padding: '6px 12px',
              borderRadius: 8,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.borderStrong}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
              fontFamily: Fonts.body,
              fontSize: 12,
              fontWeight: 700,
              color: KatanaColors.link,
              cursor: 'pointer',
            }}
          >
            <Icon name="folder_zip" size={15} color={KatanaColors.link} />
            <span>Import CBZ</span>
            <input
              type="file"
              multiple
              accept=".cbz,application/vnd.comicbook+zip,application/zip"
              style={{ display: 'none' }}
              onChange={async (e) => {
                const files = Array.from(e.target.files ?? []).filter((f) =>
                  f.name.toLowerCase().endsWith('.cbz') || f.name.toLowerCase().endsWith('.zip'),
                );
                e.target.value = '';
                if (files.length === 0) return;
                let okCount = 0;
                let lastTitle = '';
                let lastSub = '';
                for (const file of files) {
                  const imported = await offlineMedia.importMangaChapterCbz(file);
                  if (imported) {
                    okCount += 1;
                    lastTitle = imported.title;
                    lastSub = imported.subtitle || 'CBZ chapter';
                  }
                }
                if (okCount === 1) {
                  showSnackBar(`Imported "${lastTitle}" (${lastSub}) for offline reading`);
                } else if (okCount > 1) {
                  showSnackBar(`Imported ${okCount} CBZ chapters for offline reading`);
                } else {
                  showSnackBar('Could not read those .cbz archives — check that they contain JPG/PNG/WebP pages');
                }
              }}
            />
          </label>
          <label
            title="Import an entire folder of .cbz chapter archives"
            style={{
              minHeight: 40,
              padding: '6px 12px',
              borderRadius: 8,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.border}`,
              display: 'inline-flex',
              alignItems: 'center',
              gap: 5,
              fontFamily: Fonts.body,
              fontSize: 12,
              fontWeight: 700,
              color: KatanaColors.textMuted,
              cursor: 'pointer',
            }}
          >
            <Icon name="create_new_folder" size={15} color={KatanaColors.textMuted} />
            <span>Import Folder</span>
            <input
              type="file"
              multiple
              {...({ webkitdirectory: '', directory: '' } as Record<string, string>)}
              style={{ display: 'none' }}
              onChange={async (e) => {
                const files = Array.from(e.target.files ?? []).filter((f) =>
                  f.name.toLowerCase().endsWith('.cbz'),
                );
                e.target.value = '';
                if (files.length === 0) {
                  showSnackBar('No .cbz files found in that folder');
                  return;
                }
                let okCount = 0;
                for (const file of files) {
                  const imported = await offlineMedia.importMangaChapterCbz(file);
                  if (imported) okCount += 1;
                }
                showSnackBar(
                  okCount > 0
                    ? `Imported ${okCount} of ${files.length} CBZ chapters from folder`
                    : 'Could not import .cbz files from that folder',
                );
              }}
            />
          </label>
          {items.length > 0 && (
            <>
              {readDownloadIds.length > 0 && (
                <button
                  type="button"
                  className="bare-button"
                  onClick={() => onDeleteMany(readDownloadIds)}
                  style={{
                    minHeight: 40,
                    padding: '6px 12px',
                    borderRadius: 8,
                    background: withAlpha(KatanaColors.accent, 0.14),
                    border: `1px solid ${withAlpha(KatanaColors.accent, 0.4)}`,
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 5,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: 700,
                    color: KatanaColors.accentSoft,
                  }}
                >
                  <Icon name="cleaning_services" size={15} color={KatanaColors.accentSoft} />
                  <span>Delete read ({readDownloadIds.length})</span>
                </button>
              )}
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  setDlSelectMode((v) => !v);
                  setSelectedIds(new Set());
                }}
                style={{
                  minHeight: 40,
                  padding: '6px 11px',
                  borderRadius: 8,
                  background: dlSelectMode ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                  border: `1px solid ${dlSelectMode ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 5,
                  fontFamily: Fonts.body,
                  fontSize: 12,
                  fontWeight: 700,
                  color: dlSelectMode ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                }}
              >
                <Icon name="checklist" size={16} color={dlSelectMode ? KatanaColors.accentSoft : KatanaColors.textMuted} />
                <span>{dlSelectMode ? 'Done' : 'Select'}</span>
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={onClearAll}
                style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '6px 10px' }}
              >
                <Icon name="delete_sweep" variant="outlined" size={18} color={KatanaColors.textLight} />
                <span style={KatanaType.small}>Clear All</span>
              </button>
            </>
          )}
        </div>
      </div>
      <div style={{ height: 14 }} />
      <KatanaCard padding={12} radius={10} style={{ marginBottom: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
          {(() => {
            const netSupported = supportsNetworkConnectionApi();
            return (
              <>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <Icon name="wifi" size={18} color={wifiOnly ? KatanaColors.green : KatanaColors.textMuted} />
                    <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 600 }}>
                      Wi-Fi only — {wifiOnly ? 'On' : 'Off'}
                    </span>
                  </div>
                  {!netSupported && (
                    <span style={{ ...KatanaType.small, fontSize: 11, color: KatanaColors.textLight }}>
                      Safari / iOS hides cellular status. Pick your default rule for unverified connections below:
                    </span>
                  )}
                </div>
                <button
                  type="button"
                  role="switch"
                  aria-checked={wifiOnly}
                  aria-label={`Download over Wi-Fi only: ${wifiOnly ? 'On' : 'Off'}`}
                  className="bare-button"
                  onClick={onToggleWifiOnly}
                  style={{
                    width: 48,
                    height: 28,
                    borderRadius: 99,
                    padding: 3,
                    cursor: 'pointer',
                    background: wifiOnly ? KatanaColors.green : KatanaColors.switchOff,
                    border: `1px solid ${wifiOnly ? KatanaColors.green : KatanaColors.borderStrong}`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: wifiOnly ? 'flex-end' : 'flex-start',
                    transition: 'background 160ms ease',
                  }}
                >
                  <span
                    style={{
                      width: 20,
                      height: 20,
                      borderRadius: 99,
                      background: '#FFFFFF',
                      boxShadow: '0 1px 3px rgba(0,0,0,0.35)',
                    }}
                  />
                </button>
              </>
            );
          })()}
        </div>
        {wifiOnly && (
          <div
            style={{
              marginTop: 10,
              paddingTop: 10,
              borderTop: `1px solid ${KatanaColors.border}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: 8,
            }}
          >
            <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted }}>
              iOS / unverified connection rule:
            </span>
            <div style={{ display: 'inline-flex', gap: 6, flexWrap: 'wrap' }}>
              {([
                { id: 'allow' as const, label: 'Assume Wi-Fi (Allow)' },
                { id: 'ask' as const, label: 'Ask First' },
                { id: 'block' as const, label: 'Block (Cellular Safe)' },
              ]).map((opt) => {
                const active = unknownWifiPolicy === opt.id;
                return (
                  <button
                    key={opt.id}
                    type="button"
                    className="bare-button"
                    aria-pressed={active}
                    onClick={() => onChangeUnknownWifiPolicy(opt.id)}
                    style={{
                      minHeight: 36,
                      padding: '4px 10px',
                      borderRadius: 99,
                      background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                      border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                      fontFamily: Fonts.body,
                      fontSize: 11.5,
                      fontWeight: active ? 700 : 500,
                      color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                    }}
                  >
                    {opt.label}
                  </button>
                );
              })}
            </div>
          </div>
        )}
        <div
          style={{
            marginTop: 10,
            paddingTop: 10,
            borderTop: `1px solid ${KatanaColors.border}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            flexWrap: 'wrap',
            gap: 8,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
            <Icon name="downloading" size={18} color={autoDownloadNext > 0 ? KatanaColors.link : KatanaColors.textMuted} />
            <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 600 }}>
              Auto-download next unread
            </span>
            <span style={{ ...KatanaType.small, fontSize: 12, color: KatanaColors.textLight }}>
              (~{estimateMangaBatchMegabytes(1, false, items).perChapterMb} MB/ch est.)
            </span>
          </div>
          <div style={{ display: 'inline-flex', gap: 5, flexWrap: 'wrap' }}>
            {[0, 1, 3, 5].map((n) => {
              const active = autoDownloadNext === n;
              const est = n > 0 ? estimateMangaBatchMegabytes(n, false, items).label : '';
              return (
                <button
                  key={n}
                  type="button"
                  className="bare-button"
                  aria-pressed={active}
                  title={n === 0 ? 'Disable auto-download' : `Auto-download next ${n} unread (${est} est.)`}
                  onClick={() => onChangeAutoDownloadNext(n)}
                  style={{
                    minHeight: 44,
                    padding: '4px 10px',
                    borderRadius: 8,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {n === 0 ? 'Off' : `${n} ch (${est})`}
                </button>
              );
            })}
          </div>
        </div>
        {autoDownloadNext > 0 && allCategories.length > 0 && (
          <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 6 }}>
            <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted }}>
              Categories ({autoDownloadCategories.length === 0 ? 'All followed' : `${autoDownloadCategories.length} selected`}):
            </span>
            {allCategories.map((cat) => {
              const active = autoDownloadCategories.includes(cat);
              return (
                <button
                  key={cat}
                  type="button"
                  className="bare-button"
                  aria-pressed={active}
                  onClick={() => onToggleAutoDownloadCategory(cat)}
                  style={{
                    minHeight: 44,
                    padding: '6px 12px',
                    borderRadius: 99,
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {cat}
                </button>
              );
            })}
          </div>
        )}
        {batchProgress && (
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: `1px solid ${KatanaColors.border}` }}>
            <div style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.textMuted, marginBottom: 8 }}>
              Pages are cached progressively with Service Worker handoff (1 chapter at a time per source to prevent IP bans; parallel across different sources).
            </div>
            {downloadQueue.length > 0 && (
              <div style={{ marginBottom: 10, display: 'flex', flexDirection: 'column', gap: 4 }}>
                <div style={{ ...KatanaType.small, fontSize: 12, fontWeight: 700, color: KatanaColors.textMuted }}>
                  Up Next ({downloadQueue.length} · {estimateMangaBatchMegabytes(downloadQueue.length, false, items).label} est.) — reorder or remove
                </div>
                {downloadQueue.slice(0, 6).map((q, idx) => (
                  <div
                    key={`${q.manga.slug}-${q.chapter.id}`}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 6,
                      padding: '4px 8px',
                      borderRadius: 7,
                      background: KatanaColors.surfaceAlt,
                      border: `1px solid ${KatanaColors.border}`,
                    }}
                  >
                    <span className="ellipsis" style={{ flex: 1, minWidth: 0, ...KatanaType.small, color: KatanaColors.text }}>
                      {q.manga.title} · {chapterDisplayTitle(q.chapter)}
                    </span>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Move ${chapterDisplayTitle(q.chapter)} up`}
                      disabled={idx === 0}
                      onClick={() => onMoveQueueItem(idx, -1)}
                      style={{ width: 44, height: 44, display: 'grid', placeItems: 'center', opacity: idx === 0 ? 0.35 : 1 }}
                    >
                      <Icon name="arrow_upward" size={16} color={KatanaColors.textMuted} />
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Move ${chapterDisplayTitle(q.chapter)} down`}
                      disabled={idx === downloadQueue.length - 1}
                      onClick={() => onMoveQueueItem(idx, 1)}
                      style={{ width: 44, height: 44, display: 'grid', placeItems: 'center', opacity: idx === downloadQueue.length - 1 ? 0.35 : 1 }}
                    >
                      <Icon name="arrow_downward" size={16} color={KatanaColors.textMuted} />
                    </button>
                    <button
                      type="button"
                      className="bare-button"
                      aria-label={`Remove ${chapterDisplayTitle(q.chapter)} from queue`}
                      onClick={() => onRemoveQueueItem(idx)}
                      style={{ width: 44, height: 44, display: 'grid', placeItems: 'center' }}
                    >
                      <Icon name="close" size={16} color={KatanaColors.crimson} />
                    </button>
                  </div>
                ))}
              </div>
            )}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 6 }}>
              <span className="ellipsis" style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                Queue: {batchProgress.currentTitle || 'Downloading…'} ({batchProgress.done}/{batchProgress.total})
              </span>
              <button
                type="button"
                className="bare-button"
                onClick={onCancelQueue}
                style={{
                  minHeight: 44,
                  padding: '0 12px',
                  borderRadius: 8,
                  background: withAlpha(KatanaColors.crimson, 0.14),
                  border: `1px solid ${withAlpha(KatanaColors.crimson, 0.4)}`,
                  fontFamily: Fonts.body,
                  fontSize: 12,
                  fontWeight: 700,
                  color: KatanaColors.crimson,
                }}
              >
                Cancel Queue
              </button>
            </div>
            <div style={{ height: 5, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden' }}>
              <div
                style={{
                  width: `${Math.round((batchProgress.done / Math.max(1, batchProgress.total)) * 100)}%`,
                  height: '100%',
                  background: KatanaColors.link,
                  borderRadius: 99,
                  transition: 'width 180ms ease',
                }}
              />
            </div>
          </div>
        )}
        {failedDownloads.length > 0 && (
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: `1px solid ${KatanaColors.border}`, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
              <span style={{ ...KatanaType.small, fontWeight: 700, color: KatanaColors.crimson }}>
                Failed downloads ({failedDownloads.length})
              </span>
              <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <button
                  type="button"
                  className="bare-button"
                  onClick={onRetryFailed}
                  style={{
                    minHeight: 40,
                    padding: '0 12px',
                    borderRadius: 8,
                    background: KatanaColors.accent,
                    color: KatanaColors.accentInk,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: 700,
                  }}
                >
                  Retry all
                </button>
                <button
                  type="button"
                  className="bare-button"
                  onClick={onClearFailed}
                  style={{
                    minHeight: 40,
                    padding: '0 10px',
                    borderRadius: 8,
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${KatanaColors.border}`,
                    color: KatanaColors.textMuted,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: 600,
                  }}
                >
                  Dismiss
                </button>
              </div>
            </div>
            {failedDownloads.slice(0, 6).map((f, idx) => (
              <div
                key={`fail-${f.manga.slug}-${f.chapter.id}`}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '4px 10px',
                  borderRadius: 8,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${withAlpha(KatanaColors.crimson, 0.35)}`,
                }}
              >
                <span className="ellipsis" style={{ flex: 1, minWidth: 0, ...KatanaType.small, color: KatanaColors.text }}>
                  {f.manga.title} · {chapterDisplayTitle(f.chapter)}
                </span>
                <button
                  type="button"
                  className="bare-button"
                  aria-label={`Retry ${chapterDisplayTitle(f.chapter)}`}
                  onClick={() => onRetrySingleFailed(idx)}
                  style={{
                    minHeight: 40,
                    padding: '0 12px',
                    borderRadius: 8,
                    background: withAlpha(KatanaColors.accent, 0.16),
                    color: KatanaColors.accentSoft,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: 700,
                  }}
                >
                  Retry
                </button>
              </div>
            ))}
          </div>
        )}
      </KatanaCard>
      {items.length === 0 ? (
        <KatanaEmptyState
          icon="download_done"
          title="No offline chapters yet"
          subtitle="Download chapters from any manga detail page or reader to read without a connection."
          actionLabel="Browse Manga"
          actionIcon="home"
          onAction={onBrowse}
        />
      ) : (
        <>
          <KatanaCard padding={12} style={{ marginBottom: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 10 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="storage" size={18} color={KatanaColors.accent} />
                <span style={KatanaType.small}>
                  Offline storage used: <strong style={{ color: KatanaColors.text }}>{storage}</strong>
                  {quotaInfo
                    ? ` of ${quotaInfo.quota >= 1e9 ? `${(quotaInfo.quota / 1e9).toFixed(1)} GB` : `${Math.max(1, Math.round(quotaInfo.quota / 1e6))} MB`} device budget`
                    : ''}
                </span>
              </div>
              <div style={{ display: 'inline-flex', gap: 6, flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className="bare-button"
                  disabled={verifyingCache}
                  onClick={() => void handleVerifyCache()}
                  title="Verify every downloaded chapter page in browser Cache Storage"
                  style={{
                    padding: '5px 10px',
                    borderRadius: 7,
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${KatanaColors.borderStrong}`,
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 4,
                    fontFamily: Fonts.body,
                    fontSize: 12,
                    fontWeight: 700,
                    color: KatanaColors.teal,
                  }}
                >
                  <Icon name="fact_check" size={14} color={KatanaColors.teal} />
                  <span>{verifyingCache ? 'Verifying…' : 'Verify Cache'}</span>
                </button>
                {(
                  [
                    ['recent', 'Recent'],
                    ['title', 'A–Z'],
                    ['chapters', 'Most ch'],
                  ] as const
                ).map(([id, label]) => (
                  <button
                    key={id}
                    type="button"
                    className="bare-button"
                    onClick={() => setSortBy(id)}
                    style={{
                      padding: '5px 10px',
                      borderRadius: 7,
                      background: sortBy === id ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                      border: `1px solid ${sortBy === id ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                      fontFamily: Fonts.body,
                      fontSize: 12,
                      fontWeight: sortBy === id ? 700 : 500,
                      color: sortBy === id ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                    }}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
            {quotaInfo && (
              <div style={{ marginTop: 8 }}>
                <div style={{ height: 5, borderRadius: 99, background: KatanaColors.surfaceAlt, overflow: 'hidden' }}>
                  <div
                    style={{
                      width: `${Math.min(100, Math.max(2, Math.round((quotaInfo.usage / Math.max(1, quotaInfo.quota)) * 100)))}%`,
                      height: '100%',
                      background: KatanaColors.accent,
                      borderRadius: 99,
                    }}
                  />
                </div>
              </div>
            )}
            <div style={{ ...KatanaType.small, fontSize: 11, marginTop: 6 }}>
              Pending downloads save automatically and resume next time you open Manga Celestia. Clearing browser site data removes cached pages unless you export a portable <strong>.cbz</strong> archive.
            </div>
            {evictedItems.length > 0 && (
              <div
                style={{
                  marginTop: 10,
                  padding: '10px 12px',
                  borderRadius: 8,
                  background: withAlpha(KatanaColors.accent, 0.14),
                  border: `1px solid ${withAlpha(KatanaColors.accent, 0.5)}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: 8,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: '1 1 240px' }}>
                  <Icon name="warning_amber" size={18} color={KatanaColors.accent} />
                  <span style={{ ...KatanaType.small, fontSize: 12, color: KatanaColors.text, fontWeight: 600 }}>
                    {evictedItems.length} downloaded {evictedItems.length === 1 ? 'chapter has' : 'chapters have'} missing
                    Cache Storage pages evicted by the browser and won&apos;t load completely offline until repaired.
                  </span>
                </div>
                <KatanaButton
                  label={repairingAll ? 'Repairing…' : `Repair All (${evictedItems.length})`}
                  icon="build"
                  size="sm"
                  onClick={() => void handleRepairAllEvicted()}
                />
              </div>
            )}
            {persisted === false && (
              <div
                style={{
                  marginTop: 10,
                  padding: '8px 10px',
                  borderRadius: 8,
                  background: withAlpha(KatanaColors.accent, 0.08),
                  border: `1px solid ${withAlpha(KatanaColors.accent, 0.3)}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: 8,
                }}
              >
                <span style={{ ...KatanaType.small, fontSize: 11.5, color: KatanaColors.text, flex: '1 1 220px' }}>
                  Your browser may remove offline chapters when the device runs low on space.
                </span>
                <KatanaButton label="Keep them" icon="shield" size="sm" filled={false} color={KatanaColors.accentSoft} onClick={keepOffline} />
              </div>
            )}
          </KatanaCard>

          {dlSelectMode && (
            <KatanaCard padding={10} radius={10} style={{ marginBottom: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                <span style={{ ...KatanaType.small, color: KatanaColors.text, fontWeight: 700 }}>
                  {selectedIds.size} selected
                </span>
                <div style={{ display: 'inline-flex', gap: 8 }}>
                  <KatanaButton
                    label="Select all"
                    size="sm"
                    filled={false}
                    color={KatanaColors.textMuted}
                    onClick={() => setSelectedIds(new Set(items.map((i) => i.id)))}
                  />
                  <KatanaButton
                    label={`Delete (${selectedIds.size})`}
                    icon="delete_outline"
                    size="sm"
                    filled={false}
                    color={KatanaColors.crimson}
                    onClick={() => {
                      if (selectedIds.size === 0) return;
                      onDeleteMany([...selectedIds]);
                      setSelectedIds(new Set());
                      setDlSelectMode(false);
                    }}
                  />
                </div>
              </div>
            </KatanaCard>
          )}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {grouped.map((chapters) => {
              const head = chapters[0];
              return (
                <KatanaCard key={head.mediaId} padding={0} style={{ overflow: 'hidden' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: 12, borderBottom: `1px solid ${KatanaColors.border}` }}>
                    <div
                      onClick={() => onOpenSeries(head.mediaId)}
                      role="link"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          onOpenSeries(head.mediaId);
                        }
                      }}
                      style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0, textAlign: 'left', cursor: 'pointer' }}
                    >
                      <div style={{ position: 'relative', width: 46, height: 66, borderRadius: 6, overflow: 'hidden', flexShrink: 0, background: KatanaColors.surfaceAlt }}>
                        <KatanaCoverImage url={head.coverUrl} title={head.title} iconSize={18} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div className="ellipsis" style={KatanaType.title}>{head.title}</div>
                        <div style={KatanaType.small}>
                          {chapters.length} {chapters.length === 1 ? 'chapter' : 'chapters'} offline
                          {seriesBytes(chapters) ? ` · ${seriesBytes(chapters)}` : ''}
                        </div>
                      </div>
                    </div>
                    <KatanaButton label="Resume" icon="play_arrow" size="sm" onClick={() => onOpen(head)} />
                  </div>
                  {chapters.map((ch, idx) => {
                    const checked = selectedIds.has(ch.id);
                    const missingPages = ch.cacheMissingPages ?? 0;
                    const totalPages = ch.pageUrls.length;
                    const cachedPages = ch.verifiedCachedPages ?? Math.max(0, totalPages - missingPages);
                    const needsRepair = missingPages > 0;
                    return (
                      <div
                        key={ch.id}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 10,
                          padding: '10px 12px',
                          borderTop: idx > 0 ? `1px solid ${KatanaColors.border}` : undefined,
                          background: checked
                            ? withAlpha(KatanaColors.accent, 0.08)
                            : needsRepair
                              ? withAlpha(KatanaColors.accent, 0.06)
                              : 'transparent',
                        }}
                      >
                        {dlSelectMode && (
                          <button
                            type="button"
                            className="bare-button"
                            aria-label={`Select ${ch.subtitle || ch.title}`}
                            onClick={() => toggleSelect(ch.id)}
                            style={{ width: 34, height: 34, display: 'grid', placeItems: 'center', flexShrink: 0 }}
                          >
                            <Icon name={checked ? 'check_box' : 'check_box_outline_blank'} size={20} color={checked ? KatanaColors.accent : KatanaColors.textLight} />
                          </button>
                        )}
                        <button
                          type="button"
                          className="bare-button"
                          onClick={() => (dlSelectMode ? toggleSelect(ch.id) : onOpen(ch))}
                          style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 10, textAlign: 'left' }}
                        >
                          <Icon
                            name={needsRepair ? 'warning_amber' : 'menu_book'}
                            size={18}
                            color={needsRepair ? KatanaColors.accent : KatanaColors.accentSoft}
                          />
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ ...KatanaType.title, fontSize: 13.5 }}>{ch.subtitle || `Chapter ${ch.chapterId ?? ''}`}</div>
                            <div style={{ ...KatanaType.small, display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                              <span>{formattedSize(ch)}</span>
                              {needsRepair ? (
                                <span style={{ color: KatanaColors.accentSoft, fontWeight: 700 }}>
                                  · Needs Repair ({cachedPages}/{totalPages} pages cached)
                                </span>
                              ) : totalPages > 0 ? (
                                <span style={{ color: KatanaColors.green, fontWeight: 600 }}>
                                  · Offline verified ({cachedPages} {cachedPages === 1 ? 'page' : 'pages'})
                                </span>
                              ) : null}
                            </div>
                          </div>
                        </button>
                        {!dlSelectMode && (
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                            {needsRepair && (
                              <button
                                type="button"
                                className="bare-button"
                                title="Re-download evicted pages into Cache Storage"
                                aria-label={`Repair offline cache for ${ch.subtitle || ch.title}`}
                                onClick={async () => {
                                  showSnackBar(`Repairing ${ch.subtitle || ch.title}…`);
                                  await offlineMedia.repairMangaChapter(ch.id, proxyKatanaImageUrl);
                                  const res = await offlineMedia.verifyMangaChapterCache(ch.id);
                                  showSnackBar(
                                    res.isComplete
                                      ? `Repaired ${ch.subtitle || ch.title} (${res.cachedPages}/${res.totalPages} pages cached)`
                                      : `Could not restore all pages (${res.cachedPages}/${res.totalPages} cached) — check connection`,
                                  );
                                }}
                                style={{
                                  minHeight: 44,
                                  padding: '0 11px',
                                  borderRadius: 7,
                                  background: withAlpha(KatanaColors.accent, 0.18),
                                  border: `1px solid ${withAlpha(KatanaColors.accent, 0.55)}`,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: 4,
                                  fontFamily: Fonts.body,
                                  fontSize: 11.5,
                                  fontWeight: 800,
                                  color: KatanaColors.accentSoft,
                                }}
                              >
                                <Icon name="build" size={14} color={KatanaColors.accentSoft} />
                                <span>Repair</span>
                              </button>
                            )}
                            <button
                              type="button"
                              className="bare-button"
                              title="Export portable .cbz comic archive"
                              aria-label={`Export ${ch.subtitle || ch.title} as CBZ`}
                              onClick={async () => {
                                const res = await offlineMedia.exportMangaChapterCbz(ch.id);
                                if (!res) {
                                  showSnackBar('Cached pages not available to export yet');
                                  return;
                                }
                                const url = URL.createObjectURL(res.blob);
                                const a = document.createElement('a');
                                a.href = url;
                                a.download = res.filename;
                                a.click();
                                URL.revokeObjectURL(url);
                                showSnackBar(`Exported ${res.filename}`);
                              }}
                              style={{
                                minHeight: 44,
                                padding: '0 11px',
                                borderRadius: 7,
                                background: KatanaColors.surfaceAlt,
                                border: `1px solid ${KatanaColors.border}`,
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: 4,
                                fontFamily: Fonts.body,
                                fontSize: 11.5,
                                fontWeight: 700,
                                color: KatanaColors.link,
                              }}
                            >
                              <Icon name="folder_zip" size={14} color={KatanaColors.link} />
                              <span>CBZ</span>
                            </button>
                            <button
                              type="button"
                              className="bare-button"
                              aria-label={`Delete ${ch.subtitle || ch.title}`}
                              onClick={() => onDelete(ch.id)}
                              style={{ width: 44, height: 44, display: 'grid', placeItems: 'center' }}
                            >
                              <Icon name="delete_outline" size={18} color={KatanaColors.textLight} />
                            </button>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </KatanaCard>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
