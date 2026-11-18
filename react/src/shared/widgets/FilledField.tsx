// A filled Material 3 TextField with an outline border, as the app's dialogs and
// search boxes build it.
import { useState, type CSSProperties, type ReactNode } from 'react';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';

/** A filled M3 TextField (bodyLarge text, the hint drawn in the input's own line). */
export function FilledField({
  value,
  onChange,
  hint,
  hintAlpha,
  radius,
  padding,
  borderColor,
  focusColor,
  fontSize = 16,
  lines = 1,
  prefixIcon,
  suffix,
  onSubmit,
  minHeight = 48,
}: {
  value: string;
  onChange: (v: string) => void;
  hint: string;
  hintAlpha: number;
  radius: number;
  padding: [number, number];
  borderColor?: string;
  focusColor?: string;
  fontSize?: number;
  lines?: number;
  prefixIcon?: ReactNode;
  /** suffixIcon: sits in a 48px slot at the end. */ suffix?: ReactNode;
  /** onSubmitted (Enter on a single-line field). */ onSubmit?: () => void;
  /** 48 for M3 fields; isDense fields without icons are just padding + line. */ minHeight?: number;
}) {
  const [focused, setFocused] = useState(false);
  const border = focused && focusColor ? focusColor : borderColor;
  const text: CSSProperties = {
    flex: 1,
    minWidth: 0,
    padding: `${padding[1]}px ${padding[0]}px`,
    paddingLeft: prefixIcon ? 4 : padding[0],
    background: 'transparent',
    border: 'none',
    outline: 'none',
    resize: 'none',
    ...AppTypography.outfitWhite,
    fontSize,
    lineHeight: lineHeight(fontSize, 1.5),
    letterSpacing: 0.5,
    color: AppColors.petalWhite,
    ['--hint-color' as string]: withAlpha(AppColors.petalWhite, hintAlpha),
    ['--hint-size' as string]: `${fontSize}px`,
  };
  return (
    <div
      style={{
        width: '100%',
        minHeight,
        display: 'flex',
        alignItems: lines > 1 ? 'stretch' : 'center',
        background: AppColors.twilight,
        borderRadius: radius,
        boxShadow: border ? `inset 0 0 0 1px ${border}` : undefined,
        boxSizing: 'border-box',
      }}
    >
      {prefixIcon && (
        <div style={{ width: 48, height: 48, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {prefixIcon}
        </div>
      )}
      {lines > 1 ? (
        <textarea
          rows={lines}
          value={value}
          placeholder={hint}
          className="money-input"
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          style={text}
        />
      ) : (
        <input
          value={value}
          placeholder={hint}
          className="money-input"
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          onKeyDown={onSubmit ? (e) => e.key === 'Enter' && onSubmit() : undefined}
          style={text}
        />
      )}
      {suffix && (
        <div style={{ width: 48, height: 48, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {suffix}
        </div>
      )}
    </div>
  );
}
