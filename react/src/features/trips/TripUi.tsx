// Port of lib/features/trip_kit/presentation/widgets/trip_ui.dart.
import type { CSSProperties } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';

/** A collapsed TextField (bodyLarge-based: height 1.5, letterSpacing 0.5) with a 0.35 hint. */
export function TripInput({
  value,
  onChange,
  hint,
  numeric,
  rows = 1,
  onSubmit,
  style,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  numeric?: boolean;
  rows?: number;
  onSubmit?: () => void;
  style?: CSSProperties;
}) {
  const common = {
    ...AppTypography.outfitWhite,
    fontSize: 14,
    lineHeight: '21px',
    letterSpacing: 0.5,
    width: '100%',
    textOverflow: 'ellipsis',
    minWidth: 0,
    display: 'block',
    background: 'transparent',
    border: 'none',
    outline: 'none',
    padding: 0,
    margin: 0,
    caretColor: AppColors.deepRose,
    '--hint-color': withAlpha(AppColors.petalWhite, 0.35),
    '--hint-size': '14px',
    ...style,
  } as CSSProperties;
  if (rows > 1)
    return (
      <textarea
        value={value}
        placeholder={hint}
        rows={rows}
        onChange={(e) => onChange(e.target.value)}
        className="money-input no-scrollbar"
        style={{ ...common, height: rows * 21, resize: 'none' }}
      />
    );
  return (
    <input
      value={value}
      placeholder={hint}
      inputMode={numeric ? 'decimal' : 'text'}
      enterKeyHint="done"
      onChange={(e) => onChange(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === 'Enter') onSubmit?.();
      }}
      className="money-input"
      style={{ ...common, height: 21 }}
    />
  );
}

export function TripSectionTitle({
  icon,
  title,
  trailing,
  hue,
}: {
  icon: string;
  title: string;
  trailing?: string | null;
  hue: string;
}) {
  return (
    <div style={{ padding: '20px 4px 10px', display: 'flex', alignItems: 'center' }}>
      <Icon name={icon} size={16} color={hue} />
      <div style={{ width: 8 }} />
      <span
        style={{ ...AppTypography.outfitBold, fontSize: 13, letterSpacing: 1.2, color: withAlpha(AppColors.petalWhite, 0.85) }}
      >
        {title}
      </span>
      <div style={{ flex: 1 }} />
      {trailing != null && <span style={{ ...AppTypography.outfitBold, fontSize: 12, color: hue }}>{trailing}</span>}
    </div>
  );
}

export function TripCheckRow({
  label,
  subtitle,
  checked,
  hue,
  onToggle,
  onDelete,
  toggleLabel,
}: {
  label: string;
  subtitle?: string | null;
  checked: boolean;
  hue: string;
  onToggle: () => void;
  onDelete: () => void;
  toggleLabel: string;
}) {
  return (
    <div style={{ paddingBottom: 8 }}>
      <div
        style={{
          background: withAlpha(AppColors.moonlight, 0.05),
          borderRadius: AppRadius.lg,
          border: `1px solid ${checked ? withAlpha(hue, 0.35) : withAlpha(AppColors.moonlight, 0.1)}`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <button
          type="button"
          className="bare-button"
          aria-pressed={checked}
          aria-label={toggleLabel}
          onClick={onToggle}
          style={{ padding: '12px 4px 12px 12px', display: 'flex' }}
        >
          <div
            style={{
              width: 22,
              height: 22,
              boxSizing: 'border-box',
              borderRadius: '50%',
              background: checked ? hue : 'transparent',
              boxShadow: `inset 0 0 0 1.6px ${checked ? hue : withAlpha(AppColors.petalWhite, 0.35)}`,
              transition: 'background 180ms linear, box-shadow 180ms linear',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            {checked && <Icon name="check" size={14} color={AppColors.inkDeep} />}
          </div>
        </button>
        <div
          role="presentation"
          onClick={onToggle}
          style={{ flex: 1, minWidth: 0, padding: '12px 0', cursor: 'pointer', display: 'flex', flexDirection: 'column' }}
        >
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 14,
              textDecoration: checked ? 'line-through' : undefined,
              textDecorationColor: withAlpha(AppColors.petalWhite, 0.5),
              color: checked ? withAlpha(AppColors.petalWhite, 0.45) : AppColors.petalWhite,
            }}
          >
            {label}
          </span>
          {subtitle != null && subtitle !== '' && (
            <span
              style={{ ...AppTypography.outfitWhite, fontSize: 12, marginTop: 2, color: withAlpha(AppColors.petalWhite, 0.55) }}
            >
              {subtitle}
            </span>
          )}
        </div>
        <button
          type="button"
          className="bare-button"
          aria-label="Remove"
          title="Remove"
          onClick={onDelete}
          style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
        >
          <Icon name="close" size={16} color={withAlpha(AppColors.petalWhite, 0.35)} />
        </button>
      </div>
    </div>
  );
}

function AddField({
  value,
  onChange,
  hint,
  numeric,
  onSubmit,
  flex,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  numeric?: boolean;
  onSubmit: () => void;
  flex: number;
}) {
  return (
    <div
      style={{
        flex: `${flex} 1 0`,
        minWidth: 0,
        height: 44,
        boxSizing: 'border-box',
        padding: '0 14px',
        background: withAlpha(AppColors.moonlight, 0.06),
        borderRadius: AppRadius.lg,
        border: `1px solid ${withAlpha(AppColors.moonlight, 0.12)}`,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <TripInput value={value} onChange={onChange} hint={hint} numeric={numeric} onSubmit={onSubmit} />
    </div>
  );
}

export function TripAddRow({
  value,
  onChange,
  hint,
  onAdd,
  hue,
  second,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  onAdd: () => void;
  hue: string;
  second?: { value: string; onChange: (v: string) => void; hint: string; numeric?: boolean };
}) {
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <AddField value={value} onChange={onChange} hint={hint} onSubmit={onAdd} flex={3} />
      {second && (
        <>
          <div style={{ width: 8 }} />
          <AddField
            value={second.value}
            onChange={second.onChange}
            hint={second.hint}
            numeric={second.numeric}
            onSubmit={onAdd}
            flex={2}
          />
        </>
      )}
      <div style={{ width: 8 }} />
      <button
        type="button"
        className="bare-button"
        aria-label={`Add ${hint}`}
        onClick={onAdd}
        style={{
          width: 44,
          height: 44,
          boxSizing: 'border-box',
          borderRadius: '50%',
          background: withAlpha(hue, 0.16),
          border: `1px solid ${withAlpha(hue, 0.5)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon name="add" size={20} color={hue} />
      </button>
    </div>
  );
}

export function TripProgress({ value, height, color }: { value: number; height: number; color: string }) {
  return (
    <div style={{ height, borderRadius: 999, overflow: 'hidden', background: withAlpha(AppColors.moonlight, 0.1) }}>
      <div style={{ width: `${value * 100}%`, height: '100%', background: color }} />
    </div>
  );
}
