// Plain Material 3 widgets as the app theme draws them: AppBar,
// DropdownButtonFormField (underline), Switch and SwitchListTile.
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { AppColors, Derived, M3Scheme, withAlpha } from '../../core/theme/colors';
import { letterSpacing, lineHeight } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { Icon } from './Icon';
import { Tooltip } from './Tooltip';

export const canPop = () => ((window.history.state as { idx?: number } | null)?.idx ?? 0) > 0;

/** `AppBar(title: Text(title))`: 56 tall, titleLarge in petalWhite, a back arrow when the route can pop. */
export function MaterialAppBar({ title, actions }: { title: string; actions?: ReactNode }) {
  const navigate = useNavigate();
  const back = canPop();
  return (
    <div style={{ height: 56, display: 'flex', alignItems: 'center', flexShrink: 0 }}>
      {back && (
        <button
          type="button"
          className="bare-button"
          aria-label="Back"
          onClick={() => navigate(-1)}
          style={{ width: 56, height: 56, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <Icon name="arrow_back" variant="filled" color={AppColors.petalWhite} />
        </button>
      )}
      <div
        style={{
          ...AppTypography.titleLarge,
          color: AppColors.petalWhite,
          lineHeight: lineHeight(22),
          paddingLeft: 16,
          flex: 1,
          minWidth: 0,
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}
      >
        {title}
      </div>
      {actions}
    </div>
  );
}

export type DropdownItem<T> = { value: T; label: string };

/** `DropdownButtonFormField` with a floating label and the default underline. */
export function DropdownField<T>({
  label,
  value,
  items,
  onChanged,
  menuColor,
}: {
  label: string;
  value: T;
  items: DropdownItem<T>[];
  onChanged?: (value: T) => void;
  /** dropdownColor (the menu's fill). */ menuColor?: string;
}) {
  const [open, setOpen] = useState(false);
  const enabled = onChanged != null;
  const current = items.find((i) => i.value === value);
  return (
    <div style={{ position: 'relative', height: 56 }}>
      <button
        type="button"
        className="bare-button"
        disabled={!enabled}
        onClick={() => setOpen(true)}
        aria-haspopup="listbox"
        aria-label={`${label}: ${current?.label ?? ''}`}
        style={{ position: 'absolute', inset: 0, cursor: enabled ? 'pointer' : 'default' }}
      >
        <div
          style={{
            position: 'absolute',
            top: 6,
            left: 0,
            fontFamily: Fonts.body,
            fontWeight: 500,
            fontSize: 12,
            lineHeight: '16px',
            color: M3Scheme.onSurfaceVariant,
          }}
        >
          {label}
        </div>
        <div
          style={{
            position: 'absolute',
            top: 23.5,
            left: 0,
            right: 24,
            ...AppTypography.titleMedium,
            lineHeight: '24px',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            color: enabled ? AppColors.petalWhite : Derived.textDisabled,
          }}
        >
          <span style={letterSpacing(0.15)}>{current?.label}</span>
        </div>
        <div style={{ position: 'absolute', right: 0, top: 16 }}>
          <Icon name="arrow_drop_down" variant="filled" color={M3Scheme.white70} />
        </div>
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 1, background: M3Scheme.outline }} />
      </button>
      {open && (
        <DropdownMenu
          items={items}
          value={value}
          color={menuColor}
          onClose={() => setOpen(false)}
          onPick={(v) => {
            setOpen(false);
            onChanged?.(v);
          }}
        />
      )}
    </div>
  );
}

function DropdownMenu<T>({
  items,
  value,
  onPick,
  onClose,
  color = AppColors.twilight,
}: {
  items: DropdownItem<T>[];
  value: T;
  color?: string;
  onPick: (v: T) => void;
  onClose: () => void;
}) {
  const list = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const index = items.findIndex((i) => i.value === value);
    if (list.current && index > 0) list.current.scrollTop = Math.max(0, index * 48 - 96);
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [items, value, onClose]);
  return (
    <>
      <div style={{ position: 'fixed', inset: 0, zIndex: 50 }} onClick={onClose} />
      <div
        ref={list}
        role="listbox"
        style={{
          position: 'absolute',
          left: -16,
          right: -16,
          top: 0,
          zIndex: 51,
          maxHeight: 48 * 6 + 16,
          overflowY: 'auto',
          padding: '8px 0',
          background: color,
          borderRadius: 4,
          boxShadow: '0 5px 5px -3px rgba(0,0,0,.2), 0 8px 10px 1px rgba(0,0,0,.14), 0 3px 14px 2px rgba(0,0,0,.12)',
        }}
      >
        {items.map((item) => (
          <MenuItem key={String(item.value)} selected={item.value === value} onClick={() => onPick(item.value)}>
            {item.label}
          </MenuItem>
        ))}
      </div>
    </>
  );
}

function MenuItem({ selected, onClick, children }: { selected: boolean; onClick: () => void; children: ReactNode }) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      role="option"
      aria-selected={selected}
      className="bare-button"
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        height: 48,
        width: '100%',
        padding: '0 16px',
        display: 'flex',
        alignItems: 'center',
        ...AppTypography.titleMedium,
        background: selected || hovered ? withAlpha(AppColors.petalWhite, selected ? 0.12 : 0.08) : 'transparent',
      }}
    >
      {children}
    </button>
  );
}

/** Material 3 `Switch` with the app theme's thumb and track colours, in its 60x48 tap box. */
export function MaterialSwitch({
  value,
  onChanged,
  activeThumbColor = AppColors.petalWhite,
}: {
  value: boolean;
  onChanged?: (v: boolean) => void;
  activeThumbColor?: string;
}) {
  const thumb = value ? 24 : 16;
  return (
    <button
      type="button"
      role="switch"
      aria-checked={value}
      className="bare-button"
      disabled={!onChanged}
      onClick={() => onChanged?.(!value)}
      style={{ width: 60, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
    >
      <span
        style={{
          position: 'relative',
          width: 52,
          height: 32,
          borderRadius: 16,
          background: value ? AppColors.deepRose : withAlpha(AppColors.moonlight, 0.16),
          opacity: onChanged ? 1 : 0.38,
          transition: 'background 200ms linear',
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 16 - thumb / 2,
            left: (value ? 36 : 16) - thumb / 2,
            width: thumb,
            height: thumb,
            borderRadius: '50%',
            background: value ? activeThumbColor : Derived.textDisabled,
            transition: 'all 200ms cubic-bezier(0.2, 0, 0, 1)',
          }}
        />
      </span>
    </button>
  );
}

/** `SwitchListTile(contentPadding: zero, title, subtitle)`: a 72px two-line tile with the switch trailing. */
export function SwitchListTile({
  title,
  subtitle,
  value,
  onChanged,
  activeThumbColor,
}: {
  title: string;
  subtitle?: string;
  value: boolean;
  onChanged?: (v: boolean) => void;
  activeThumbColor?: string;
}) {
  return (
    <div
      onClick={() => onChanged?.(!value)}
      style={{
        minHeight: subtitle ? 72 : 56,
        display: 'flex',
        alignItems: 'center',
        cursor: onChanged ? 'pointer' : 'default',
      }}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...AppTypography.bodyLarge, ...letterSpacing(0.5), color: M3Scheme.onSurface, lineHeight: '24px' }}>
          {title}
        </div>
        {subtitle && (
          <div style={{ ...AppTypography.bodyMedium, color: M3Scheme.onSurfaceVariant, lineHeight: lineHeight(14) }}>
            {subtitle}
          </div>
        )}
      </div>
      <div onClick={(e) => e.stopPropagation()}>
        <MaterialSwitch value={value} onChanged={onChanged} activeThumbColor={activeThumbColor} />
      </div>
    </div>
  );
}

/** Material 3 `IconButton`: a 40px circle in its 48px tap slot, an 8% hover wash of the icon colour. */
export function MaterialIconButton({
  icon,
  tooltip,
  color = AppColors.petalWhite,
  size = 24,
  onPressed,
  children,
}: {
  icon?: string;
  tooltip?: string;
  color?: string;
  size?: number;
  onPressed?: () => void;
  children?: ReactNode;
}) {
  const [hovered, setHovered] = useState(false);
  const enabled = onPressed != null;
  const button = (
    <div style={{ width: 48, height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <button
        type="button"
        className="bare-button"
        aria-label={tooltip}
        disabled={!enabled}
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: hovered && enabled ? withAlpha(color, 0.08) : 'transparent',
          opacity: enabled ? 1 : 0.38,
          cursor: enabled ? 'pointer' : 'default',
        }}
      >
        {children ?? <Icon name={icon!} size={size} color={color} />}
      </button>
    </div>
  );
  return tooltip ? <Tooltip message={tooltip}>{button}</Tooltip> : button;
}

/** Material 3 `FilledButton` / `FilledButton.icon`: 40 tall, primary fill, labelLarge in onPrimary. */
export function FilledButton({
  icon,
  label,
  onPressed,
  stretch = false,
}: {
  icon?: string;
  label: string;
  onPressed?: () => void;
  stretch?: boolean;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <div style={{ height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <button
        type="button"
        className="bare-button"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: stretch ? '100%' : undefined,
          height: 40,
          padding: icon ? '0 24px 0 16px' : '0 24px',
          borderRadius: 20,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 8,
          background: AppColors.deepRose,
          boxShadow: hovered ? '0 1px 2px rgba(0,0,0,.3), 0 1px 3px 1px rgba(0,0,0,.15)' : undefined,
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {hovered && (
          <span aria-hidden style={{ position: 'absolute', inset: 0, background: withAlpha(M3Scheme.onPrimary, 0.08) }} />
        )}
        {icon && <Icon name={icon} size={18} color={M3Scheme.onPrimary} />}
        <span style={{ ...AppTypography.labelLarge, lineHeight: lineHeight(14), color: M3Scheme.onPrimary }}>{label}</span>
      </button>
    </div>
  );
}

/** Material 3 ExpansionTile: a ListTile (two-line when there is a subtitle) that opens its children below. */
export function ExpansionTile({ title, subtitle, children }: { title: string; subtitle?: string; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const [hovered, setHovered] = useState(false);
  const line = open ? M3Scheme.outline : 'transparent';
  return (
    <div style={{ padding: '1px 0', boxShadow: `inset 0 1px 0 ${line}, inset 0 -1px 0 ${line}`, transition: 'box-shadow 200ms' }}>
      <button
        type="button"
        className="bare-button"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          position: 'relative',
          width: '100%',
          height: subtitle ? 72 : 56,
          padding: `0 24px ${subtitle ? 2 : 0}px 16px`,
          display: 'flex',
          alignItems: 'center',
          textAlign: 'left',
          background: hovered ? withAlpha(M3Scheme.onSurface, 0.08) : 'transparent',
        }}
      >
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              ...AppTypography.bodyLarge,
              color: M3Scheme.onSurface,
              lineHeight: lineHeight(16, 1.5),
              ...letterSpacing(0.5),
            }}
          >
            {title}
          </div>
          {subtitle && <div style={{ ...AppTypography.bodyMedium, color: M3Scheme.onSurface }}>{subtitle}</div>}
        </div>
        <div style={{ width: 16 }} />
        <span style={{ display: 'flex', transform: `rotate(${open ? 180 : 0}deg)`, transition: 'transform 200ms ease-in' }}>
          <Icon name="expand_more" variant="filled" size={24} color={open ? AppColors.deepRose : M3Scheme.onSurfaceVariant} />
        </span>
      </button>
      <div style={{ display: 'grid', gridTemplateRows: open ? '1fr' : '0fr', transition: 'grid-template-rows 200ms ease-in' }}>
        <div style={{ overflow: 'hidden' }}>{open && children}</div>
      </div>
    </div>
  );
}

/** `TextField(decoration: InputDecoration(labelText, prefixIcon, suffixIcon))`: the M3 underline field. */
export function UnderlineTextField({
  label,
  value,
  onChange,
  prefixIcon,
  suffix,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  prefixIcon?: string;
  suffix?: ReactNode;
}) {
  const [focused, setFocused] = useState(false);
  const floating = focused || value.length > 0;
  const accent = focused ? AppColors.deepRose : M3Scheme.onSurfaceVariant;
  const left = prefixIcon ? 52 : 0;
  return (
    <label style={{ position: 'relative', display: 'block', height: 56, cursor: 'text' }}>
      {prefixIcon && (
        <div
          style={{
            position: 'absolute',
            left: 0,
            top: 4,
            width: 48,
            height: 48,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={prefixIcon} size={24} color={accent} />
        </div>
      )}
      <div
        style={{
          ...letterSpacing(floating ? 0.4 : 0.5),
          position: 'absolute',
          left,
          top: floating ? 6 : 16,
          fontFamily: Fonts.body,
          fontWeight: 500,
          fontSize: floating ? 12 : 16,
          lineHeight: floating ? '16px' : '24px',
          color: accent,
          pointerEvents: 'none',
          transition: 'all 167ms cubic-bezier(0.4, 0, 0.2, 1)',
        }}
      >
        {label}
      </div>
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        style={{
          ...letterSpacing(0.5),
          position: 'absolute',
          left,
          right: suffix ? 48 : 0,
          top: 23.5,
          height: 24,
          padding: 0,
          border: 'none',
          outline: 'none',
          background: 'transparent',
          ...AppTypography.bodyLarge,
          lineHeight: '24px',
          color: M3Scheme.onSurface,
          caretColor: AppColors.deepRose,
        }}
      />
      {suffix && <div style={{ position: 'absolute', right: 0, top: 4 }}>{suffix}</div>}
      <div
        style={{
          position: 'absolute',
          left: 0,
          right: 0,
          bottom: 0,
          height: focused ? 2 : 1,
          background: focused ? AppColors.deepRose : M3Scheme.outline,
        }}
      />
    </label>
  );
}
