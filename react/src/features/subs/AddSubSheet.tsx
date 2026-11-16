// Port of lib/features/subs/presentation/widgets/add_sub_sheet.dart.
import { useRef, useState, type CSSProperties } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppMotion, orZero } from '../../core/theme/motion';
import { linear, lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { subPayerHue } from './SubCard';
import { SubCycles, SubPayers, subsService, type SubCycle, type SubPayer, type Subscription } from './subsService';

const trimPrice = (p: number) => (p === Math.trunc(p) ? `${Math.trunc(p)}` : `${p}`);
const dateOnly = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
const toInputDate = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const monthDay = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' });

function Field({
  value,
  onChange,
  hint,
  prefix,
  numeric,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  prefix?: string;
  numeric?: boolean;
}) {
  const [focused, setFocused] = useState(false);
  return (
    <label
      style={{
        flex: 1,
        minWidth: 0,
        display: 'flex',
        alignItems: 'center',
        padding: '14px 16px',
        background: AppColors.twilight,
        borderRadius: AppRadius.md,
        boxShadow: `inset 0 0 0 ${focused ? 2 : 1}px ${focused ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.15)}`,
        cursor: 'text',
      }}
    >
      {prefix && <span style={{ ...AppTypography.outfitBold, fontSize: 15, color: AppColors.blushGold, whiteSpace: 'pre' }}>{prefix}</span>}
      <input
        value={value}
        placeholder={hint}
        inputMode={numeric ? 'decimal' : 'text'}
        autoCapitalize={numeric ? undefined : 'words'}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        onChange={(e) => onChange(numeric ? e.target.value.replace(/[^0-9.,]/g, '') : e.target.value)}
        className="money-input"
        style={
          {
            ...AppTypography.outfitWhite,
            fontSize: 15,
            flex: 1,
            minWidth: 0,
            background: 'transparent',
            border: 'none',
            outline: 'none',
            padding: 0,
            caretColor: AppColors.deepRose,
            '--hint-color': withAlpha(AppColors.petalWhite, 0.35),
            '--hint-size': '14px',
          } as CSSProperties
        }
      />
    </label>
  );
}

const sectionLabel: CSSProperties = {
  ...AppTypography.outfitBold,
  fontSize: 10,
  letterSpacing: 1.4,
  lineHeight: lineHeight(10),
  color: withAlpha(AppColors.petalWhite, 0.5),
};

function ChoicePill({ label, dot, hue, selected, onTap }: { label: string; dot?: string; hue: string; selected: boolean; onTap: () => void }) {
  const t = `${orZero(AppMotion.fast)}ms linear`;
  return (
    <button
      type="button"
      className="bare-button"
      aria-pressed={selected}
      aria-label={label}
      onClick={onTap}
      style={{
        padding: '10px 16px',
        background: selected ? withAlpha(hue, 0.16) : withAlpha(AppColors.moonlight, 0.05),
        borderRadius: AppRadius.full,
        border: `1px solid ${selected ? withAlpha(hue, 0.6) : withAlpha(AppColors.moonlight, 0.12)}`,
        transition: `background ${t}, border-color ${t}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      {dot && (
        <>
          <div style={{ width: 8, height: 8, borderRadius: '50%', background: dot }} />
          <div style={{ width: 7 }} />
        </>
      )}
      <span style={{ ...AppTypography.outfitBold, fontSize: 12, lineHeight: lineHeight(12), color: selected ? hue : withAlpha(AppColors.petalWhite, 0.6) }}>
        {label}
      </span>
    </button>
  );
}

export function AddSubSheet({ createdBy, existing, close }: { createdBy: string; existing: Subscription | null; close: () => void }) {
  const [name, setName] = useState(existing?.name ?? '');
  const [price, setPrice] = useState(existing ? trimPrice(existing.price) : '');
  const [cycle, setCycle] = useState<SubCycle>(existing?.cycle ?? 'monthly');
  const [payer, setPayer] = useState<SubPayer>(existing?.payer ?? 'shared');
  const [renewalDate, setRenewalDate] = useState<Date | null>(existing?.renewalDate ?? null);
  const [saving, setSaving] = useState(false);
  const dateInput = useRef<HTMLInputElement>(null);
  const editing = existing != null;

  const parsePrice = () => {
    const v = Number.parseFloat(price.trim().replaceAll(',', ''));
    return Number.isFinite(v) && v > 0 ? v : null;
  };
  const canSave = name.trim() !== '' && parsePrice() != null && renewalDate != null;

  const save = async () => {
    const n = name.trim();
    const p = parsePrice();
    if (n === '' || p == null || renewalDate == null || saving) return;
    setSaving(true);
    try {
      if (existing) {
        await subsService.update({ ...existing, name: n, price: p, renewalDate, cycle, payer }, existing);
      } else {
        await subsService.add({ name: n, price: p, renewalDate, cycle, payer, createdBy, createdAt: new Date() });
      }
      close();
    } catch {
      setSaving(false);
      showSnackBar('Could not save. Your details are still here — try again.');
    }
  };

  const remove = async () => {
    if (!existing || saving) return;
    setSaving(true);
    try {
      await subsService.delete(existing.id);
      close();
    } catch {
      setSaving(false);
      showSnackBar('Could not remove this subscription. Try again.');
    }
  };

  const today = dateOnly(new Date());
  const first = new Date(today.getTime() - 366 * 86_400_000);
  const last = new Date(today.getTime() + 366 * 3 * 86_400_000);
  const pickDate = () => {
    const el = dateInput.current;
    if (!el) return;
    try {
      el.showPicker();
    } catch {
      el.focus();
    }
  };

  const active = canSave && !saving;
  return (
    <div style={{ display: 'flex', justifyContent: 'center' }}>
      <div
        className="no-scrollbar"
        style={{
          width: '100%',
          maxWidth: 560,
          maxHeight: '92vh',
          overflowY: 'auto',
          padding: '12px 24px calc(24px + env(keyboard-inset-height, 0px))',
          background: AppColors.velvet,
          borderRadius: `${AppRadius.x3}px ${AppRadius.x3}px 0 0`,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
          boxSizing: 'border-box',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div style={{ alignSelf: 'center', width: 40, height: 4, marginBottom: 16, borderRadius: 999, background: withAlpha(AppColors.petalWhite, 0.3) }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
            <div style={{ ...AppTypography.cormorantBold, fontSize: 26, lineHeight: '26px' }}>
              {editing ? 'Edit subscription 💳' : 'New subscription 💳'}
            </div>
            <div style={{ height: 4 }} />
            <div style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12), color: withAlpha(AppColors.petalWhite, 0.55) }}>
              Netflix, Spotify, iCloud — all in pesos
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
              borderRadius: '50%',
              background: withAlpha(AppColors.moonlight, 0.07),
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxSizing: 'border-box',
            }}
          >
            <Icon name="close" size={18} color={withAlpha(AppColors.petalWhite, 0.7)} />
          </button>
        </div>
        <div style={{ height: 18 }} />
        <div style={{ display: 'flex' }}>
          <Field value={name} onChange={setName} hint="Name — Netflix, Spotify…" />
        </div>
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <Field value={price} onChange={setPrice} hint="Price — 549" prefix="₱ " numeric />
          <div style={{ width: 10 }} />
          <div style={{ position: 'relative' }}>
            <button
              type="button"
              className="bare-button"
              onClick={pickDate}
              style={{
                padding: 14,
                background: renewalDate == null ? AppColors.twilight : withAlpha(AppColors.deepRose, 0.2),
                borderRadius: AppRadius.md,
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.25)}`,
                display: 'flex',
                alignItems: 'center',
              }}
            >
              <Icon name="calendar_today" size={14} color={AppColors.blushGold} />
              <div style={{ width: 7 }} />
              <span style={{ ...AppTypography.outfitBold, fontSize: 13, lineHeight: lineHeight(13), color: AppColors.petalWhite }}>
                {renewalDate == null ? 'Renews…' : monthDay.format(renewalDate)}
              </span>
            </button>
            <input
              ref={dateInput}
              type="date"
              tabIndex={-1}
              aria-hidden
              min={toInputDate(first)}
              max={toInputDate(last)}
              value={toInputDate(renewalDate ?? today)}
              onChange={(e) => {
                const [y, m, d] = e.target.value.split('-').map(Number);
                if (y && m && d) setRenewalDate(new Date(y, m - 1, d));
              }}
              style={{ position: 'absolute', inset: 0, opacity: 0, pointerEvents: 'none' }}
            />
          </div>
        </div>
        <div style={{ height: 18 }} />
        <div style={sectionLabel}>BILLS EVERY</div>
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 8 }}>
          {SubCycles.map((c) => (
            <ChoicePill key={c.id} label={c.displayName} hue={AppColors.blushGold} selected={cycle === c.id} onTap={() => setCycle(c.id)} />
          ))}
        </div>
        <div style={{ height: 18 }} />
        <div style={sectionLabel}>WHO PAYS?</div>
        <div style={{ height: 10 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', columnGap: 8 }}>
          {SubPayers.map((p) => (
            <ChoicePill
              key={p.id}
              label={p.displayName}
              dot={subPayerHue(p.id)}
              hue={subPayerHue(p.id)}
              selected={payer === p.id}
              onTap={() => setPayer(p.id)}
            />
          ))}
        </div>
        <div style={{ height: 22 }} />
        <button
          type="button"
          className="bare-button"
          aria-label={editing ? 'Save changes' : 'Add subscription'}
          disabled={!active}
          onClick={save}
          style={{
            width: '100%',
            padding: '15px 0',
            background: active ? linear([AppColors.deepRose, AppColors.rosePressed]) : withAlpha(AppColors.moonlight, 0.06),
            borderRadius: AppRadius.lg,
            border: `1px solid ${active ? withAlpha(AppColors.blushGold, 0.35) : withAlpha(AppColors.moonlight, 0.1)}`,
            display: 'flex',
            justifyContent: 'center',
          }}
        >
          {saving ? (
            <CircularProgress size={20} strokeWidth={2} color={AppColors.petalWhite} />
          ) : (
            <span
              style={{
                ...AppTypography.outfitBold,
                fontSize: 14,
                lineHeight: lineHeight(14),
                color: canSave ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.4),
              }}
            >
              {editing ? 'Save changes 💾' : 'Track it 💳'}
            </span>
          )}
        </button>
        {editing && (
          <>
            <div style={{ height: 10 }} />
            <button
              type="button"
              className="bare-button"
              aria-label="Delete subscription"
              disabled={saving}
              onClick={remove}
              style={{
                width: '100%',
                padding: '13px 0',
                background: withAlpha(AppColors.error, 0.08),
                borderRadius: AppRadius.lg,
                border: `1px solid ${withAlpha(AppColors.error, 0.3)}`,
                display: 'flex',
                justifyContent: 'center',
              }}
            >
              <span style={{ ...AppTypography.outfitBold, fontSize: 13, lineHeight: lineHeight(13), color: AppColors.error }}>Stop tracking</span>
            </button>
          </>
        )}
      </div>
    </div>
  );
}
