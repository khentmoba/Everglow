// Ports of drop_star_dialog.dart and note_display_dialog.dart.
import { useEffect, useState } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, M3Scheme, withAlpha } from '../../core/theme/colors';
import { Curves } from '../../core/theme/motion';
import { boxShadow, insetBorder, letterSpacing, lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useDraft } from '../../shared/utils/draft';
import { TextButton } from '../../shared/widgets/Dialogs';
import { ElevatedButton } from '../../shared/widgets/ElevatedButton';
import { FilledField } from '../../shared/widgets/FilledField';
import { Icon } from '../../shared/widgets/Icon';
import { STAR_CATEGORIES, STAR_CATEGORY_INFO, type StarNote } from './starlightService';

export type StarDropResult = { content: string; category: string; tags: string[] };

const panel = (blur: number) => ({
  margin: '0 32px',
  background: AppColors.velvet,
  borderRadius: 24,
  boxShadow: `${insetBorder(withAlpha(AppColors.blushGold, 0.25), 1.5).boxShadow}, ${boxShadow([
    { color: withAlpha(AppColors.deepRose, 0.3), blur, spread: 5 },
  ])}`,
  boxSizing: 'border-box' as const,
});

export function DropStarDialog({ close }: { close: (r: StarDropResult | null) => void }) {
  const { height } = useViewport();
  const [text, setText, clearDraft] = useDraft('starlight:drop');
  const [tag, setTag] = useState('');
  const [category, setCategory] = useState('gratitude');
  const [tags, setTags] = useState<string[]>([]);
  const canSubmit = text.trim() !== '';

  const addTag = () => {
    const t = tag.trim().toLowerCase();
    if (t && !tags.includes(t) && tags.length < 5) {
      setTags([...tags, t]);
      setTag('');
    }
  };

  return (
    <div
      style={{
        ...panel(20),
        padding: 25.5,
        maxHeight: height * 0.85,
        overflowY: 'auto',
        width: 'calc(100% - 64px)',
        maxWidth: 'none',
      }}
    >
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ ...AppTypography.cormorantBold, fontSize: 26, lineHeight: mixedLineHeight(26) }}>Drop a Star ✨</div>
        <div style={{ height: 16 }} />
        <div
          style={{
            ...AppTypography.outfitBold,
            fontSize: 12,
            lineHeight: lineHeight(12),
            color: withAlpha(AppColors.petalWhite, 0.75),
            ...letterSpacing(1),
          }}
        >
          Category
        </div>
        <div style={{ height: 8 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: '6px 8px' }}>
          {STAR_CATEGORIES.map((cat) => {
            const [emoji, label] = STAR_CATEGORY_INFO[cat];
            const selected = category === cat;
            const bw = selected ? 1.5 : 1;
            return (
              <button
                key={cat}
                type="button"
                className="bare-button"
                onClick={() => setCategory(cat)}
                style={{
                  padding: `${6 + bw}px ${12 + bw}px`,
                  borderRadius: 16,
                  background: selected ? withAlpha(AppColors.deepRose, 0.7) : AppColors.twilight,
                  ...insetBorder(selected ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.15), bw),
                  transition: 'background 200ms, box-shadow 200ms, padding 200ms',
                  ...AppTypography.outfitWhite,
                  fontSize: 12,
                  lineHeight: lineHeight(12),
                  fontWeight: selected ? 700 : 500,
                  color: selected ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.7),
                  cursor: 'pointer',
                }}
              >
                {emoji} {label}
              </button>
            );
          })}
        </div>
        <div style={{ height: 16 }} />
        <FilledField
          value={text}
          onChange={setText}
          hint="What are you grateful for today?"
          hintAlpha={0.65}
          radius={16}
          padding={[16, 16]}
          lines={3}
          borderColor={M3Scheme.onSurfaceVariant}
          focusColor={AppColors.blushGold}
        />
        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', alignItems: 'center', width: '100%' }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <FilledField
              value={tag}
              onChange={setTag}
              onSubmit={addTag}
              hint="Add a tag…"
              hintAlpha={0.55}
              radius={12}
              padding={[12, 8]}
              fontSize={12}
              minHeight={0}
              borderColor={M3Scheme.onSurfaceVariant}
              focusColor={withAlpha(AppColors.blushGold, 0.6)}
            />
          </div>
          <div style={{ width: 8 }} />
          <button
            type="button"
            className="bare-button"
            aria-label="Add tag"
            onClick={addTag}
            style={{
              padding: 8,
              borderRadius: 8,
              background: withAlpha(AppColors.deepRose, 0.5),
              display: 'flex',
              cursor: 'pointer',
            }}
          >
            <Icon name="add" variant="filled" size={16} color={AppColors.petalWhite} />
          </button>
        </div>
        {tags.length > 0 && (
          <>
            <div style={{ height: 8 }} />
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px 6px', alignSelf: 'flex-start' }}>
              {tags.map((t) => (
                <span
                  key={t}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 4,
                    height: 24,
                    padding: '0 4px 0 10px',
                    borderRadius: 12,
                    background: withAlpha(AppColors.softLavender, 0.3),
                    border: `1px solid ${withAlpha(AppColors.moonlight, 0.18)}`,
                    ...AppTypography.outfitWhite,
                    fontSize: 10,
                    color: AppColors.petalWhite,
                  }}
                >
                  {t}
                  <button
                    type="button"
                    className="bare-button"
                    aria-label={`Remove ${t}`}
                    onClick={() => setTags(tags.filter((x) => x !== t))}
                    style={{ display: 'flex', cursor: 'pointer' }}
                  >
                    <Icon name="cancel" size={16} color={withAlpha(AppColors.petalWhite, 0.75)} />
                  </button>
                </span>
              ))}
            </div>
          </>
        )}
        <div style={{ height: 24 }} />
        <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', width: '100%' }}>
          <TextButton
            onPressed={() => close(null)}
            color={withAlpha(AppColors.roseQuartz, 0.6)}
            style={{ ...AppTypography.outfitWhite, fontSize: 14, color: withAlpha(AppColors.roseQuartz, 0.6) }}
          >
            Cancel
          </TextButton>
          <div style={{ width: 12 }} />
          <ElevatedButton
            padding="12px 24px"
            disabled={!canSubmit}
            disabledBackground={withAlpha(AppColors.deepRose, 0.3)}
            onPressed={() => {
              const result = { content: text, category, tags: [...tags] };
              clearDraft();
              close(result);
            }}
          >
            <span
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 14,
                lineHeight: '18px',
                fontWeight: 700,
                color: AppColors.petalWhite,
              }}
            >
              Drop it!
            </span>
          </ElevatedButton>
        </div>
      </div>
    </div>
  );
}

export function NoteDisplayDialog({ note, close }: { note: StarNote; close: () => void }) {
  const [info] = useState(() => STAR_CATEGORY_INFO[note.category] ?? ['⭐', note.category]);
  const [scale, setScale] = useState(0);
  useEffect(() => {
    const start = performance.now();
    let raf = 0;
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / 400);
      setScale(Curves.easeOutBack(t));
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);
  const d = note.timestamp;
  return (
    <div
      style={{
        ...panel(30),
        padding: 33.5,
        maxWidth: 'calc(100% - 64px)',
        transform: `scale(${scale})`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div style={{ padding: '4px 12px', borderRadius: 12, background: withAlpha(AppColors.deepRose, 0.4) }}>
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 11,
            lineHeight: mixedLineHeight(11),
            color: AppColors.blushGold,
            display: 'block',
            ...letterSpacing(0.8),
          }}
        >
          {info[0]} {info[1]}
        </span>
      </div>
      <div style={{ height: 20 }} />
      <Icon name="auto_awesome" variant="filled" size={36} color={AppColors.blushGold} />
      <div style={{ height: 16 }} />
      <div
        style={{
          ...AppTypography.cormorantHeading,
          fontSize: 22,
          lineHeight: lineHeight(22),
          color: AppColors.roseQuartz,
          fontStyle: 'italic',
          textAlign: 'center',
          paddingTop: 1,
        }}
      >
        {note.content}
      </div>
      {note.tags.length > 0 && (
        <>
          <div style={{ height: 16 }} />
          <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: '4px 6px' }}>
            {note.tags.map((t) => (
              <span
                key={t}
                style={{
                  padding: '2px 8px',
                  borderRadius: 8,
                  background: withAlpha(AppColors.softLavender, 0.2),
                  ...AppTypography.outfitWhite,
                  fontSize: 10,
                  lineHeight: '13px',
                  color: AppColors.softLavender,
                }}
              >
                #{t}
              </span>
            ))}
          </div>
        </>
      )}
      <div style={{ height: 24 }} />
      <div
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 14,
          lineHeight: lineHeight(14),
          fontWeight: 700,
          color: AppColors.blushGold,
          ...letterSpacing(1.2),
        }}
      >
        — {note.author.toUpperCase()}
      </div>
      <div style={{ height: 8 }} />
      <div
        style={{
          ...AppTypography.outfitWhite,
          fontSize: 12,
          lineHeight: lineHeight(12),
          color: withAlpha(AppColors.petalWhite, 0.7),
        }}
      >
        {d.getMonth() + 1}/{d.getDate()}/{d.getFullYear()}
      </div>
      <div style={{ height: 32 }} />
      <ElevatedButton padding="12px 40px" flat onPressed={close}>
        <span
          style={{ ...AppTypography.outfitWhite, fontSize: 14, lineHeight: '18px', fontWeight: 700, color: AppColors.petalWhite }}
        >
          Close
        </span>
      </ElevatedButton>
    </div>
  );
}
