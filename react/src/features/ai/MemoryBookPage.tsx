// Port of lib/features/ai/presentation/screens/memory_book_screen.dart.
import { useEffect, useRef, useState } from 'react';
import { AppColors, Derived, M3Scheme, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { letterSpacing, linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowSkeleton } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import { DropdownField, MaterialIconButton } from '../../shared/widgets/MaterialFields';
import { AIMemoryRepository } from './aiMemoryRepo';
import { isOnThisDay, memoryFactFromJson, parseFactStructure, type MemoryFact } from './memory';

const CATEGORIES: (string | null)[] = [null, 'fact', 'preference', 'dislike', 'goal', 'date', 'habit'];
const medium = { ...AppTypography.outfitMedium, fontSize: 14, lineHeight: lineHeight(14) };

export function MemoryBookPage() {
  const repo = useRef(new AIMemoryRepository()).current;
  const [facts, setFacts] = useState<MemoryFact[]>([]);
  const [loading, setLoading] = useState(true);
  const [queryText, setQueryText] = useState('');
  const [category, setCategory] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    await repo.load();
    setFacts(repo.facts);
    setLoading(false);
  };
  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const visible = (() => {
    let list = [...facts];
    if (category != null) list = list.filter((f) => f.category === category);
    const q = queryText.trim().toLowerCase();
    if (q !== '')
      list = list.filter((f) => `${f.fact} ${f.subject ?? ''} ${f.object ?? ''} ${f.category}`.toLowerCase().includes(q));
    const time = (d: Date | null) => (d ?? new Date(2000, 0, 1)).getTime();
    list.sort((a, b) => (a.pinned !== b.pinned ? (a.pinned ? -1 : 1) : time(b.createdAt) - time(a.createdAt)));
    return list;
  })();

  const addFact = async () => {
    const result = await showDialog<MemoryFact>((close) => <AddMemoryDialog close={close} />);
    if (result == null) return;
    await repo.saveStructured(result);
    await load();
  };

  const deleteFact = async (fact: MemoryFact) => {
    const confirmed = await showDialog<boolean>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        radius={AppRadius.x2}
        title={<span style={{ color: AppColors.petalWhite }}>Forget this memory?</span>}
        content={<span style={medium}>Motchi will no longer remember: {fact.fact}</span>}
        actions={[
          <TextButton key="keep" onPressed={() => close(false)}>
            Keep it
          </TextButton>,
          <TextButton key="forget" onPressed={() => close(true)} color={AppColors.error}>
            Forget
          </TextButton>,
        ]}
      />
    ));
    if (confirmed !== true) return;
    await repo.delete(fact.id);
    await load();
  };

  const onThisDay = facts.filter((f) => isOnThisDay(f, new Date()));

  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.twilight }}>
      <EverglowBackground
        glows={[
          { color: AppColors.softLavender, alignment: [-0.7, -0.8], size: 0.7, opacity: 0.12 },
          { color: AppColors.auroraRose, alignment: [0.85, 0.9], size: 0.6, opacity: 0.1 },
        ]}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          paddingTop: 'env(safe-area-inset-top)',
          paddingBottom: 'env(safe-area-inset-bottom)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <EverglowFeatureHeader
          title="Motchi's Memory Book"
          subtitle="what Motchi remembers about you"
          icon="menu_book"
          hue={AppColors.softLavender}
          actions={[
            <MaterialIconButton
              key="add"
              icon="add"
              tooltip="Add a memory"
              color={AppColors.softLavender}
              onPressed={() => void addFact()}
            />,
          ]}
        />
        <SearchBar value={queryText} onChange={setQueryText} />
        <div className="no-scrollbar" style={{ height: 42, flexShrink: 0, overflowX: 'auto', overflowY: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, height: '100%', padding: '0 16px', width: 'max-content' }}>
            {CATEGORIES.map((c) => (
              <ChoiceChip key={c ?? 'all'} label={c ?? 'All'} selected={category === c} onSelected={() => setCategory(c)} />
            ))}
          </div>
        </div>
        {onThisDay.length > 0 && <OnThisDayBanner facts={onThisDay} />}
        <div style={{ flex: 1, minHeight: 0 }}>
          {loading ? (
            <div style={{ padding: 16 }}>
              <EverglowSkeleton height={120} radius={16} />
            </div>
          ) : visible.length === 0 ? (
            <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ ...medium, padding: 24, textAlign: 'center' }}>
                No memories here yet. Tell Motchi something worth keeping.
              </div>
            </div>
          ) : (
            <div className="no-scrollbar" style={{ height: '100%', overflowY: 'auto' }}>
              <div style={{ padding: '12px 16px 24px', display: 'flex', flexDirection: 'column', gap: 8 }}>
                {visible.map((fact) => (
                  <MemoryCard
                    key={fact.id || fact.fact}
                    fact={fact}
                    onPin={async () => {
                      await repo.setPinned(fact.id, !fact.pinned);
                      await load();
                    }}
                    onDelete={() => void deleteFact(fact)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function SearchBar({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const [focused, setFocused] = useState(false);
  return (
    <div style={{ padding: '4px 16px', flexShrink: 0 }}>
      <div
        style={{
          position: 'relative',
          height: 48,
          borderRadius: AppRadius.full,
          background: Derived.surfaceGlass,
          boxShadow: `inset 0 0 0 ${focused ? 2 : 1}px ${focused ? withAlpha(AppColors.softLavender, 0.7) : Derived.border}`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <div style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Icon name="search" color={AppColors.softLavender} />
        </div>
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          placeholder="Search memories..."
          aria-label="Search memories"
          className="memory-search"
          style={{
            flex: 1,
            minWidth: 0,
            height: '100%',
            padding: '0 16px 0 4px',
            background: 'transparent',
            border: 0,
            outline: 'none',
            ...AppTypography.outfitWhite,
            fontSize: 16,
            caretColor: AppColors.deepRose,
          }}
        />
        <style>{`.memory-search::placeholder{color:${Derived.textMuted};opacity:1}`}</style>
      </div>
    </div>
  );
}

function ChoiceChip({ label, selected, onSelected }: { label: string; selected: boolean; onSelected: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      role="radio"
      aria-checked={selected}
      onClick={onSelected}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        position: 'relative',
        height: 34,
        padding: '0 17px',
        paddingLeft: selected ? 10 : 17,
        borderRadius: AppRadius.xl,
        background: selected ? withAlpha(AppColors.softLavender, 0.25) : Derived.surfaceGlass,
        boxShadow: `inset 0 0 0 1px ${selected ? AppColors.softLavender : Derived.border}`,
        display: 'flex',
        alignItems: 'center',
        flexShrink: 0,
        overflow: 'hidden',
      }}
    >
      {hovered && (
        <span aria-hidden style={{ position: 'absolute', inset: 0, background: withAlpha(M3Scheme.onSurfaceVariant, 0.08) }} />
      )}
      {selected && (
        <svg width={14} height={14} viewBox="0 0 14 14" style={{ marginRight: 9, flexShrink: 0 }} aria-hidden>
          <path d="M2.1 6.3 L5.6 9.8 L11.9 3.5" fill="none" stroke={AppColors.petalWhite} strokeWidth={2} />
        </svg>
      )}
      <span style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), ...letterSpacing(0.1) }}>
        {label}
      </span>
    </button>
  );
}

function OnThisDayBanner({ facts }: { facts: MemoryFact[] }) {
  return (
    <div
      style={{
        margin: '8px 16px',
        padding: '13px 17px',
        borderRadius: AppRadius.lg,
        background: linear([withAlpha(AppColors.auroraGold, 0.18), withAlpha(AppColors.deepRose, 0.16)]),
        boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.auroraGold, 0.55)}`,
        display: 'flex',
        alignItems: 'center',
        flexShrink: 0,
      }}
    >
      <span style={{ fontSize: 18, lineHeight: lineHeight(18) }}>📌</span>
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...AppTypography.outfitHeading, fontSize: 13, lineHeight: lineHeight(13), color: AppColors.auroraGold }}>
          On This Day
        </div>
        <div style={{ height: 2 }} />
        <div className="clamp-2" style={{ ...AppTypography.outfitWhite, fontSize: 13, lineHeight: lineHeight(13) }}>
          {facts[0].fact}
        </div>
      </div>
      {facts.length > 1 && (
        <span style={{ ...AppTypography.outfitBold, fontSize: 14, lineHeight: lineHeight(14), color: AppColors.auroraGold }}>
          +{facts.length - 1}
        </span>
      )}
    </div>
  );
}

function MemoryCard({ fact, onPin, onDelete }: { fact: MemoryFact; onPin: () => void; onDelete: () => void }) {
  const occurred = fact.occurredAt;
  return (
    <div
      style={{
        padding: 17,
        borderRadius: AppRadius.lg,
        background: Derived.surfaceGlass,
        boxShadow: `inset 0 0 0 1px ${fact.pinned ? withAlpha(AppColors.auroraGold, 0.6) : Derived.border}`,
        display: 'flex',
        alignItems: 'flex-start',
      }}
    >
      <div
        style={{
          width: 34,
          height: 34,
          borderRadius: '50%',
          flexShrink: 0,
          background: fact.pinned ? withAlpha(AppColors.auroraGold, 0.18) : withAlpha(AppColors.softLavender, 0.14),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon
          name={fact.pinned ? 'push_pin' : 'spa_outlined'}
          size={17}
          color={fact.pinned ? AppColors.auroraGold : AppColors.softLavender}
        />
      </div>
      <div style={{ width: 12 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...AppTypography.outfitWhite, fontSize: 14, fontWeight: 600, lineHeight: lineHeight(14) }}>{fact.fact}</div>
        <div style={{ height: 8 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 8, rowGap: 4 }}>
          <Tag label={fact.category} />
          {fact.subject != null && <Tag label={fact.subject} />}
          {fact.object != null && <Tag label={fact.object} />}
          {occurred != null && <Tag label={`${occurred.getMonth() + 1}/${occurred.getDate()}`} />}
        </div>
      </div>
      <MaterialIconButton
        icon={fact.pinned ? 'push_pin' : 'push_pin_outlined'}
        size={18}
        tooltip={fact.pinned ? 'Unpin' : 'Pin'}
        color={fact.pinned ? AppColors.auroraGold : Derived.textMuted}
        onPressed={onPin}
      />
      <MaterialIconButton icon="delete_outline" size={18} tooltip="Forget" color={Derived.textMuted} onPressed={onDelete} />
    </div>
  );
}

function Tag({ label }: { label: string }) {
  return (
    <span
      style={{
        padding: '3px 9px',
        borderRadius: AppRadius.xs,
        background: withAlpha(AppColors.softLavender, 0.1),
        boxShadow: `inset 0 0 0 1px ${Derived.border}`,
        ...AppTypography.outfitMedium,
        fontSize: 10,
        lineHeight: lineHeight(10),
      }}
    >
      {label}
    </span>
  );
}

const CATEGORY_ITEMS = [
  { value: 'fact', label: 'Fact' },
  { value: 'preference', label: 'Preference' },
  { value: 'dislike', label: 'Dislike' },
  { value: 'goal', label: 'Goal' },
  { value: 'date', label: 'Date' },
  { value: 'habit', label: 'Habit' },
];

const toInputDate = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

function AddMemoryDialog({ close }: { close: (v: MemoryFact | null) => void }) {
  const [text, setText] = useState('');
  const [category, setCategory] = useState('fact');
  const [occurredAt, setOccurredAt] = useState<Date | null>(null);
  const dateInput = useRef<HTMLInputElement>(null);
  const clean = text.trim();
  const remember = () => {
    const [subject, relation, object] = parseFactStructure(clean);
    close({ ...memoryFactFromJson({ fact: clean, category }), subject, relation, object, occurredAt });
  };
  const pickDate = () => {
    const el = dateInput.current;
    if (!el) return;
    try {
      el.showPicker();
    } catch {
      el.focus();
    }
  };
  return (
    <AlertDialog
      background={AppColors.velvet}
      radius={AppRadius.x2}
      title={<span style={{ color: AppColors.petalWhite }}>New memory</span>}
      content={
        <div
          style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', width: 'min(312px, calc(100vw - 128px))' }}
        >
          <textarea
            autoFocus
            rows={3}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="e.g. Khent prefers black coffee"
            className="memory-search"
            style={{
              width: '100%',
              resize: 'none',
              padding: '8px 0',
              background: 'transparent',
              border: 0,
              borderBottom: `1px solid ${M3Scheme.outline}`,
              outline: 'none',
              ...AppTypography.outfitWhite,
              fontSize: 16,
              lineHeight: '24px',
              caretColor: AppColors.deepRose,
            }}
          />
          <div style={{ height: 12 }} />
          <div style={{ alignSelf: 'stretch' }}>
            <DropdownField label="" value={category} items={CATEGORY_ITEMS} onChanged={setCategory} />
          </div>
          <div style={{ height: 8 }} />
          <div style={{ position: 'relative' }}>
            <TextButton onPressed={pickDate} icon={<Icon name="event" size={18} color={AppColors.softLavender} />}>
              <span style={medium}>
                {occurredAt == null
                  ? 'Add a date (optional)'
                  : `${occurredAt.getMonth() + 1}/${occurredAt.getDate()}/${occurredAt.getFullYear()}`}
              </span>
            </TextButton>
            <input
              ref={dateInput}
              type="date"
              tabIndex={-1}
              aria-hidden
              min="2020-01-01"
              max={toInputDate(new Date())}
              value={occurredAt ? toInputDate(occurredAt) : ''}
              onChange={(e) => {
                const [y, m, d] = e.target.value.split('-').map(Number);
                if (y) setOccurredAt(new Date(y, m - 1, d));
              }}
              style={{ position: 'absolute', left: 0, bottom: 0, width: 1, height: 1, opacity: 0, pointerEvents: 'none' }}
            />
          </div>
        </div>
      }
      actions={[
        <TextButton key="cancel" onPressed={() => close(null)}>
          Cancel
        </TextButton>,
        <div key="remember" style={{ height: 48, display: 'flex', alignItems: 'center' }}>
          <button
            type="button"
            className="bare-button"
            disabled={clean === ''}
            onClick={remember}
            style={{
              height: 40,
              padding: '0 24px',
              borderRadius: 20,
              background: clean === '' ? withAlpha(M3Scheme.onSurface, 0.12) : AppColors.deepRose,
              ...AppTypography.labelLarge,
              lineHeight: lineHeight(14),
              color: clean === '' ? withAlpha(M3Scheme.onSurface, 0.38) : M3Scheme.onPrimary,
              cursor: clean === '' ? 'default' : 'pointer',
            }}
          >
            Remember
          </button>
        </div>,
      ]}
    />
  );
}
