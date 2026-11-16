// Port of lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart.
import { useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Align, linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../shared/widgets/Icon';
import { STAR_CATEGORIES, STAR_CATEGORY_INFO, starlightService, type StarNote } from './starlightService';

export function StarlightJarWidget({ standalone = false }: { standalone?: boolean }) {
  const auth = useAuth();
  const notes = useSource(() => starlightService.getStarNotes(), [], []);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [openNote, setOpenNote] = useState<StarNote | null>(null);
  const [dropOpen, setDropOpen] = useState(false);
  const [dropContent, setDropContent] = useState('');
  const [dropCategory, setDropCategory] = useState('gratitude');

  const filtered = notes.filter((n) => {
    if (selectedCategory && n.category !== selectedCategory) return false;
    if (search && !n.content.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  const revealRandom = () => {
    if (filtered.length === 0) return;
    setOpenNote(filtered[Math.floor(Math.random() * filtered.length)]);
  };

  const submitDrop = async () => {
    const text = dropContent.trim();
    if (!text) return;
    setDropContent('');
    setDropOpen(false);
    await starlightService.addStarNote({
      content: text,
      author: auth.currentUser ?? 'Khent',
      category: dropCategory,
    });
  };

  return (
    <div style={{ position: 'relative' }}>
      <EverglowFeatureHeader
        title="Starlight Jar"
        subtitle="gratitude under the stars"
        icon="auto_awesome"
        hue={AppColors.blushGold}
        showBack={standalone}
      />

      <div style={{ padding: '6px 20px' }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            background: AppColors.twilight,
            borderRadius: 14,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
            padding: '0 12px',
          }}
        >
          <Icon name="search" size={18} color={AppColors.blushGold} />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search stars…"
            style={{
              flex: 1,
              background: 'transparent',
              border: 'none',
              outline: 'none',
              padding: '10px 8px',
              ...AppTypography.outfitWhite,
              fontSize: 13,
            }}
          />
          {search && (
            <button type="button" className="bare-button" onClick={() => setSearch('')}>
              <Icon name="clear" size={16} color={withAlpha(AppColors.petalWhite, 0.4)} />
            </button>
          )}
        </div>

        <div style={{ height: 8 }} />
        <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex', gap: 6 }}>
          <CategoryChip label="All" selected={selectedCategory == null} onClick={() => setSelectedCategory(null)} />
          {STAR_CATEGORIES.map((cat) => (
            <CategoryChip
              key={cat}
              label={`${STAR_CATEGORY_INFO[cat]?.[0] ?? ''} ${STAR_CATEGORY_INFO[cat]?.[1] ?? cat}`}
              selected={selectedCategory === cat}
              onClick={() => setSelectedCategory(selectedCategory === cat ? null : cat)}
            />
          ))}
        </div>
      </div>

      <div style={{ height: 390, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
        <button
          type="button"
          className="bare-button"
          aria-label="Tap jar to pick a star note"
          onClick={revealRandom}
          style={{
            position: 'relative',
            width: 280,
            height: 350,
            borderRadius: 36,
            background: linear([withAlpha(AppColors.moonlight, 0.1), withAlpha(AppColors.velvet, 0.45), withAlpha(AppColors.inkDeep, 0.85)], {
              begin: Align.topLeft,
              end: Align.bottomRight,
            }),
            border: `1.5px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
            boxShadow: `0 16px 34px ${withAlpha(AppColors.inkDeep, 0.65)}, inset 0 1px 18px ${withAlpha(AppColors.moonlight, 0.08)}`,
            overflow: 'hidden',
          }}
        >
          {/* Jar lid */}
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 36,
              right: 36,
              height: 18,
              borderRadius: '0 0 10px 10px',
              background: linear([AppColors.blushGold, AppColors.warmAmber]),
              opacity: 0.85,
            }}
          />

          {notes.length > 0 && (
            <div
              style={{
                position: 'absolute',
                top: 24,
                left: '50%',
                transform: 'translateX(-50%)',
                padding: '4px 12px',
                borderRadius: 12,
                background: withAlpha(AppColors.deepRose, 0.8),
                boxShadow: `0 0 8px ${withAlpha(AppColors.deepRose, 0.3)}`,
              }}
            >
              <span style={{ ...AppTypography.outfitBold, fontSize: 11, letterSpacing: 0.5 }}>
                {notes.length} {notes.length === 1 ? 'star' : 'stars'}
              </span>
            </div>
          )}

          {/* Stars inside jar */}
          {filtered.slice(0, 24).map((star, idx) => {
            const left = 24 + ((idx * 67) % 210);
            const top = 80 + ((idx * 53) % 230);
            const colors = [AppColors.blushGold, AppColors.roseQuartz, AppColors.auroraGold, AppColors.auroraLilac];
            return (
              <div
                key={star.id}
                style={{
                  position: 'absolute',
                  left,
                  top,
                  pointerEvents: 'none',
                  filter: `drop-shadow(0 0 6px ${withAlpha(colors[idx % colors.length], 0.7)})`,
                }}
              >
                <Icon name="star" size={20} color={colors[idx % colors.length]} />
              </div>
            );
          })}
        </button>

        <div style={{ position: 'absolute', right: 20, bottom: 24, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button
            type="button"
            className="bare-button"
            aria-label="Surprise star"
            onClick={revealRandom}
            style={{
              width: 40,
              height: 40,
              borderRadius: '50%',
              background: AppColors.blushGold,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 12px rgba(0,0,0,0.35)',
            }}
          >
            <Icon name="casino" size={20} color={AppColors.velvet} />
          </button>
          <button
            type="button"
            className="bare-button"
            aria-label="Drop a star"
            onClick={() => setDropOpen(true)}
            style={{
              width: 52,
              height: 52,
              borderRadius: 16,
              background: AppColors.deepRose,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 6px 16px rgba(0,0,0,0.4)',
            }}
          >
            <Icon name="add" size={24} color={AppColors.petalWhite} />
          </button>
        </div>
      </div>

      {openNote && (
        <div
          onClick={() => setOpenNote(null)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 400,
              padding: 24,
              borderRadius: 24,
              background: linear([AppColors.velvet, AppColors.inkDeep]),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.4)}`,
              textAlign: 'center',
            }}
          >
            <div style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.blushGold, letterSpacing: 1 }}>
              {(STAR_CATEGORY_INFO[openNote.category]?.[1] ?? openNote.category).toUpperCase()}
            </div>
            <div style={{ height: 12 }} />
            <div style={{ ...AppTypography.cormorantBold, fontSize: 22, color: AppColors.petalWhite }}>
              “{openNote.content}”
            </div>
            <div style={{ height: 12 }} />
            <div style={{ ...AppTypography.outfitMuted, fontSize: 12 }}>— {openNote.author}</div>
            <div style={{ height: 18 }} />
            <button
              type="button"
              className="bare-button"
              onClick={() => setOpenNote(null)}
              style={{ margin: '0 auto', padding: '8px 20px', borderRadius: 999, background: AppColors.deepRose, ...AppTypography.outfitBold, fontSize: 12 }}
            >
              Keep in heart
            </button>
          </div>
        </div>
      )}

      {dropOpen && (
        <div
          onClick={() => setDropOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 420,
              padding: 24,
              borderRadius: 24,
              background: AppColors.velvet,
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
            }}
          >
            <div style={{ ...AppTypography.cormorantBold, fontSize: 22, marginBottom: 12 }}>Drop a Star</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginBottom: 12 }}>
              {STAR_CATEGORIES.map((cat) => (
                <CategoryChip
                  key={cat}
                  label={STAR_CATEGORY_INFO[cat]?.[1] ?? cat}
                  selected={dropCategory === cat}
                  onClick={() => setDropCategory(cat)}
                />
              ))}
            </div>
            <textarea
              value={dropContent}
              onChange={(e) => setDropContent(e.target.value)}
              placeholder="Write a gratitude note or dream..."
              rows={3}
              style={{
                width: '100%',
                background: AppColors.inkDeep,
                border: `1px solid ${withAlpha(AppColors.moonlight, 0.16)}`,
                borderRadius: 12,
                padding: 12,
                ...AppTypography.outfitWhite,
                fontSize: 13,
                outline: 'none',
              }}
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 14 }}>
              <button type="button" className="bare-button" onClick={() => setDropOpen(false)} style={{ padding: '8px 14px', ...AppTypography.outfitMuted }}>
                Cancel
              </button>
              <button
                type="button"
                className="bare-button"
                onClick={submitDrop}
                style={{ padding: '8px 18px', borderRadius: 999, background: AppColors.deepRose, ...AppTypography.outfitBold, fontSize: 13 }}
              >
                Drop Star ✨
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function CategoryChip({ label, selected, onClick }: { label: string; selected: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onClick}
      style={{
        padding: '5px 11px',
        borderRadius: 999,
        background: selected ? withAlpha(AppColors.blushGold, 0.22) : withAlpha(AppColors.moonlight, 0.06),
        border: `1px solid ${withAlpha(AppColors.blushGold, selected ? 0.55 : 0.16)}`,
        ...AppTypography.outfitBold,
        fontSize: 11,
        color: selected ? AppColors.blushGold : withAlpha(AppColors.petalWhite, 0.72),
        whiteSpace: 'nowrap',
      }}
    >
      {label}
    </button>
  );
}
