import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Icon } from '../../shared/widgets/Icon';
import { chapterDisplayTitle, proxyKatanaImageUrl, type KatanaChapter } from './katanaService';
import { KatanaColors, KatanaType } from './katanaTokens';
import { resolveReaderImageUrl } from './ReaderPageImage';
import {
  READER_BACKGROUNDS,
  READER_PROFILES,
  READING_MODE_META,
  READING_MODE_ORDER,
  SERVER_OPTIONS,
  type FitMode,
  type OrientationLock,
  type PageBookmark,
  type PageTransition,
  type ReaderBackground,
  type ReaderSettings,
  type ReadingMode,
  type ScrollHideSensitivity,
  type TapZoneLayout,
} from './readerSettings';

function useDialogFocusTrap(containerRef: React.RefObject<HTMLDivElement | null>, onClose: () => void) {
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const prevFocused = document.activeElement as HTMLElement | null;
    const focusables = () =>
      Array.from(
        el.querySelectorAll<HTMLElement>(
          'button:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ),
      );
    focusables()[0]?.focus();

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        closeRef.current();
        return;
      }
      if (e.key !== 'Tab') return;
      const list = focusables();
      if (list.length === 0) return;
      const first = list[0];
      const last = list[list.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };
    window.addEventListener('keydown', onKeyDown, true);
    return () => {
      window.removeEventListener('keydown', onKeyDown, true);
      prevFocused?.focus?.();
    };
  }, [containerRef]);
}

function SheetHeader({ title, subtitle, onClose }: { title: string; subtitle?: string; onClose: () => void }) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 12,
        padding: '14px 16px 12px',
        borderBottom: `1px solid ${KatanaColors.border}`,
      }}
    >
      <div style={{ minWidth: 0 }}>
        <div style={{ ...KatanaType.title, fontSize: 16 }}>{title}</div>
        {subtitle && <div style={{ ...KatanaType.small, marginTop: 2 }}>{subtitle}</div>}
      </div>
      <button
        type="button"
        className="bare-button player-focusable"
        aria-label={`Close ${title}`}
        onClick={onClose}
        style={{
          width: 44,
          height: 44,
          borderRadius: 99,
          display: 'grid',
          placeItems: 'center',
          background: KatanaColors.surfaceAlt,
          border: `1px solid ${KatanaColors.border}`,
        }}
      >
        <Icon name="close" size={20} color={KatanaColors.textMuted} />
      </button>
    </div>
  );
}

function ToggleRow({
  label,
  hint,
  checked,
  onChange,
}: {
  label: string;
  hint?: string;
  checked: boolean;
  onChange: (next: boolean) => void;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      className="bare-button player-focusable"
      onClick={() => onChange(!checked)}
      style={{
        width: '100%',
        minHeight: 48,
        padding: '10px 12px',
        borderRadius: 12,
        background: KatanaColors.surfaceAlt,
        border: `1px solid ${checked ? KatanaColors.borderStrong : KatanaColors.border}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: 12,
      }}
    >
      <div style={{ textAlign: 'left', minWidth: 0 }}>
        <div style={{ fontSize: 13.5, fontWeight: 600, color: KatanaColors.text }}>{label}</div>
        {hint && <div style={{ ...KatanaType.small, marginTop: 2 }}>{hint}</div>}
      </div>
      <span
        aria-hidden
        style={{
          width: 42,
          height: 24,
          borderRadius: 99,
          padding: 2,
          flexShrink: 0,
          background: checked ? KatanaColors.accent : KatanaColors.switchOff,
          display: 'flex',
          alignItems: 'center',
          justifyContent: checked ? 'flex-end' : 'flex-start',
          transition: 'background 150ms ease',
        }}
      >
        <span
          style={{
            width: 20,
            height: 20,
            borderRadius: 99,
            background: '#FFFFFF',
            boxShadow: '0 1px 3px rgba(0,0,0,0.4)',
          }}
        />
      </span>
    </button>
  );
}

function SectionLabel({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        fontSize: 11.5,
        fontWeight: 700,
        letterSpacing: 0.7,
        textTransform: 'uppercase',
        color: KatanaColors.textLight,
        marginBottom: 8,
        marginTop: 14,
      }}
    >
      {children}
    </div>
  );
}

export function ChapterDrawerSheet({
  chapters,
  currentChapterId,
  currentPageIdx,
  pages,
  readChapterIds,
  pageBookmarks,
  mangaTitle,
  onSelectChapter,
  onSelectPage,
  onToggleChapterRead,
  onSelectBookmark,
  onRemoveBookmark,
  onClose,
}: {
  chapters: KatanaChapter[];
  currentChapterId: string;
  currentPageIdx: number;
  pages: string[];
  readChapterIds: ReadonlySet<string>;
  pageBookmarks: PageBookmark[];
  mangaTitle: string;
  onSelectChapter: (chapterId: string) => void;
  onSelectPage: (pageIdx: number) => void;
  onToggleChapterRead: (chapterId: string) => void;
  onSelectBookmark: (bm: PageBookmark) => void;
  onRemoveBookmark: (bm: PageBookmark) => void;
  onClose: () => void;
}) {
  const [drawerTab, setDrawerTab] = useState<'chapters' | 'pages' | 'bookmarks'>('chapters');
  const [query, setQuery] = useState('');
  const [ascending, setAscending] = useState(false);
  const sheetRef = useRef<HTMLDivElement>(null);
  const activeRef = useRef<HTMLButtonElement>(null);
  useDialogFocusTrap(sheetRef, onClose);

  const filtered = useMemo(() => {
    const base = ascending ? [...chapters].reverse() : chapters;
    const q = query.trim().toLowerCase();
    if (!q) return base;
    return base.filter((c) => chapterDisplayTitle(c).toLowerCase().includes(q) || c.num.toLowerCase().includes(q));
  }, [chapters, ascending, query]);

  useEffect(() => {
    if (drawerTab === 'chapters') {
      activeRef.current?.scrollIntoView({ block: 'center', behavior: 'auto' });
    }
  }, [drawerTab]);

  const readCount = useMemo(
    () => chapters.filter((c) => readChapterIds.has(c.id)).length,
    [chapters, readChapterIds],
  );

  return (
    <div
      className="drawer-barrier"
      role="dialog"
      aria-modal="true"
      aria-label="Chapters and bookmarks"
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 120,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
      }}
    >
      <div
        ref={sheetRef}
        className="drawer-slide"
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 560,
          maxHeight: '82dvh',
          background: KatanaColors.surface,
          borderTopLeftRadius: 20,
          borderTopRightRadius: 20,
          border: `1px solid ${KatanaColors.border}`,
          borderBottom: 'none',
          display: 'flex',
          flexDirection: 'column',
          paddingBottom: 'max(12px, env(safe-area-inset-bottom))',
          boxShadow: '0 -16px 48px rgba(0,0,0,0.65)',
        }}
      >
        <SheetHeader
          title="Chapters & Bookmarks"
          subtitle={`${mangaTitle} • ${readCount}/${chapters.length} finished`}
          onClose={onClose}
        />

        <div
          role="tablist"
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 6,
            padding: '8px 16px',
            borderBottom: `1px solid ${KatanaColors.border}`,
          }}
        >
          {(
            [
              ['chapters', `Chapters (${chapters.length})`, 'format_list_numbered'],
              ['pages', `Pages (${pages.length})`, 'grid_view'],
              ['bookmarks', `Saved (${pageBookmarks.length})`, 'bookmark'],
            ] as const
          ).map(([id, label, icon]) => {
            const active = drawerTab === id;
            return (
              <button
                key={id}
                type="button"
                role="tab"
                aria-selected={active}
                className="bare-button player-focusable"
                onClick={() => setDrawerTab(id)}
                style={{
                  minHeight: 40,
                  borderRadius: 10,
                  background: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
                  color: active ? '#FFFFFF' : KatanaColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: 600,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 6,
                }}
              >
                <Icon name={icon} size={17} color={active ? '#FFFFFF' : KatanaColors.textMuted} />
                {label}
              </button>
            );
          })}
        </div>

        {drawerTab === 'chapters' ? (
          <>
            <div style={{ display: 'flex', gap: 8, padding: '10px 16px', borderBottom: `1px solid ${KatanaColors.border}` }}>
              <div
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  borderRadius: 10,
                  padding: '0 12px',
                  minHeight: 42,
                }}
              >
                <Icon name="search" size={18} color={KatanaColors.textLight} />
                <input
                  type="search"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Filter chapters..."
                  aria-label="Filter chapters"
                  style={{
                    flex: 1,
                    background: 'transparent',
                    border: 'none',
                    outline: 'none',
                    color: KatanaColors.text,
                    fontSize: 13.5,
                  }}
                />
              </div>
              <button
                type="button"
                className="bare-button player-focusable"
                aria-label={ascending ? 'Sort newest first' : 'Sort oldest first'}
                onClick={() => setAscending((a) => !a)}
                style={{
                  minHeight: 42,
                  padding: '0 12px',
                  borderRadius: 10,
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  color: KatanaColors.accentSoft,
                  fontSize: 12.5,
                  fontWeight: 600,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 6,
                }}
              >
                <Icon name="swap_vert" size={18} color={KatanaColors.accentSoft} />
                {ascending ? 'Oldest' : 'Newest'}
              </button>
            </div>

            <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', padding: '8px 12px' }}>
              {filtered.length === 0 ? (
                <div style={{ padding: 28, textAlign: 'center', ...KatanaType.small }}>No matching chapters.</div>
              ) : (
                filtered.map((ch) => {
                  const isCurrent = ch.id === currentChapterId;
                  const isRead = readChapterIds.has(ch.id);
                  return (
                    <div
                      key={ch.id}
                      style={{
                        width: '100%',
                        minHeight: 48,
                        marginBottom: 4,
                        borderRadius: 12,
                        background: isCurrent ? KatanaColors.surfaceGlow : 'transparent',
                        border: `1px solid ${isCurrent ? KatanaColors.accent : 'transparent'}`,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 6,
                        padding: '0 6px 0 0',
                      }}
                    >
                      <button
                        ref={isCurrent ? activeRef : undefined}
                        type="button"
                        className="bare-button player-focusable"
                        onClick={() => {
                          onSelectChapter(ch.id);
                          onClose();
                        }}
                        style={{
                          flex: 1,
                          minWidth: 0,
                          minHeight: 46,
                          padding: '10px 12px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          gap: 8,
                          textAlign: 'left',
                        }}
                      >
                        <div
                          className="ellipsis"
                          style={{
                            fontSize: 13.5,
                            fontWeight: isCurrent ? 700 : 500,
                            color: isCurrent
                              ? KatanaColors.accentSoft
                              : isRead
                                ? KatanaColors.textLight
                                : KatanaColors.text,
                          }}
                        >
                          {chapterDisplayTitle(ch)}
                        </div>
                        {isCurrent && (
                          <span
                            style={{
                              fontSize: 11,
                              fontWeight: 700,
                              padding: '2px 8px',
                              borderRadius: 99,
                              background: KatanaColors.accent,
                              color: '#FFFFFF',
                              flexShrink: 0,
                            }}
                          >
                            Reading
                          </span>
                        )}
                      </button>
                      <button
                        type="button"
                        className="bare-button player-focusable"
                        aria-label={isRead ? `Mark ${chapterDisplayTitle(ch)} unread` : `Mark ${chapterDisplayTitle(ch)} read`}
                        onClick={() => onToggleChapterRead(ch.id)}
                        style={{
                          width: 40,
                          height: 40,
                          borderRadius: 99,
                          display: 'grid',
                          placeItems: 'center',
                          flexShrink: 0,
                        }}
                      >
                        <Icon
                          name={isRead ? 'check_circle' : 'radio_button_unchecked'}
                          size={18}
                          color={isRead ? KatanaColors.accentSoft : KatanaColors.textLight}
                        />
                      </button>
                    </div>
                  );
                })
              )}
            </div>
          </>
        ) : drawerTab === 'pages' ? (
          <div
            className="no-scrollbar"
            style={{
              flex: 1,
              overflowY: 'auto',
              padding: '12px 14px',
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 10,
              alignContent: 'start',
            }}
          >
            {pages.length === 0 ? (
              <div style={{ gridColumn: '1 / -1', padding: 28, textAlign: 'center', ...KatanaType.small }}>
                No pages loaded yet.
              </div>
            ) : (
              pages.map((url, idx) => {
                const isActive = idx === currentPageIdx;
                return (
                  <button
                    key={`${url}:${idx}`}
                    type="button"
                    className="bare-button player-focusable"
                    onClick={() => {
                      onSelectPage(idx);
                      onClose();
                    }}
                    style={{
                      position: 'relative',
                      borderRadius: 10,
                      overflow: 'hidden',
                      aspectRatio: '0.7 / 1',
                      background: KatanaColors.surfaceAlt,
                      border: `2px solid ${isActive ? KatanaColors.accent : KatanaColors.border}`,
                    }}
                  >
                    <img
                      src={resolveReaderImageUrl(url, 0)}
                      alt={`Thumbnail page ${idx + 1}`}
                      loading="lazy"
                      style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                    />
                    <span
                      style={{
                        position: 'absolute',
                        bottom: 4,
                        right: 4,
                        padding: '2px 7px',
                        borderRadius: 99,
                        background: isActive ? KatanaColors.accent : 'rgba(9, 6, 12, 0.82)',
                        color: '#FFFFFF',
                        fontSize: 11,
                        fontWeight: 700,
                      }}
                    >
                      {idx + 1}
                    </span>
                  </button>
                );
              })
            )}
          </div>
        ) : (
          <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', padding: '10px 12px' }}>
            {pageBookmarks.length === 0 ? (
              <div style={{ padding: 32, textAlign: 'center', ...KatanaType.small }}>
                No page bookmarks yet. Tap the bookmark icon in the bottom bar or long-press any page to save it.
              </div>
            ) : (
              pageBookmarks.map((bm) => (
                <div
                  key={`${bm.chapterId}:${bm.pageIdx}`}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 8,
                    marginBottom: 6,
                    padding: '6px 8px 6px 12px',
                    borderRadius: 12,
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${KatanaColors.border}`,
                  }}
                >
                  <button
                    type="button"
                    className="bare-button player-focusable"
                    onClick={() => {
                      onSelectBookmark(bm);
                      onClose();
                    }}
                    style={{ flex: 1, minWidth: 0, minHeight: 40, textAlign: 'left' }}
                  >
                    <div className="ellipsis" style={{ fontSize: 13.5, fontWeight: 600, color: KatanaColors.text }}>
                      {bm.chapterTitle}
                    </div>
                    <div style={{ ...KatanaType.small, color: KatanaColors.accentSoft }}>Page {bm.pageIdx + 1}</div>
                  </button>
                  <button
                    type="button"
                    className="bare-button player-focusable"
                    aria-label={`Remove bookmark for ${bm.chapterTitle} page ${bm.pageIdx + 1}`}
                    onClick={() => onRemoveBookmark(bm)}
                    style={{
                      width: 40,
                      height: 40,
                      borderRadius: 10,
                      display: 'grid',
                      placeItems: 'center',
                    }}
                  >
                    <Icon name="delete_outline" size={19} color={KatanaColors.textLight} />
                  </button>
                </div>
              ))
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export function ReaderSettingsSheet({
  settings,
  hasSeriesOverride,
  server,
  onUpdateSettings,
  onToggleSeriesOverride,
  onChangeServer,
  onClose,
}: {
  settings: ReaderSettings;
  hasSeriesOverride: boolean;
  server: string;
  onUpdateSettings: (patch: Partial<ReaderSettings>) => void;
  onToggleSeriesOverride: (enabled: boolean) => void;
  onChangeServer: (server: string) => void;
  onClose: () => void;
}) {
  const [tab, setTab] = useState<'reading' | 'display' | 'controls'>('reading');
  const sheetRef = useRef<HTMLDivElement>(null);
  useDialogFocusTrap(sheetRef, onClose);

  const fitOptions: Array<{ id: FitMode; label: string }> = [
    { id: 'smart-fit', label: 'Smart Fit' },
    { id: 'fit-width', label: 'Fit Width' },
    { id: 'fit-height', label: 'Fit Height' },
    { id: 'fit-screen', label: 'Fit Screen' },
    { id: 'stretch', label: 'Stretch' },
    { id: 'original', label: 'Original' },
  ];

  const tapOptions: Array<{ id: TapZoneLayout; label: string; desc: string }> = [
    { id: 'standard', label: 'Standard', desc: 'Left / Center HUD / Right' },
    { id: 'l-shaped', label: 'L-Shaped', desc: 'Top back, center HUD, L advance' },
    { id: 'kindle', label: 'Kindle', desc: 'Top HUD, 75% advance' },
    { id: 'edge', label: 'Edge', desc: 'Narrow 22% side zones' },
    { id: 'disabled', label: 'Off', desc: 'Tap anywhere toggles HUD' },
  ];

  const transitionOptions: Array<{ id: PageTransition; label: string }> = [
    { id: 'fade', label: 'Fade' },
    { id: 'slide', label: 'Slide' },
    { id: 'none', label: 'Instant' },
  ];

  const sensitivityOptions: Array<{ id: ScrollHideSensitivity; label: string }> = [
    { id: 'low', label: 'Low' },
    { id: 'medium', label: 'Medium' },
    { id: 'high', label: 'High' },
  ];

  const orientationOptions: Array<{ id: OrientationLock; label: string }> = [
    { id: 'auto', label: 'Auto' },
    { id: 'portrait', label: 'Portrait' },
    { id: 'landscape', label: 'Landscape' },
  ];

  const zoomOptions = [1.5, 2, 2.5, 3];
  const autoScrollSpeeds = [0.5, 1, 1.5, 2, 3];

  const bgChoices: Array<{ id: ReaderBackground; label: string; swatch: string }> = [
    { id: 'auto', label: 'Auto', swatch: 'linear-gradient(135deg, #000000 50%, #F7F7F7 50%)' },
    ...(Object.keys(READER_BACKGROUNDS) as Array<Exclude<ReaderBackground, 'auto'>>).map((key) => ({
      id: key,
      label: READER_BACKGROUNDS[key].label.split(' ')[0],
      swatch: READER_BACKGROUNDS[key].swatch,
    })),
  ];

  const isDoubleCapable =
    settings.readingMode === 'double-rtl' ||
    settings.readingMode === 'double-ltr' ||
    settings.readingMode === 'auto-rtl' ||
    settings.readingMode === 'auto-ltr';
  const isSingleCapable =
    settings.readingMode === 'paged-rtl' ||
    settings.readingMode === 'paged-ltr' ||
    settings.readingMode === 'auto-rtl' ||
    settings.readingMode === 'auto-ltr';
  const isWebtoon = settings.readingMode === 'webtoon';

  return (
    <div
      className="drawer-barrier"
      role="dialog"
      aria-modal="true"
      aria-label="Reader settings"
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 120,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
      }}
    >
      <div
        ref={sheetRef}
        className="drawer-slide"
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 560,
          maxHeight: '84dvh',
          background: KatanaColors.surface,
          borderTopLeftRadius: 20,
          borderTopRightRadius: 20,
          border: `1px solid ${KatanaColors.border}`,
          borderBottom: 'none',
          display: 'flex',
          flexDirection: 'column',
          paddingBottom: 'max(14px, env(safe-area-inset-bottom))',
          boxShadow: '0 -16px 48px rgba(0,0,0,0.65)',
        }}
      >
        <SheetHeader title="Reader Settings" onClose={onClose} />

        <div
          role="tablist"
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 6,
            padding: '10px 16px',
            borderBottom: `1px solid ${KatanaColors.border}`,
          }}
        >
          {(
            [
              ['reading', 'Reading', 'menu_book'],
              ['display', 'Display', 'tune'],
              ['controls', 'Controls', 'touch_app'],
            ] as const
          ).map(([id, label, icon]) => {
            const active = tab === id;
            return (
              <button
                key={id}
                type="button"
                role="tab"
                aria-selected={active}
                className="bare-button player-focusable"
                onClick={() => setTab(id)}
                style={{
                  minHeight: 42,
                  borderRadius: 10,
                  background: active ? KatanaColors.accent : KatanaColors.surfaceAlt,
                  color: active ? '#FFFFFF' : KatanaColors.textMuted,
                  fontSize: 13,
                  fontWeight: 600,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 6,
                }}
              >
                <Icon name={icon} size={17} color={active ? '#FFFFFF' : KatanaColors.textMuted} />
                {label}
              </button>
            );
          })}
        </div>

        <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', padding: '4px 16px 16px' }}>
          {tab === 'reading' && (
            <>
              <SectionLabel>Quick Profiles</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
                {READER_PROFILES.map((preset) => (
                  <button
                    key={preset.id}
                    type="button"
                    className="bare-button player-focusable"
                    onClick={() => onUpdateSettings(preset.patch)}
                    style={{
                      minHeight: 50,
                      padding: '8px 11px',
                      borderRadius: 12,
                      background: KatanaColors.surfaceAlt,
                      border: `1px solid ${KatanaColors.border}`,
                      textAlign: 'left',
                    }}
                  >
                    <div style={{ fontSize: 12.5, fontWeight: 700, color: KatanaColors.accentSoft }}>{preset.label}</div>
                    <div style={{ ...KatanaType.small, fontSize: 10.5, marginTop: 2 }}>{preset.desc}</div>
                  </button>
                ))}
              </div>

              <SectionLabel>Reading Mode</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(136px, 1fr))', gap: 8 }}>
                {READING_MODE_ORDER.map((m: ReadingMode) => {
                  const meta = READING_MODE_META[m];
                  const active = settings.readingMode === m;
                  return (
                    <button
                      key={m}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ readingMode: m })}
                      style={{
                        minHeight: 46,
                        padding: '8px 11px',
                        borderRadius: 12,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 8,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 12.5,
                        fontWeight: 600,
                      }}
                    >
                      <Icon name={meta.icon} size={18} color={active ? KatanaColors.accentSoft : KatanaColors.textLight} />
                      <span>{meta.shortLabel}</span>
                    </button>
                  );
                })}
              </div>

              <SectionLabel>Image Scaling</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 8 }}>
                {fitOptions.map((opt) => {
                  const active = settings.fitMode === opt.id;
                  return (
                    <button
                      key={opt.id}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ fitMode: opt.id })}
                      style={{
                        minHeight: 44,
                        padding: '8px 10px',
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 12.5,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {opt.label}
                    </button>
                  );
                })}
              </div>

              {isDoubleCapable && (
                <>
                  <SectionLabel>Spread Center Gutter ({settings.spreadGutter}px)</SectionLabel>
                  <input
                    type="range"
                    className="manga-range"
                    min={0}
                    max={32}
                    step={2}
                    value={settings.spreadGutter}
                    aria-label="Spread center gutter"
                    onChange={(e) => onUpdateSettings({ spreadGutter: Number(e.target.value) })}
                    style={{ width: '100%' }}
                  />
                </>
              )}

              {isWebtoon && (
                <>
                  <SectionLabel>Auto-Scroll Speed ({settings.autoScrollSpeed}×)</SectionLabel>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 6 }}>
                    {autoScrollSpeeds.map((sp) => {
                      const active = settings.autoScrollSpeed === sp;
                      return (
                        <button
                          key={sp}
                          type="button"
                          className="bare-button player-focusable"
                          onClick={() => onUpdateSettings({ autoScrollSpeed: sp })}
                          style={{
                            minHeight: 40,
                            borderRadius: 10,
                            background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                            border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                            color: active ? KatanaColors.accentSoft : KatanaColors.text,
                            fontSize: 12.5,
                            fontWeight: 600,
                            textAlign: 'center',
                          }}
                        >
                          {sp}×
                        </button>
                      );
                    })}
                  </div>
                </>
              )}

              <SectionLabel>Wide Pages &amp; Chapter Flow</SectionLabel>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <ToggleRow
                  label="Custom settings for this series"
                  hint="Save mode, fit, brightness, tint, width, crop, gap & tap zones for this title"
                  checked={hasSeriesOverride}
                  onChange={onToggleSeriesOverride}
                />
                {isSingleCapable && (
                  <>
                    <ToggleRow
                      label="Split wide double-page spreads"
                      hint="Reads wide landscape spreads as two half-pages in reading order"
                      checked={settings.splitWidePages}
                      onChange={(v) => onUpdateSettings({ splitWidePages: v })}
                    />
                    <ToggleRow
                      label="Rotate wide pages to fit"
                      hint="Rotates landscape spreads 90° on vertical phones"
                      checked={settings.rotateWidePages}
                      onChange={(v) => onUpdateSettings({ rotateWidePages: v })}
                    />
                  </>
                )}
                {isDoubleCapable && (
                  <>
                    <ToggleRow
                      label="Offset double spreads (cover solo)"
                      hint="Display page 1 alone so spreads pair correctly"
                      checked={settings.coverOffset}
                      onChange={(v) => onUpdateSettings({ coverOffset: v })}
                    />
                    <ToggleRow
                      label="Auto-solo wide spreads"
                      hint="Never pair landscape double-page art with another page"
                      checked={settings.autoSpreadWide}
                      onChange={(v) => onUpdateSettings({ autoSpreadWide: v })}
                    />
                  </>
                )}
                {isWebtoon && (
                  <>
                    <ToggleRow
                      label="Seamless next chapter"
                      hint="Auto-append the next chapter as you reach the bottom"
                      checked={settings.seamlessNextChapter}
                      onChange={(v) => onUpdateSettings({ seamlessNextChapter: v })}
                    />
                    {settings.seamlessNextChapter && (
                      <ToggleRow
                        label="Show chapter transition divider"
                        hint="Subtle hairline label between chained chapters"
                        checked={settings.alwaysShowChapterDivider}
                        onChange={(v) => onUpdateSettings({ alwaysShowChapterDivider: v })}
                      />
                    )}
                  </>
                )}
                <ToggleRow
                  label="Skip finished chapters"
                  hint="Jump past chapters you already completed"
                  checked={settings.skipReadChapters}
                  onChange={(v) => onUpdateSettings({ skipReadChapters: v })}
                />
                <ToggleRow
                  label="Data-saver preloading"
                  hint="Preload only the next page and skip background chapter prefetch"
                  checked={settings.dataSaver}
                  onChange={(v) => onUpdateSettings({ dataSaver: v })}
                />
                <ToggleRow
                  label="Preload ahead on Wi-Fi only"
                  hint="Limits aggressive multi-page preloading on cellular connections"
                  checked={settings.preloadWifiOnly}
                  onChange={(v) => onUpdateSettings({ preloadWifiOnly: v })}
                />
                {!settings.dataSaver && (
                  <div style={{ padding: '4px 2px' }}>
                    <SectionLabel>Pages to Preload Ahead ({settings.preloadCount})</SectionLabel>
                    <input
                      type="range"
                      className="manga-range"
                      min={1}
                      max={6}
                      step={1}
                      value={settings.preloadCount}
                      aria-label="Pages to preload ahead"
                      onChange={(e) => onUpdateSettings({ preloadCount: Number(e.target.value) })}
                      style={{ width: '100%' }}
                    />
                  </div>
                )}
              </div>

              <SectionLabel>Image Source Server</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {SERVER_OPTIONS.map((srv) => {
                  const active = server === srv.value;
                  return (
                    <button
                      key={srv.label}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onChangeServer(srv.value)}
                      style={{
                        minHeight: 44,
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 13,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {srv.label}
                    </button>
                  );
                })}
              </div>
            </>
          )}

          {tab === 'display' && (
            <>
              <SectionLabel>Background</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {bgChoices.map((item) => {
                  const active = settings.background === item.id;
                  return (
                    <button
                      key={item.id}
                      type="button"
                      className="bare-button player-focusable"
                      aria-label={item.label}
                      onClick={() => onUpdateSettings({ background: item.id })}
                      style={{
                        minHeight: 50,
                        borderRadius: 12,
                        padding: '6px 8px',
                        background: KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        gap: 8,
                      }}
                    >
                      <span
                        style={{
                          width: 20,
                          height: 20,
                          borderRadius: 99,
                          background: item.swatch,
                          border: '1px solid rgba(255,255,255,0.28)',
                          flexShrink: 0,
                        }}
                      />
                      <span style={{ fontSize: 12, fontWeight: 600, color: active ? KatanaColors.accentSoft : KatanaColors.textMuted }}>
                        {item.label}
                      </span>
                    </button>
                  );
                })}
              </div>

              <SectionLabel>Brightness Dimmer ({Math.round(settings.brightness * 100)}%)</SectionLabel>
              <input
                type="range"
                className="manga-range"
                min={15}
                max={100}
                step={5}
                value={Math.round(settings.brightness * 100)}
                aria-label="Reader brightness"
                onChange={(e) => onUpdateSettings({ brightness: Number(e.target.value) / 100 })}
                style={{ width: '100%' }}
              />

              <SectionLabel>Warm Night Tint ({Math.round((settings.warmTint / 0.4) * 100)}%)</SectionLabel>
              <input
                type="range"
                className="manga-range"
                min={0}
                max={40}
                step={5}
                value={Math.round(settings.warmTint * 100)}
                aria-label="Warm night tint"
                onChange={(e) => onUpdateSettings({ warmTint: Number(e.target.value) / 100 })}
                style={{ width: '100%' }}
              />

              <SectionLabel>Contrast ({Math.round(settings.contrast * 100)}%)</SectionLabel>
              <input
                type="range"
                className="manga-range"
                min={75}
                max={135}
                step={5}
                value={Math.round(settings.contrast * 100)}
                aria-label="Page contrast"
                onChange={(e) => onUpdateSettings({ contrast: Number(e.target.value) / 100 })}
                style={{ width: '100%' }}
              />

              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 14, marginBottom: 8 }}>
                <span style={{ fontSize: 11.5, fontWeight: 700, letterSpacing: 0.7, textTransform: 'uppercase', color: KatanaColors.textLight }}>
                  Reading Width ({settings.widthUnit === 'pct' ? `${settings.maxWidthPct}%` : settings.maxWidth === 0 ? 'Full Bleed' : `${settings.maxWidth}px`})
                </span>
                <div style={{ display: 'flex', gap: 4 }}>
                  {(['px', 'pct'] as const).map((unit) => (
                    <button
                      key={unit}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ widthUnit: unit })}
                      style={{
                        padding: '3px 10px',
                        borderRadius: 8,
                        background: settings.widthUnit === unit ? KatanaColors.accent : KatanaColors.surfaceAlt,
                        color: settings.widthUnit === unit ? '#FFFFFF' : KatanaColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: 700,
                      }}
                    >
                      {unit === 'px' ? 'px' : '%'}
                    </button>
                  ))}
                </div>
              </div>
              {settings.widthUnit === 'pct' ? (
                <input
                  type="range"
                  className="manga-range"
                  min={50}
                  max={100}
                  step={5}
                  value={settings.maxWidthPct}
                  aria-label="Max reading width percentage"
                  onChange={(e) => onUpdateSettings({ maxWidthPct: Number(e.target.value) })}
                  style={{ width: '100%' }}
                />
              ) : (
                <input
                  type="range"
                  className="manga-range"
                  min={480}
                  max={1400}
                  step={40}
                  value={settings.maxWidth === 0 ? 1400 : settings.maxWidth}
                  aria-label="Max reading width pixels"
                  onChange={(e) => {
                    const v = Number(e.target.value);
                    onUpdateSettings({ maxWidth: v >= 1400 ? 0 : v });
                  }}
                  style={{ width: '100%' }}
                />
              )}

              <SectionLabel>Page Gap ({settings.pageGap}px)</SectionLabel>
              <input
                type="range"
                className="manga-range"
                min={0}
                max={24}
                step={4}
                value={settings.pageGap}
                aria-label="Page gap"
                onChange={(e) => onUpdateSettings({ pageGap: Number(e.target.value) })}
                style={{ width: '100%' }}
              />

              <SectionLabel>Orientation Lock</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {orientationOptions.map((opt) => {
                  const active = settings.orientationLock === opt.id;
                  return (
                    <button
                      key={opt.id}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ orientationLock: opt.id })}
                      style={{
                        minHeight: 42,
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 12.5,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {opt.label}
                    </button>
                  );
                })}
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 14 }}>
                <ToggleRow
                  label="Grayscale mode"
                  hint="Monochrome filter for crisp black-and-white manga reading"
                  checked={settings.grayscale}
                  onChange={(v) => onUpdateSettings({ grayscale: v })}
                />
                <ToggleRow
                  label="Invert page colors"
                  hint="Flips white paper to dark ink for late-night reading"
                  checked={settings.invertColors}
                  onChange={(v) => onUpdateSettings({ invertColors: v })}
                />
                <ToggleRow
                  label="E-ink flash on page turn"
                  hint="Brief 90ms refresh flash to clear ghosting on e-ink displays"
                  checked={settings.einkFlash}
                  onChange={(v) => onUpdateSettings({ einkFlash: v })}
                />
                <ToggleRow
                  label="Crop scan borders"
                  hint="Detects and trims uniform white or black scan margins"
                  checked={settings.cropBorders}
                  onChange={(v) => onUpdateSettings({ cropBorders: v })}
                />
                <ToggleRow
                  label="Keep screen awake"
                  hint="Prevents screen dimming while reading (re-acquires on resume)"
                  checked={settings.keepAwake}
                  onChange={(v) => onUpdateSettings({ keepAwake: v })}
                />
              </div>
            </>
          )}

          {tab === 'controls' && (
            <>
              <SectionLabel>Tap Zones (Paged &amp; Spread)</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
                {tapOptions.map((opt) => {
                  const active = settings.tapZoneLayout === opt.id;
                  return (
                    <button
                      key={opt.id}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ tapZoneLayout: opt.id })}
                      style={{
                        minHeight: 54,
                        padding: '8px 12px',
                        borderRadius: 12,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        textAlign: 'left',
                      }}
                    >
                      <div style={{ fontSize: 13, fontWeight: 600, color: active ? KatanaColors.accentSoft : KatanaColors.text }}>
                        {opt.label}
                      </div>
                      <div style={{ ...KatanaType.small, fontSize: 11, marginTop: 2 }}>{opt.desc}</div>
                    </button>
                  );
                })}
              </div>

              <SectionLabel>Double-Tap Zoom Level</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
                {zoomOptions.map((z) => {
                  const active = settings.doubleTapZoom === z;
                  return (
                    <button
                      key={z}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ doubleTapZoom: z })}
                      style={{
                        minHeight: 42,
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 13,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {z.toFixed(1)}×
                    </button>
                  );
                })}
              </div>
              <ToggleRow
                label="Keep zoom across pages"
                hint="Preserve your magnification level when turning pages (accessibility & small text)"
                checked={settings.keepZoomAcrossPages}
                onChange={(v) => onUpdateSettings({ keepZoomAcrossPages: v })}
              />

              <SectionLabel>Page Transition</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {transitionOptions.map((opt) => {
                  const active = settings.pageTransition === opt.id;
                  return (
                    <button
                      key={opt.id}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ pageTransition: opt.id })}
                      style={{
                        minHeight: 42,
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 13,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {opt.label}
                    </button>
                  );
                })}
              </div>

              <SectionLabel>Scroll-Hide Sensitivity</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {sensitivityOptions.map((opt) => {
                  const active = settings.scrollHideSensitivity === opt.id;
                  return (
                    <button
                      key={opt.id}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ scrollHideSensitivity: opt.id })}
                      style={{
                        minHeight: 42,
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 13,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {opt.label}
                    </button>
                  );
                })}
              </div>

              <SectionLabel>Long-Strip Vertical Seekbar</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {(
                  [
                    ['right', 'Right Edge'],
                    ['left', 'Left Edge'],
                    ['off', 'Off'],
                  ] as const
                ).map(([side, label]) => {
                  const active = settings.verticalSeekbar === side;
                  return (
                    <button
                      key={side}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() => onUpdateSettings({ verticalSeekbar: side })}
                      style={{
                        minHeight: 42,
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 12.5,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {label}
                    </button>
                  );
                })}
              </div>

              <SectionLabel>HUD Auto-Hide Delay</SectionLabel>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6 }}>
                {(
                  [
                    [0, 'Off'],
                    [3000, '3s'],
                    [5000, '5s'],
                    [10000, '10s'],
                  ] as const
                ).map(([ms, label]) => {
                  const active = (settings.autoHideChrome ? settings.autoHideDelayMs : 0) === ms;
                  return (
                    <button
                      key={label}
                      type="button"
                      className="bare-button player-focusable"
                      onClick={() =>
                        onUpdateSettings(ms === 0 ? { autoHideChrome: false, autoHideDelayMs: 0 } : { autoHideChrome: true, autoHideDelayMs: ms })
                      }
                      style={{
                        minHeight: 40,
                        borderRadius: 10,
                        background: active ? KatanaColors.surfaceGlow : KatanaColors.surfaceAlt,
                        border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                        color: active ? KatanaColors.accentSoft : KatanaColors.text,
                        fontSize: 12.5,
                        fontWeight: 600,
                        textAlign: 'center',
                      }}
                    >
                      {label}
                    </button>
                  );
                })}
              </div>

              <SectionLabel>HUD &amp; Ergonomics</SectionLabel>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <ToggleRow
                  label="Tap-to-scroll in Webtoon"
                  hint="Tap lower screen to scroll down, upper screen to scroll up, center for HUD"
                  checked={settings.webtoonTapScroll}
                  onChange={(v) => onUpdateSettings({ webtoonTapScroll: v })}
                />
                <ToggleRow
                  label="Confirm swipe at chapter end"
                  hint="Prevents accidental chapter jumps when swiping past the last page"
                  checked={settings.confirmChapterSwipe}
                  onChange={(v) => onUpdateSettings({ confirmChapterSwipe: v })}
                />
                <ToggleRow
                  label="Invert tap zones"
                  hint="Swaps left and right page-turn sides"
                  checked={settings.invertTapZones}
                  onChange={(v) => onUpdateSettings({ invertTapZones: v })}
                />
                <ToggleRow
                  label="Show tap-zone guide overlay"
                  hint="Display subtle tap-zone borders in paged/spread modes"
                  checked={settings.showTapZonesOverlay}
                  onChange={(v) => onUpdateSettings({ showTapZonesOverlay: v })}
                />
                <ToggleRow
                  label="Persistent page indicator"
                  hint="Show subtle page pill even when bars are hidden"
                  checked={settings.showPageIndicator}
                  onChange={(v) => onUpdateSettings({ showPageIndicator: v })}
                />
                <ToggleRow
                  label="Show reading mode banner"
                  hint="Brief toast when opening chapters or switching modes"
                  checked={settings.showModeToast}
                  onChange={(v) => onUpdateSettings({ showModeToast: v })}
                />
                <ToggleRow
                  label="Hide bars when scrolling down"
                  hint="Auto-hides top & bottom HUD while scrolling webtoons"
                  checked={settings.hideChromeOnScroll}
                  onChange={(v) => onUpdateSettings({ hideChromeOnScroll: v })}
                />
                <ToggleRow
                  label="Reveal bars when scrolling up"
                  hint="Bring top & bottom HUD back on upward scroll"
                  checked={settings.showChromeOnScrollUp}
                  onChange={(v) => onUpdateSettings({ showChromeOnScrollUp: v })}
                />
                <ToggleRow
                  label="Auto-hide HUD after idle"
                  hint="Fades controls out after 4 seconds of reading"
                  checked={settings.autoHideChrome}
                  onChange={(v) => onUpdateSettings({ autoHideChrome: v })}
                />
                <ToggleRow
                  label="Subtle haptic feedback"
                  hint="Gentle tap vibration on page turns and bookmarks (mobile)"
                  checked={settings.haptics}
                  onChange={(v) => onUpdateSettings({ haptics: v })}
                />
              </div>

              <SectionLabel>Keyboard Shortcuts</SectionLabel>
              <div
                style={{
                  background: KatanaColors.surfaceAlt,
                  border: `1px solid ${KatanaColors.border}`,
                  borderRadius: 12,
                  padding: '10px 12px',
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '6px 12px',
                  fontSize: 12,
                  color: KatanaColors.textMuted,
                }}
              >
                <div><strong style={{ color: KatanaColors.text }}>← / →</strong> Turn page</div>
                <div><strong style={{ color: KatanaColors.text }}>Space</strong> Next page</div>
                <div><strong style={{ color: KatanaColors.text }}>[ / ]</strong> Prev / Next ch.</div>
                <div><strong style={{ color: KatanaColors.text }}>M / G</strong> Mode / Jump page</div>
                <div><strong style={{ color: KatanaColors.text }}>B / P</strong> Bookmark / Auto-scroll</div>
                <div><strong style={{ color: KatanaColors.text }}>C / S</strong> Chapters / Settings</div>
                <div><strong style={{ color: KatanaColors.text }}>F / H</strong> Fullscreen / HUD</div>
                <div><strong style={{ color: KatanaColors.text }}>+ / - / 0</strong> Zoom controls</div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export function PageActionSheet({
  pageNumber,
  mangaTitle,
  chapterLabel,
  imageUrl,
  isBookmarked,
  onToggleBookmark,
  onReloadPage,
  onOpenSettings,
  onClose,
}: {
  pageNumber: number;
  mangaTitle: string;
  chapterLabel: string;
  imageUrl: string;
  isBookmarked: boolean;
  onToggleBookmark: () => void;
  onReloadPage: () => void;
  onOpenSettings: () => void;
  onClose: () => void;
}) {
  const [statusMsg, setStatusMsg] = useState<string | null>(null);
  const sheetRef = useRef<HTMLDivElement>(null);
  useDialogFocusTrap(sheetRef, onClose);

  const isLocalOrInline = imageUrl.startsWith('data:') || imageUrl.startsWith('blob:');
  const isShareableUrl = !isLocalOrInline && Boolean(imageUrl);

  const handleSave = async () => {
    const baseName = `${mangaTitle.replace(/[^a-z0-9]+/gi, '_')}_${chapterLabel.replace(/[^a-z0-9]+/gi, '_')}_p${pageNumber}`;
    const isSameOriginOrLocal = isLocalOrInline || imageUrl.startsWith('/');
    const fetchUrl = isSameOriginOrLocal ? imageUrl : proxyKatanaImageUrl(imageUrl);
    const canFetch = isSameOriginOrLocal || fetchUrl.includes('proxyMangaKatana');
    if (!canFetch) {
      window.open(fetchUrl, '_blank', 'noopener,noreferrer');
      onClose();
      return;
    }
    try {
      const res = await fetch(fetchUrl);
      if (!res.ok) throw new Error('fetch failed');
      const blob = await res.blob();
      const mime = blob.type.toLowerCase();
      const ext = mime.includes('jpeg') || mime.includes('jpg')
        ? 'jpg'
        : mime.includes('webp')
          ? 'webp'
          : mime.includes('svg')
            ? 'svg'
            : mime.includes('gif')
              ? 'gif'
              : 'png';
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${baseName}.${ext}`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.setTimeout(() => URL.revokeObjectURL(url), 1500);
      setStatusMsg('Saved image');
      window.setTimeout(onClose, 500);
    } catch {
      if (isShareableUrl) {
        window.open(fetchUrl, '_blank', 'noopener,noreferrer');
      }
      onClose();
    }
  };

  const handleShare = async () => {
    if (!isShareableUrl) return;
    try {
      if (navigator.share) {
        await navigator.share({ title: `${mangaTitle} — ${chapterLabel} (Page ${pageNumber})`, url: imageUrl });
        onClose();
        return;
      }
      await navigator.clipboard?.writeText(imageUrl);
      setStatusMsg('Link copied to share');
      window.setTimeout(onClose, 500);
    } catch {
      onClose();
    }
  };

  const actions = [
    {
      icon: isBookmarked ? 'bookmark' : 'bookmark_border',
      label: isBookmarked ? 'Remove Page Bookmark' : `Bookmark Page ${pageNumber}`,
      onClick: () => {
        onToggleBookmark();
        onClose();
      },
    },
    {
      icon: 'download',
      label: 'Save Page Image',
      onClick: handleSave,
    },
    ...(isShareableUrl
      ? [
          {
            icon: 'share',
            label: 'Share Page',
            onClick: handleShare,
          },
        ]
      : []),
    {
      icon: 'refresh',
      label: `Reload Page ${pageNumber}`,
      onClick: () => {
        onReloadPage();
        onClose();
      },
    },
    ...(isShareableUrl
      ? [
          {
            icon: 'content_copy',
            label: 'Copy Image Link',
            onClick: async () => {
              try {
                await navigator.clipboard?.writeText(imageUrl);
                setStatusMsg('Copied image link');
                window.setTimeout(onClose, 450);
              } catch {
                onClose();
              }
            },
          },
          {
            icon: 'open_in_new',
            label: 'Open Image in New Tab',
            onClick: () => {
              window.open(imageUrl, '_blank', 'noopener,noreferrer');
              onClose();
            },
          },
        ]
      : []),
    {
      icon: 'dns',
      label: 'Switch Source Server',
      onClick: () => {
        onClose();
        onOpenSettings();
      },
    },
  ];

  return (
    <div
      className="drawer-barrier"
      role="dialog"
      aria-modal="true"
      aria-label={`Page ${pageNumber} actions`}
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 130,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
      }}
    >
      <div
        ref={sheetRef}
        className="drawer-slide"
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 440,
          background: KatanaColors.surface,
          borderTopLeftRadius: 20,
          borderTopRightRadius: 20,
          border: `1px solid ${KatanaColors.border}`,
          borderBottom: 'none',
          paddingBottom: 'max(14px, env(safe-area-inset-bottom))',
        }}
      >
        <SheetHeader
          title={`Page ${pageNumber}`}
          subtitle={statusMsg ?? `${chapterLabel} • Page actions`}
          onClose={onClose}
        />
        <div style={{ padding: '10px 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
          {actions.map((a) => (
            <button
              key={a.label}
              type="button"
              className="bare-button player-focusable"
              onClick={a.onClick}
              style={{
                minHeight: 46,
                padding: '0 14px',
                borderRadius: 12,
                background: KatanaColors.surfaceAlt,
                border: `1px solid ${KatanaColors.border}`,
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                color: KatanaColors.text,
                fontSize: 14,
                fontWeight: 600,
              }}
            >
              <Icon name={a.icon} size={20} color={KatanaColors.accentSoft} />
              <span>{a.label}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

export function QuickDisplayPopover({
  settings,
  onUpdateSettings,
  onOpenFullSettings,
  onClose,
}: {
  settings: ReaderSettings;
  onUpdateSettings: (patch: Partial<ReaderSettings>) => void;
  onOpenFullSettings: () => void;
  onClose: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useDialogFocusTrap(ref, onClose);

  const bgChoices: Array<{ id: ReaderBackground; label: string; swatch: string }> = [
    { id: 'auto', label: 'Smart', swatch: 'linear-gradient(135deg, #000000 50%, #F7F7F7 50%)' },
    ...(Object.keys(READER_BACKGROUNDS) as Array<Exclude<ReaderBackground, 'auto'>>).map((key) => ({
      id: key,
      label: READER_BACKGROUNDS[key].label.split(' ')[0],
      swatch: READER_BACKGROUNDS[key].swatch,
    })),
  ];

  return (
    <div
      className="drawer-barrier"
      role="dialog"
      aria-modal="true"
      aria-label="Quick display controls"
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 125,
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
      }}
    >
      <div
        ref={ref}
        className="drawer-slide"
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 460,
          background: KatanaColors.surface,
          borderTopLeftRadius: 20,
          borderTopRightRadius: 20,
          border: `1px solid ${KatanaColors.borderStrong}`,
          borderBottom: 'none',
          padding: '14px 16px max(16px, env(safe-area-inset-bottom))',
          boxShadow: '0 -12px 36px rgba(0,0,0,0.65)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ ...KatanaType.title, fontSize: 15 }}>Quick Display</div>
          <button
            type="button"
            className="bare-button player-focusable"
            onClick={() => {
              onClose();
              onOpenFullSettings();
            }}
            style={{
              padding: '6px 12px',
              borderRadius: 99,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.border}`,
              color: KatanaColors.accentSoft,
              fontSize: 12,
              fontWeight: 600,
            }}
          >
            All Settings
          </button>
        </div>

        <SectionLabel>Brightness ({Math.round(settings.brightness * 100)}%)</SectionLabel>
        <input
          type="range"
          className="manga-range"
          min={15}
          max={100}
          step={5}
          value={Math.round(settings.brightness * 100)}
          aria-label="Quick brightness"
          onChange={(e) => onUpdateSettings({ brightness: Number(e.target.value) / 100 })}
          style={{ width: '100%' }}
        />

        <SectionLabel>Warm Night Tint ({Math.round((settings.warmTint / 0.4) * 100)}%)</SectionLabel>
        <input
          type="range"
          className="manga-range"
          min={0}
          max={40}
          step={5}
          value={Math.round(settings.warmTint * 100)}
          aria-label="Quick warm tint"
          onChange={(e) => onUpdateSettings({ warmTint: Number(e.target.value) / 100 })}
          style={{ width: '100%' }}
        />

        <SectionLabel>Background</SectionLabel>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 6 }}>
          {bgChoices.map((item) => {
            const active = settings.background === item.id;
            return (
              <button
                key={item.id}
                type="button"
                className="bare-button player-focusable"
                aria-label={item.label}
                onClick={() => onUpdateSettings({ background: item.id })}
                style={{
                  minHeight: 46,
                  borderRadius: 10,
                  background: KatanaColors.surfaceAlt,
                  border: `1.5px solid ${active ? KatanaColors.accent : KatanaColors.border}`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 3,
                }}
              >
                <span
                  style={{
                    width: 18,
                    height: 18,
                    borderRadius: 99,
                    background: item.swatch,
                    border: '1px solid rgba(255,255,255,0.28)',
                  }}
                />
                <span style={{ fontSize: 10, color: active ? KatanaColors.accentSoft : KatanaColors.textMuted }}>
                  {item.label}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

export function PageJumpDialog({
  currentPage,
  totalPages,
  onJump,
  onClose,
}: {
  currentPage: number;
  totalPages: number;
  onJump: (pageNumber: number) => void;
  onClose: () => void;
}) {
  const [value, setValue] = useState(String(currentPage));
  const dialogRef = useRef<HTMLDivElement>(null);
  useDialogFocusTrap(dialogRef, onClose);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    const num = Number.parseInt(value, 10);
    if (Number.isFinite(num)) {
      onJump(Math.min(totalPages, Math.max(1, num)));
    }
    onClose();
  };

  return (
    <div
      className="drawer-barrier"
      role="dialog"
      aria-modal="true"
      aria-label="Jump to page"
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 130,
        display: 'grid',
        placeItems: 'center',
        padding: 16,
      }}
    >
      <div
        ref={dialogRef}
        className="drawer-slide"
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: 320,
          background: KatanaColors.surface,
          borderRadius: 18,
          border: `1px solid ${KatanaColors.borderStrong}`,
          padding: 18,
          boxShadow: '0 16px 48px rgba(0,0,0,0.65)',
        }}
      >
        <div style={{ ...KatanaType.title, fontSize: 16 }}>Jump to Page</div>
        <div style={{ ...KatanaType.small, marginTop: 4 }}>Enter a page number between 1 and {totalPages}</div>
        <form onSubmit={submit} style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
          <input
            type="number"
            inputMode="numeric"
            min={1}
            max={totalPages}
            value={value}
            onChange={(e) => setValue(e.target.value)}
            aria-label="Page number"
            style={{
              width: '100%',
              minHeight: 46,
              padding: '0 14px',
              borderRadius: 12,
              background: KatanaColors.surfaceAlt,
              border: `1px solid ${KatanaColors.borderStrong}`,
              color: KatanaColors.text,
              fontSize: 16,
              fontWeight: 600,
              textAlign: 'center',
              outline: 'none',
            }}
          />
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              type="button"
              className="bare-button player-focusable"
              onClick={onClose}
              style={{
                flex: 1,
                minHeight: 44,
                borderRadius: 10,
                background: KatanaColors.surfaceAlt,
                border: `1px solid ${KatanaColors.border}`,
                color: KatanaColors.textMuted,
                fontSize: 13.5,
                fontWeight: 600,
                textAlign: 'center',
              }}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="bare-button player-focusable"
              style={{
                flex: 1,
                minHeight: 44,
                borderRadius: 10,
                background: KatanaColors.accent,
                color: '#FFFFFF',
                fontSize: 13.5,
                fontWeight: 700,
                textAlign: 'center',
              }}
            >
              Go
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
