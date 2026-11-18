// Port of lib/features/money/presentation/widgets/add_money_dialog.dart.
import { useState, type CSSProperties } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { DialogPanel, showDialog } from '../../shared/widgets/Dialogs';
import { EverglowButton } from '../../shared/widgets/EverglowButton';
import { EverglowSegmentedControl } from '../../shared/widgets/EverglowSegmentedControl';
import { Icon } from '../../shared/widgets/Icon';
import { MoneyCategories, type MoneyType } from './moneyService';

export type MoneyDraft = { type: MoneyType; amount: number; category: string; note: string };

const parseAmount = (text: string) => Number.parseFloat(text.replaceAll(',', '')) || 0;
const onlyAmountChars = (text: string) => text.replace(/[^0-9.,]/g, '');

const title = (size: number): CSSProperties => ({
  ...AppTypography.cormorantBold,
  fontSize: size,
  lineHeight: lineHeight(size),
  color: AppColors.petalWhite,
});
const subtitle: CSSProperties = { ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: Derived.textMuted };
const errorText: CSSProperties = { fontSize: 14, color: AppColors.error };

function OutlinedField({
  value,
  onChange,
  onSubmit,
  fontSize,
  prefix,
  hint,
  hintStyle,
  numeric,
  autoFocus,
  textStyle,
}: {
  value: string;
  onChange: (v: string) => void;
  onSubmit: () => void;
  fontSize: number;
  prefix?: string;
  hint: string;
  hintStyle?: CSSProperties;
  numeric?: boolean;
  autoFocus?: boolean;
  textStyle: CSSProperties;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <label
      style={{
        display: 'flex',
        alignItems: 'baseline',
        padding: '20px 12px 12px',
        background: withAlpha(AppColors.inkDeep, 0.5),
        borderRadius: AppRadius.lg,
        boxShadow: `inset 0 0 0 ${focused ? 2 : 1}px ${focused ? AppColors.blushGold : Derived.border}`,
        cursor: 'text',
      }}
    >
      {prefix && (
        <span style={{ ...AppTypography.outfitWhite, fontSize, color: AppColors.blushGold, whiteSpace: 'pre' }}>{prefix}</span>
      )}
      <input
        value={value}
        autoFocus={autoFocus}
        inputMode={numeric ? 'decimal' : 'text'}
        autoCapitalize={numeric ? undefined : 'sentences'}
        placeholder={hint}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        onChange={(e) => onChange(numeric ? onlyAmountChars(e.target.value) : e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && onSubmit()}
        className="money-input"
        style={
          {
            ...textStyle,
            flex: 1,
            minWidth: 0,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            padding: 0,
            caretColor: AppColors.deepRose,
            '--hint-color': hintStyle?.color ?? Derived.textDisabled,
            '--hint-size': `${hintStyle?.fontSize ?? fontSize}px`,
          } as CSSProperties
        }
      />
    </label>
  );
}

function ChoiceChip({ label, selected, onSelected }: { label: string; selected: boolean; onSelected: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-pressed={selected}
      onClick={onSelected}
      style={{
        height: 32,
        padding: selected ? '0 16px 0 8px' : '0 16px',
        borderRadius: AppRadius.full,
        background: selected ? withAlpha(AppColors.deepRose, 0.35) : withAlpha(AppColors.moonlight, 0.08),
        boxShadow: `inset 0 0 0 1px ${selected ? AppColors.auroraRose : Derived.border}`,
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        ...AppTypography.bodySmall,
        lineHeight: lineHeight(12.5),
        color: selected ? AppColors.petalWhite : Derived.textMedium,
      }}
    >
      {selected && <Icon name="check" size={18} color={AppColors.petalWhite} />}
      {label}
    </button>
  );
}

function AddMoneyDialog({ onSave, close }: { onSave?: (d: MoneyDraft) => Promise<void>; close: (d: MoneyDraft | null) => void }) {
  const [type, setType] = useState<MoneyType>('expense');
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [category, setCategory] = useState('Food');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const categories = type === 'expense' ? MoneyCategories.expense : MoneyCategories.income;

  const save = async () => {
    if (saving) return;
    const value = parseAmount(amount);
    if (value <= 0) return;
    const draft: MoneyDraft = { type, amount: value, category, note: note.trim() };
    setSaving(true);
    setError(null);
    try {
      await onSave?.(draft);
      close(draft);
    } catch {
      setSaving(false);
      setError('Could not save. Your entry is still here — try again.');
    }
  };

  return (
    <DialogPanel background={AppColors.velvet} radius={AppRadius.xl} border={false}>
      <div style={{ padding: 20, display: 'flex', flexDirection: 'column' }}>
        <div style={title(24)}>Add money</div>
        <div style={{ height: 4 }} />
        <div style={subtitle}>one shared wallet for us</div>
        <div style={{ height: 16 }} />
        <EverglowSegmentedControl
          selectedIndex={type === 'expense' ? 0 : 1}
          onChanged={(i) => {
            const next: MoneyType = i === 0 ? 'expense' : 'income';
            setType(next);
            setCategory((next === 'expense' ? MoneyCategories.expense : MoneyCategories.income)[0]);
          }}
          items={[
            { label: 'Spent', icon: 'arrow_upward' },
            { label: 'Got', icon: 'arrow_downward' },
          ]}
        />
        <div style={{ height: 16 }} />
        <OutlinedField
          value={amount}
          onChange={setAmount}
          onSubmit={save}
          fontSize={28}
          prefix="₱ "
          hint="0"
          numeric
          autoFocus
          textStyle={{ ...AppTypography.outfitWhite, fontSize: 28 }}
        />
        <div style={{ height: 14 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {categories.map((c) => (
            <ChoiceChip
              key={c}
              label={`${MoneyCategories.iconFor(c)} ${c}`}
              selected={category === c}
              onSelected={() => setCategory(c)}
            />
          ))}
        </div>
        <div style={{ height: 14 }} />
        <OutlinedField
          value={note}
          onChange={setNote}
          onSubmit={save}
          fontSize={14}
          hint="Note (optional) — e.g. milk tea with Clair"
          hintStyle={{ fontSize: 12.5, color: Derived.textDisabled }}
          textStyle={{ ...AppTypography.bodyMedium }}
        />
        <div style={{ height: 18 }} />
        {error != null && <div style={errorText}>{error}</div>}
        <EverglowButton
          enabled={!saving}
          label={type === 'expense' ? 'Log spending' : 'Log income'}
          icon="check"
          onPressed={save}
          fullWidth
        />
      </div>
    </DialogPanel>
  );
}

export function showAddMoneyDialog(onSave?: (d: MoneyDraft) => Promise<void>) {
  return showDialog<MoneyDraft>((close) => <AddMoneyDialog onSave={onSave} close={close} />);
}

function SetBudgetDialog({
  category,
  current,
  onSave,
  close,
}: {
  category: string;
  current: number;
  onSave?: (amount: number) => Promise<void>;
  close: (v: number | null) => void;
}) {
  const [text, setText] = useState(current > 0 ? current.toFixed(0) : '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const save = async () => {
    if (saving) return;
    const amount = parseAmount(text);
    setSaving(true);
    setError(null);
    try {
      await onSave?.(amount);
      close(amount);
    } catch {
      setSaving(false);
      setError('Could not save this budget. Try again.');
    }
  };
  return (
    <DialogPanel background={AppColors.velvet} radius={AppRadius.xl} border={false}>
      <div style={{ padding: 20, display: 'flex', flexDirection: 'column' }}>
        <div style={title(22)}>{`${MoneyCategories.iconFor(category)} ${category} budget`}</div>
        <div style={{ height: 4 }} />
        <div style={subtitle}>monthly cap — 0 removes it</div>
        <div style={{ height: 14 }} />
        <OutlinedField
          value={text}
          onChange={setText}
          onSubmit={save}
          fontSize={24}
          prefix="₱ "
          hint="0"
          numeric
          autoFocus
          textStyle={{ ...AppTypography.outfitWhite, fontSize: 24 }}
        />
        <div style={{ height: 16 }} />
        {error != null && <div style={errorText}>{error}</div>}
        <EverglowButton enabled={!saving} label="Save budget" icon="savings" onPressed={save} fullWidth />
      </div>
    </DialogPanel>
  );
}

export function showSetBudgetDialog(category: string, opts: { current?: number; onSave?: (amount: number) => Promise<void> } = {}) {
  return showDialog<number>((close) => (
    <SetBudgetDialog category={category} current={opts.current ?? 0} onSave={opts.onSave} close={close} />
  ));
}
