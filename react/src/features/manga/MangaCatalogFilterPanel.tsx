import { withAlpha } from '../../core/theme/colors';
import { Icon } from '../../shared/widgets/Icon';
import type { KatanaGenre } from './katanaService';
import { KatanaColors, KatanaFonts as Fonts, KatanaType } from './katanaTokens';

const FILTER_PRESETS_KEY = 'katana_filter_presets_v1';

export interface SavedFilterPreset {
  id: string;
  name: string;
  order: string;
  status: string;
  demo: string;
  minCh: string;
  gm: string;
  lang: string;
  author: string;
  inc: string[];
  exc: string[];
}

export function loadSavedFilterPresets(): SavedFilterPreset[] {
  try {
    const raw = localStorage.getItem(FILTER_PRESETS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (p): p is SavedFilterPreset =>
        Boolean(p && typeof p.id === 'string' && typeof p.name === 'string' && Array.isArray(p.inc) && Array.isArray(p.exc)),
    );
  } catch {
    return [];
  }
}

export function saveFilterPresets(presets: SavedFilterPreset[]): void {
  try {
    if (presets.length === 0) localStorage.removeItem(FILTER_PRESETS_KEY);
    else localStorage.setItem(FILTER_PRESETS_KEY, JSON.stringify(presets.slice(0, 12)));
  } catch {
    // ignore storage quota errors
  }
}

export const ORDER_OPTIONS = [
  { id: 'latest', label: 'Latest Updated' },
  { id: 'popular', label: 'Most Followed' },
  { id: 'rating', label: 'Top Rated' },
  { id: 'numc', label: 'Most Chapters' },
  { id: 'new', label: 'Newest Added' },
  { id: 'az', label: 'Title A–Z' },
] as const;

export const MIN_CHAPTER_OPTIONS = [
  { id: '1', label: 'Any length' },
  { id: '10', label: '10+ ch' },
  { id: '50', label: '50+ ch' },
  { id: '100', label: '100+ ch' },
] as const;

export const STATUS_FILTER_OPTIONS = [
  { id: 'all', label: 'Any status' },
  { id: 'ongoing', label: 'Ongoing' },
  { id: 'completed', label: 'Completed' },
] as const;

export const DEMOGRAPHIC_OPTIONS = [
  { id: 'all', label: 'All' },
  { id: 'shounen', label: 'Shounen' },
  { id: 'seinen', label: 'Seinen' },
  { id: 'shoujo', label: 'Shoujo' },
  { id: 'josei', label: 'Josei' },
] as const;

export function MangaCatalogFilterPanel({
  filterPresets,
  activeFilterCount,
  orderBy,
  statusFilter,
  demographicFilter,
  minChapters,
  genreMode,
  languageFilter,
  authorDraft,
  setAuthorDraft,
  presetNameDraft,
  setPresetNameDraft,
  includeGenres,
  excludeGenres,
  genres,
  onSavePreset,
  onApplyPreset,
  onDeletePreset,
  onUpdateUrl,
  onToggleIncludeGenre,
  onToggleExcludeGenre,
}: {
  filterPresets: SavedFilterPreset[];
  activeFilterCount: number;
  orderBy: string;
  statusFilter: string;
  demographicFilter: string;
  minChapters: string;
  genreMode: string;
  languageFilter: string;
  authorDraft: string;
  setAuthorDraft: (v: string) => void;
  presetNameDraft: string;
  setPresetNameDraft: (v: string) => void;
  includeGenres: string[];
  excludeGenres: string[];
  genres: KatanaGenre[];
  onSavePreset: () => void;
  onApplyPreset: (preset: SavedFilterPreset) => void;
  onDeletePreset: (id: string) => void;
  onUpdateUrl: (updates: Record<string, string | null>, opts?: { replace?: boolean }) => void;
  onToggleIncludeGenre: (slug: string) => void;
  onToggleExcludeGenre: (slug: string) => void;
}) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      {(filterPresets.length > 0 || activeFilterCount > 0 || orderBy !== 'latest') && (
        <div
          style={{
            padding: 10,
            borderRadius: 10,
            background: KatanaColors.background,
            border: `1px solid ${KatanaColors.border}`,
            display: 'flex',
            flexDirection: 'column',
            gap: 8,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
            <span style={{ ...KatanaType.small, fontWeight: 700, color: KatanaColors.text }}>Saved filter presets</span>
            {(activeFilterCount > 0 || orderBy !== 'latest') && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, flex: 1, minWidth: 200, maxWidth: 320 }}>
                <input
                  value={presetNameDraft}
                  onChange={(e) => setPresetNameDraft(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') onSavePreset();
                  }}
                  placeholder="Preset name (optional)…"
                  aria-label="Filter preset name"
                  style={{
                    flex: 1,
                    minWidth: 0,
                    height: 40,
                    padding: '0 10px',
                    borderRadius: 8,
                    background: KatanaColors.surface,
                    border: `1px solid ${KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
                    color: KatanaColors.text,
                    outline: 'none',
                  }}
                />
                <button
                  type="button"
                  className="bare-button"
                  onClick={onSavePreset}
                  style={{
                    minHeight: 40,
                    padding: '0 12px',
                    borderRadius: 8,
                    background: KatanaColors.accent,
                    color: KatanaColors.accentInk,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
                    fontWeight: 700,
                    whiteSpace: 'nowrap',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 4,
                  }}
                >
                  <Icon name="bookmark_add" size={15} color={KatanaColors.accentInk} />
                  <span>Save</span>
                </button>
              </div>
            )}
          </div>
          {filterPresets.length > 0 && (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {filterPresets.map((preset) => (
                <div
                  key={preset.id}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    borderRadius: 9,
                    overflow: 'hidden',
                    background: KatanaColors.surfaceAlt,
                    border: `1px solid ${KatanaColors.borderStrong}`,
                  }}
                >
                  <button
                    type="button"
                    className="bare-button"
                    onClick={() => onApplyPreset(preset)}
                    style={{
                      minHeight: 40,
                      padding: '0 12px',
                      fontFamily: Fonts.body,
                      fontSize: 12.5,
                      fontWeight: 600,
                      color: KatanaColors.text,
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 5,
                    }}
                  >
                    <Icon name="bookmarks" size={14} color={KatanaColors.accent} />
                    <span>{preset.name}</span>
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    aria-label={`Delete preset ${preset.name}`}
                    onClick={() => onDeletePreset(preset.id)}
                    style={{
                      width: 40,
                      height: 40,
                      display: 'grid',
                      placeItems: 'center',
                      borderLeft: `1px solid ${KatanaColors.border}`,
                    }}
                  >
                    <Icon name="close" size={14} color={KatanaColors.textMuted} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, alignItems: 'flex-start' }}>
        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Sort by</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {ORDER_OPTIONS.map((opt) => {
              const active = orderBy === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => onUpdateUrl({ order: opt.id === 'latest' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    minHeight: 40,
                    padding: '8px 12px',
                    borderRadius: 8,
                    display: 'inline-flex',
                    alignItems: 'center',
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
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

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Status</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {STATUS_FILTER_OPTIONS.map((opt) => {
              const active = statusFilter === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => onUpdateUrl({ status: opt.id === 'all' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    minHeight: 40,
                    padding: '8px 12px',
                    borderRadius: 8,
                    display: 'inline-flex',
                    alignItems: 'center',
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
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

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Demographic</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {DEMOGRAPHIC_OPTIONS.map((opt) => {
              const active = demographicFilter === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => onUpdateUrl({ demo: opt.id === 'all' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    minHeight: 40,
                    padding: '8px 12px',
                    borderRadius: 8,
                    display: 'inline-flex',
                    alignItems: 'center',
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
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

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Min chapters</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {MIN_CHAPTER_OPTIONS.map((opt) => {
              const active = minChapters === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => onUpdateUrl({ minCh: opt.id === '1' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    minHeight: 40,
                    padding: '8px 12px',
                    borderRadius: 8,
                    display: 'inline-flex',
                    alignItems: 'center',
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
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

        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Genre match</div>
          <div style={{ display: 'flex', gap: 6 }}>
            {(['and', 'or'] as const).map((gm) => {
              const active = genreMode === gm;
              return (
                <button
                  key={gm}
                  type="button"
                  className="bare-button"
                  onClick={() => onUpdateUrl({ gm: gm === 'and' ? null : gm, page: '1' }, { replace: true })}
                  style={{
                    minHeight: 40,
                    padding: '8px 12px',
                    borderRadius: 8,
                    display: 'inline-flex',
                    alignItems: 'center',
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
                    fontWeight: active ? 700 : 500,
                    color: active ? KatanaColors.chipSelectedText : KatanaColors.textMuted,
                  }}
                >
                  {gm === 'and' ? 'Match All' : 'Match Any'}
                </button>
              );
            })}
          </div>
        </div>
        <div>
          <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Language</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {(
              [
                { id: 'all', label: 'All' },
                { id: 'en', label: 'EN' },
                { id: 'ja', label: 'JA' },
                { id: 'ko', label: 'KO' },
                { id: 'zh', label: 'ZH' },
              ] as const
            ).map((opt) => {
              const active = languageFilter === opt.id;
              return (
                <button
                  key={opt.id}
                  type="button"
                  className="bare-button"
                  onClick={() => onUpdateUrl({ lang: opt.id === 'all' ? null : opt.id, page: '1' }, { replace: true })}
                  style={{
                    minHeight: 40,
                    padding: '8px 12px',
                    borderRadius: 8,
                    display: 'inline-flex',
                    alignItems: 'center',
                    background: active ? KatanaColors.chipSelectedBg : KatanaColors.surfaceAlt,
                    border: `1px solid ${active ? KatanaColors.chipSelectedBorder : KatanaColors.border}`,
                    fontFamily: Fonts.body,
                    fontSize: 12.5,
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
      </div>

      <div>
        <div style={{ ...KatanaType.small, fontWeight: 700, marginBottom: 6 }}>Author filter</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, maxWidth: 340, position: 'relative' }}>
          <input
            value={authorDraft}
            onChange={(e) => setAuthorDraft(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                onUpdateUrl({ author: authorDraft.trim() || null, page: '1' }, { replace: true });
              }
            }}
            placeholder="Filter by author name (updates live)..."
            aria-label="Filter by author"
            style={{
              flex: 1,
              height: 40,
              padding: authorDraft ? '0 40px 0 12px' : '0 12px',
              borderRadius: 8,
              background: KatanaColors.background,
              border: `1px solid ${KatanaColors.border}`,
              fontFamily: Fonts.body,
              fontSize: 13,
              color: KatanaColors.text,
              outline: 'none',
            }}
          />
          {authorDraft && (
            <button
              type="button"
              className="bare-button"
              aria-label="Clear author filter"
              onClick={() => {
                setAuthorDraft('');
                onUpdateUrl({ author: null, page: '1' }, { replace: true });
              }}
              style={{
                position: 'absolute',
                right: 0,
                width: 40,
                height: 40,
                borderRadius: 8,
                display: 'grid',
                placeItems: 'center',
              }}
            >
              <Icon name="close" size={16} color={KatanaColors.textMuted} />
            </button>
          )}
        </div>
      </div>

      {genres.length > 0 && (
        <div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 6, marginBottom: 8 }}>
            <span style={{ ...KatanaType.small, fontWeight: 700 }}>Genres & Tags</span>
            <span style={{ ...KatanaType.small, fontSize: 12 }}>
              Tap genre to <span style={{ color: KatanaColors.green, fontWeight: 700 }}>+ Include</span>, or{' '}
              <span style={{ color: KatanaColors.crimson, fontWeight: 700 }}>−</span> to exclude
            </span>
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {genres.map((g) => {
              const inc = includeGenres.includes(g.slug);
              const exc = excludeGenres.includes(g.slug);
              return (
                <div
                  key={g.slug}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    borderRadius: 9,
                    overflow: 'hidden',
                    background: inc
                      ? withAlpha(KatanaColors.green, 0.18)
                      : exc
                        ? withAlpha(KatanaColors.crimson, 0.18)
                        : KatanaColors.surfaceAlt,
                    border: `1px solid ${inc ? KatanaColors.green : exc ? KatanaColors.crimson : KatanaColors.border}`,
                  }}
                >
                  <button
                    type="button"
                    className="bare-button"
                    aria-pressed={inc}
                    aria-label={`${inc ? 'Remove include' : 'Include'} ${g.name}`}
                    onClick={() => onToggleIncludeGenre(g.slug)}
                    style={{
                      minHeight: 40,
                      padding: '0 12px',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 4,
                      fontFamily: Fonts.body,
                      fontSize: 12.5,
                      fontWeight: inc || exc ? 700 : 600,
                      textDecoration: exc ? 'line-through' : 'none',
                      color: inc ? KatanaColors.green : exc ? KatanaColors.crimson : KatanaColors.textMuted,
                    }}
                  >
                    {inc && <Icon name="add" size={14} color={KatanaColors.green} />}
                    <span>{g.name}</span>
                  </button>
                  <button
                    type="button"
                    className="bare-button"
                    aria-pressed={exc}
                    aria-label={`${exc ? 'Remove exclude' : 'Exclude'} ${g.name}`}
                    title={exc ? `Remove ${g.name} exclusion` : `Exclude ${g.name}`}
                    onClick={() => onToggleExcludeGenre(g.slug)}
                    style={{
                      width: 40,
                      height: 40,
                      display: 'grid',
                      placeItems: 'center',
                      borderLeft: `1px solid ${inc ? withAlpha(KatanaColors.green, 0.35) : exc ? withAlpha(KatanaColors.crimson, 0.35) : KatanaColors.border}`,
                      background: exc ? withAlpha(KatanaColors.crimson, 0.22) : 'transparent',
                      color: exc ? KatanaColors.crimson : KatanaColors.textLight,
                      fontFamily: Fonts.body,
                      fontSize: 15,
                      fontWeight: 700,
                    }}
                  >
                    −
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
