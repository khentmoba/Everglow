// Port of lib/features/bucket_list/presentation/widgets/add_bucket_item_sheet.dart.
import { useLayoutEffect, useRef, useState, type CSSProperties } from 'react';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppMotion, orZero } from '../../core/theme/motion';
import { boxShadow, letterSpacing, lineHeight, mixedLineHeight, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { pickDate } from '../../shared/utils/pickDate';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { CenteredSheetArea, showModalBottomSheet } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { bucketListService, type BucketCategory, type BucketPriority } from './bucketListService';
import {
  assigneeHue,
  assigneeIcon,
  assigneeLabel,
  BUCKET_CATEGORY_IDS,
  BUCKET_CLAIR,
  BUCKET_KHENT,
  BUCKET_PRIORITIES,
  categoryInfo,
  priorityHue,
  PRIORITY_NAME,
  yMMMd,
} from './bucketUi';

export function showAddBucketItemSheet(createdBy: string) {
  void showModalBottomSheet<void>((close) => (
    <CenteredSheetArea close={() => close(null)}>
      <AddBucketItemSheet createdBy={createdBy} close={() => close(null)} />
    </CenteredSheetArea>
  ));
}

const bold = (size: number, color: string, height?: string): CSSProperties => ({
  ...AppTypography.outfitBold,
  fontSize: size,
  lineHeight: height ?? lineHeight(size),
  color,
});

function AddBucketItemSheet({ createdBy, close }: { createdBy: string; close: () => void }) {
  const { height } = useViewport();
  const [title, setTitle] = useState('');
  const [desc, setDesc] = useState('');
  const [category, setCategory] = useState<BucketCategory>('experience');
  const [priority, setPriority] = useState<BucketPriority>('medium');
  const [assignedTo, setAssignedTo] = useState<string | undefined>();
  const [dueDate, setDueDate] = useState<Date | undefined>();
  const [saving, setSaving] = useState(false);
  const canSave = title.trim() !== '';

  const save = async () => {
    const t = title.trim();
    if (t === '' || saving) return;
    setSaving(true);
    await bucketListService.add({
      title: t,
      description: desc.trim(),
      category,
      status: 'wish',
      createdBy,
      createdAt: new Date(),
      priority,
      assignedTo,
      dueDate,
    });
    close();
  };

  const pickDue = async () => {
    const now = new Date();
    const picked = await pickDate({
      initial: dueDate ?? now,
      first: new Date(now.getTime() - 86_400_000),
      last: new Date(now.getTime() + 365 * 2 * 86_400_000),
    });
    if (picked) setDueDate(picked);
  };

  return (
    <div style={{ width: '100%', minHeight: 0, display: 'flex', justifyContent: 'center' }}>
      <div
        style={{
          width: '100%',
          maxWidth: 560,
          maxHeight: Math.min(height * 0.92, height - 48),
          overflowY: 'auto',
          padding: '12px 24px 24px',
          background: AppColors.velvet,
          borderRadius: `${AppRadius.x3}px ${AppRadius.x3}px 0 0`,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
          boxSizing: 'border-box',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div
          style={{
            alignSelf: 'center',
            width: 40,
            height: 4,
            marginBottom: 16,
            flexShrink: 0,
            borderRadius: AppRadius.full,
            background: withAlpha(AppColors.petalWhite, 0.3),
          }}
        />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 26, lineHeight: mixedLineHeight(26, 1) }}>
              Plant a new dream ✨
            </div>
            <div style={{ height: 4 }} />
            <div
              style={{
                ...AppTypography.outfitWhite,
                fontSize: 12,
                lineHeight: lineHeight(12),
                color: withAlpha(AppColors.petalWhite, 0.55),
              }}
            >
              Something for just the two of you
            </div>
          </div>
          <button
            type="button"
            className="bare-button"
            aria-label="Close"
            onClick={close}
            style={{
              width: 38,
              height: 38,
              flexShrink: 0,
              boxSizing: 'border-box',
              borderRadius: '50%',
              background: withAlpha(AppColors.moonlight, 0.07),
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
            }}
          >
            <Icon name="close" size={18} color={withAlpha(AppColors.petalWhite, 0.7)} />
          </button>
        </div>
        <div style={{ height: 18 }} />
        <DreamField value={title} onChange={setTitle} hint="Japan together, a Persian cat, slow Sundays…" fontSize={15} />
        <div style={{ height: 10 }} />
        <DreamField
          value={desc}
          onChange={setDesc}
          hint="Little details, places, secret plans… (optional)"
          fontSize={14}
          multiline
        />
        <div style={{ height: 18 }} />
        <SectionLabel label="What kind of dream?" />
        <div style={{ height: 10 }} />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 8 }}>
          {BUCKET_CATEGORY_IDS.map((c) => (
            <CategoryTile key={c} category={c} selected={category === c} onTap={() => setCategory(c)} />
          ))}
        </div>
        <div style={{ height: 18 }} />
        <SectionLabel label="What pace?" />
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {BUCKET_PRIORITIES.map((p) => (
            <ChoicePill
              key={p}
              label={PRIORITY_NAME[p]}
              dot={priorityHue(p)}
              hue={priorityHue(p)}
              selected={priority === p}
              onTap={() => setPriority(p)}
            />
          ))}
        </div>
        <div style={{ height: 18 }} />
        <SectionLabel label="Whose dream is it?" />
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {[undefined, BUCKET_KHENT, BUCKET_CLAIR].map((u) => (
            <ChoicePill
              key={u ?? 'both'}
              label={u == null ? 'Both of us' : assigneeLabel(u)}
              icon={assigneeIcon(u)}
              hue={assigneeHue(u)}
              selected={assignedTo === u}
              onTap={() => setAssignedTo(u)}
            />
          ))}
        </div>
        <div style={{ height: 18 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ flex: 1 }}>
            <SectionLabel label="Dream date" />
          </div>
          <button
            type="button"
            className="bare-button"
            onClick={() => void pickDue()}
            style={{
              padding: '9px 14px',
              borderRadius: AppRadius.lg,
              background: dueDate == null ? AppColors.twilight : withAlpha(AppColors.deepRose, 0.2),
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.25)}`,
              display: 'flex',
              alignItems: 'center',
              cursor: 'pointer',
            }}
          >
            <Icon name="calendar_today" size={14} color={AppColors.blushGold} />
            <div style={{ width: 7 }} />
            <span style={bold(12, AppColors.petalWhite)}>{dueDate == null ? 'Someday' : yMMMd(dueDate)}</span>
          </button>
          {dueDate != null && (
            <>
              <div style={{ width: 8 }} />
              <button
                type="button"
                className="bare-button"
                aria-label="Clear dream date"
                onClick={() => setDueDate(undefined)}
                style={{ display: 'flex', cursor: 'pointer' }}
              >
                <Icon name="cancel" size={20} color={withAlpha(AppColors.petalWhite, 0.5)} />
              </button>
            </>
          )}
        </div>
        <div style={{ height: 22 }} />
        <SaveButton enabled={canSave} saving={saving} onTap={() => void save()} />
      </div>
    </div>
  );
}

function SectionLabel({ label }: { label: string }) {
  return <div style={{ ...bold(10, withAlpha(AppColors.petalWhite, 0.5)), ...letterSpacing(1.4) }}>{label.toUpperCase()}</div>;
}

function DreamField({
  value,
  onChange,
  hint,
  fontSize,
  multiline = false,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  fontSize: number;
  multiline?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  const lh = Math.round(fontSize * 1.5);
  // Flutter grows a minLines 1 / maxLines 2 field with its text, and its hint wraps
  // the same way; the textarea's scrollHeight covers both.
  const area = useRef<HTMLTextAreaElement>(null);
  const [lines, setLines] = useState(1);
  useLayoutEffect(() => {
    const el = area.current;
    if (!el) return;
    el.style.height = '0';
    const n = Math.round((el.scrollHeight - 28) / lh);
    el.style.height = '';
    setLines(Math.min(2, Math.max(1, n)));
  }, [value, lh]);
  const style: CSSProperties = {
    display: 'block',
    width: '100%',
    boxSizing: 'border-box',
    // Flutter leaves the hint ~8px less room than the 16px content padding suggests.
    padding: '14px 24px 14px 16px',
    height: 28 + lh * (multiline ? lines : 1),
    background: AppColors.twilight,
    borderRadius: AppRadius.md,
    border: 'none',
    boxShadow: `inset 0 0 0 1px ${focused ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.15)}`,
    outline: 'none',
    resize: 'none',
    overflowY: 'hidden',
    textOverflow: 'ellipsis',
    ...AppTypography.outfitWhite,
    fontSize,
    lineHeight: `${lh}px`,
    letterSpacing: 0.5,
    color: AppColors.petalWhite,
    ['--hint-color' as string]: withAlpha(AppColors.petalWhite, 0.35),
    ['--hint-size' as string]: '14px',
  };
  const common = {
    className: 'money-input',
    value,
    placeholder: hint,
    'aria-label': hint,
    autoCapitalize: 'sentences',
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
  };
  return multiline ? (
    <textarea {...common} ref={area} onChange={(e) => onChange(e.target.value)} style={style} />
  ) : (
    <input {...common} onChange={(e) => onChange(e.target.value)} style={style} />
  );
}

function CategoryTile({ category, selected, onTap }: { category: BucketCategory; selected: boolean; onTap: () => void }) {
  const { name, emoji, hue } = categoryInfo(category);
  const bw = selected ? 1.6 : 1;
  const ms = orZero(AppMotion.fast);
  return (
    <div style={{ position: 'relative', minWidth: 0 }}>
      {selected && (
        <div
          aria-hidden
          style={shadowLayer({ color: withAlpha(hue, 0.22), blur: 12, offset: [0, 4] }, { radius: AppRadius.lg })}
        />
      )}
      <button
        type="button"
        className="bare-button"
        aria-label={`${name} category`}
        aria-pressed={selected}
        onClick={onTap}
        style={{
          aspectRatio: '1.55',
          minWidth: 0,
          borderRadius: AppRadius.lg,
          background: selected
            ? `linear-gradient(135deg, ${withAlpha(hue, 0.28)}, ${withAlpha(hue, 0.08)})`
            : `linear-gradient(135deg, ${withAlpha(AppColors.moonlight, 0.05)}, ${withAlpha(AppColors.moonlight, 0.02)})`,
          boxShadow: `inset 0 0 0 ${bw}px ${selected ? withAlpha(hue, 0.7) : withAlpha(AppColors.moonlight, 0.1)}`,
          position: 'relative',
          width: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: `0 ${bw}px`,
          transition: `box-shadow ${ms}ms, background ${ms}ms`,
          cursor: 'pointer',
        }}
      >
        <span style={{ fontSize: 22, lineHeight: mixedLineHeight(22) }}>{emoji}</span>
        <div style={{ height: 4 }} />
        <span
          style={{
            ...bold(10.5, selected ? hue : withAlpha(AppColors.petalWhite, 0.6)),
            maxWidth: '100%',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {name}
        </span>
      </button>
    </div>
  );
}

function ChoicePill({
  label,
  icon,
  dot,
  hue,
  selected,
  onTap,
}: {
  label: string;
  icon?: string;
  dot?: string;
  hue: string;
  selected: boolean;
  onTap: () => void;
}) {
  const ms = orZero(AppMotion.fast);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      aria-pressed={selected}
      onClick={onTap}
      style={{
        padding: '9px 13px',
        borderRadius: AppRadius.full,
        background: selected ? withAlpha(hue, 0.16) : withAlpha(AppColors.moonlight, 0.05),
        border: `1px solid ${selected ? withAlpha(hue, 0.6) : withAlpha(AppColors.moonlight, 0.12)}`,
        display: 'flex',
        alignItems: 'center',
        transition: `background ${ms}ms, border-color ${ms}ms`,
        cursor: 'pointer',
      }}
    >
      {dot && (
        <>
          <div style={{ width: 8, height: 8, borderRadius: '50%', background: dot }} />
          <div style={{ width: 7 }} />
        </>
      )}
      {icon && (
        <>
          <Icon name={icon} size={13} color={selected ? hue : withAlpha(AppColors.petalWhite, 0.55)} />
          <div style={{ width: 6 }} />
        </>
      )}
      <span style={bold(12, selected ? hue : withAlpha(AppColors.petalWhite, 0.6))}>{label}</span>
    </button>
  );
}

function SaveButton({ enabled, saving, onTap }: { enabled: boolean; saving: boolean; onTap: () => void }) {
  const active = enabled && !saving;
  const ms = orZero(AppMotion.fast);
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="Add to our story"
      disabled={!active}
      onClick={active ? onTap : undefined}
      style={{
        width: '100%',
        padding: '15px 0',
        borderRadius: AppRadius.lg,
        background: active
          ? `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.rosePressed})`
          : withAlpha(AppColors.moonlight, 0.06),
        border: `1px solid ${active ? withAlpha(AppColors.blushGold, 0.35) : withAlpha(AppColors.moonlight, 0.1)}`,
        boxShadow: active ? boxShadow([{ color: withAlpha(AppColors.deepRose, 0.35), blur: 18, offset: [0, 6] }]) : 'none',
        display: 'flex',
        justifyContent: 'center',
        transition: `background ${ms}ms, box-shadow ${ms}ms`,
        cursor: active ? 'pointer' : 'default',
      }}
    >
      {saving ? (
        <CircularProgress size={20} strokeWidth={2} color={AppColors.petalWhite} />
      ) : (
        <span style={bold(14, enabled ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.4), mixedLineHeight(14))}>
          {enabled ? 'Add to our story 🌟' : 'Name your dream first ✨'}
        </span>
      )}
    </button>
  );
}
