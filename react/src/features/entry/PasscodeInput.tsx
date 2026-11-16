// Port of lib/features/entry/presentation/widgets/passcode_input.dart.
import { useEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from 'react';
import { useController } from '../../core/anim/controller';
import { lerpColor, lerpNum, lerpShadows, useImplicit, type Shadow } from '../../core/anim/implicit';
import { focusHighlightTraditional, Haptics } from '../../core/system/focusHighlight';
import { useValue } from '../../core/system/store';
import { TvMode } from '../../core/system/tvMode';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppMotion, Curves, motionReduced, orZero } from '../../core/theme/motion';
import { Align, letterSpacing, linear, shadowLayer } from '../../core/theme/paint';
import { AnimatedSwitcher } from '../../shared/widgets/AnimatedSwitcher';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { Icon } from '../../shared/widgets/Icon';
import type { GatewayFailureReason } from './gatewayState';

type Props = {
  input: string;
  onDigitPressed: (digit: string) => void;
  onBackspace: () => void;
  onClear?: () => void;
  isError: boolean;
  isVerifying: boolean;
  failureReason: GatewayFailureReason | null;
};

export function PasscodeInput(props: Props) {
  const { input, isError, isVerifying, failureReason } = props;
  const shake = useController(orZero(520));
  const wasError = useRef(isError);

  useEffect(() => {
    if (isError && !wasError.current) {
      if (!motionReduced()) {
        void shake.forward(0).then(() => shake.reverse());
      }
      Haptics.vibrate();
    }
    wasError.current = isError;
  }, [isError, shake]);

  const shakeValue = 13 * Curves.easeInOut(shake.value);
  const wave = motionReduced() ? 0 : Math.sin((shakeValue / 13) * Math.PI);

  const onKeyDown = (e: KeyboardEvent) => {
    if (isVerifying) return;
    const key = e.key;
    if (TvMode.isBackKey(key)) {
      if (key === 'Escape' && props.onClear) props.onClear();
      else props.onBackspace();
      if (!(key !== 'Escape' && input.length === 0)) e.preventDefault();
      return;
    }
    const digit = TvMode.digitFromKey(key);
    if (digit != null) {
      props.onDigitPressed(digit);
      if (input.length < 4) e.preventDefault();
    }
  };

  return (
    <div
      role="group"
      aria-label="Passcode entry for Khent and Clair"
      aria-description="Enter your 4-digit passcode"
      onKeyDown={onKeyDown}
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        transform: `translateX(${wave * shakeValue}px)`,
      }}
    >
      <Dots input={input} isError={isError} isVerifying={isVerifying} />
      <div style={{ height: 8 }} />
      <div style={{ height: 30, display: 'flex', alignItems: 'center', justifyContent: 'center', alignSelf: 'stretch' }}>
        <StatusLine input={input} isError={isError} isVerifying={isVerifying} failureReason={failureReason} />
      </div>
      <div style={{ height: 10 }} />
      <NumPad {...props} />
    </div>
  );
}

function Dots({ input, isError, isVerifying }: { input: string; isError: boolean; isVerifying: boolean }) {
  return (
    <div
      aria-label="Passcode progress"
      aria-live="polite"
      aria-valuetext={isVerifying ? 'Verifying code' : `${input.length} of 4 digits entered`}
      style={{ display: 'flex', justifyContent: 'center', alignItems: 'center' }}
    >
      {[0, 1, 2, 3].map((i) => (
        <Dot key={i} filled={i < input.length} isError={isError} />
      ))}
    </div>
  );
}

type DotLook = { size: number; color: string; border: string; shadows: Shadow[] };

function lerpDot(a: DotLook, b: DotLook, t: number): DotLook {
  return {
    size: lerpNum(a.size, b.size, t),
    color: lerpColor(a.color, b.color, t),
    border: lerpColor(a.border, b.border, t),
    shadows: lerpShadows(a.shadows, b.shadows, t),
  };
}

function Dot({ filled, isError }: { filled: boolean; isError: boolean }) {
  const target: DotLook = {
    size: filled ? 18 : 14,
    color: isError ? withAlpha(AppColors.error, 0.7) : filled ? AppColors.auroraGold : withAlpha(AppColors.moonlight, 0.08),
    border: filled ? (isError ? AppColors.error : AppColors.auroraGold) : withAlpha(AppColors.moonlight, 0.25),
    shadows: filled
      ? [{ color: withAlpha(isError ? AppColors.error : AppColors.auroraGold, 0.7), blur: 12, spread: 2, dx: 0, dy: 0 }]
      : [],
  };
  const look = useImplicit(target, `${filled}-${isError}`, lerpDot, orZero(220), AppMotion.easeOutStrong);
  return (
    <div style={{ position: 'relative', width: look.size, height: look.size, margin: '0 10px' }}>
      {look.shadows.map((s, i) => (
        <div key={i} style={shadowLayer({ color: s.color, blur: s.blur, spread: s.spread, offset: [s.dx, s.dy] }, { circle: true })} />
      ))}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '50%',
          background: look.color,
          border: `1.6px solid ${look.border}`,
        }}
      />
    </div>
  );
}

function StatusLine({
  input,
  isError,
  isVerifying,
  failureReason,
}: {
  input: string;
  isError: boolean;
  isVerifying: boolean;
  failureReason: GatewayFailureReason | null;
}) {
  let id: string;
  let child: React.ReactNode;
  if (isVerifying) {
    id = 'verifying';
    child = (
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <div style={{ width: 13, height: 13 }}>
          {motionReduced() ? (
            <Icon name="lock" variant="outlined" size={13} color={AppColors.auroraGold} label="Verifying" />
          ) : (
            <CircularProgress size={13} strokeWidth={2} color={AppColors.auroraGold} />
          )}
        </div>
        <div style={{ width: 8 }} />
        <span className="t-bodySmall" style={{ color: withAlpha(AppColors.blushGold, 0.92), fontSize: 12 }}>
          Opening your space…
        </span>
      </div>
    );
  } else if (isError || failureReason != null) {
    const message =
      failureReason === 'connection'
        ? 'Everglow couldn’t connect. Check your connection and try again.'
        : 'That code didn’t open Everglow. Try again.';
    id = `error-${message}`;
    child = (
      <div style={{ padding: '0 24px' }}>
        <div
          className="t-bodySmall clamp-2"
          style={{ color: Derived.textMuted, fontSize: 12, lineHeight: 1.25, textAlign: 'center' }}
        >
          {message}
        </div>
      </div>
    );
  } else {
    id = `progress-${input.length}`;
    child = (
      <div
        className="t-bodySmall"
        style={{ color: withAlpha(AppColors.roseQuartz, 0.62), fontSize: 11, ...letterSpacing(0.4) }}
      >
        {`${input.length} of 4`}
      </div>
    );
  }
  return (
    <AnimatedSwitcher id={id} duration={orZero(220)}>
      {child}
    </AnimatedSwitcher>
  );
}

function NumPad(props: Props) {
  const { isVerifying, onDigitPressed, onBackspace, onClear } = props;
  const rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];
  return (
    <div
      style={{
        pointerEvents: isVerifying ? 'none' : undefined,
        opacity: isVerifying ? 0.55 : 1,
        transition: `opacity ${orZero(200)}ms linear`,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      {rows.map((row) => (
        <div key={row[0]} style={{ display: 'flex', justifyContent: 'center' }}>
          {row.map((d) => (
            <KeyButton
              key={d}
              digit={d}
              autoFocus={d === '1' && TvMode.isTvMode.value}
              onPressed={() => onDigitPressed(d)}
            />
          ))}
        </div>
      ))}
      <div style={{ display: 'flex', justifyContent: 'center' }}>
        <KeyButton
          icon="refresh"
          label="Clear"
          onPressed={() => {
            if (onClear) onClear();
            else for (let i = 0; i < props.input.length; i++) onBackspace();
          }}
        />
        <KeyButton digit="0" onPressed={() => onDigitPressed('0')} />
        <KeyButton icon="backspace" iconVariant="outlined" label="Backspace" onPressed={onBackspace} />
      </div>
    </div>
  );
}

type KeyLook = {
  scale: number;
  c1: string;
  c2: string;
  border: string;
  borderWidth: number;
  shadows: Shadow[];
};

function lerpKey(a: KeyLook, b: KeyLook, t: number): KeyLook {
  return {
    scale: lerpNum(a.scale, b.scale, t),
    c1: lerpColor(a.c1, b.c1, t),
    c2: lerpColor(a.c2, b.c2, t),
    border: lerpColor(a.border, b.border, t),
    borderWidth: lerpNum(a.borderWidth, b.borderWidth, t),
    shadows: lerpShadows(a.shadows, b.shadows, t),
  };
}

function KeyButton({
  digit,
  icon,
  iconVariant = 'round',
  label,
  autoFocus = false,
  onPressed,
}: {
  digit?: string;
  icon?: string;
  iconVariant?: 'round' | 'outlined';
  label?: string;
  autoFocus?: boolean;
  onPressed: () => void;
}) {
  const isTv = useValue(TvMode.isTvMode);
  const traditional = useValue(focusHighlightTraditional);
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [focused, setFocused] = useState(false);
  const ref = useRef<HTMLButtonElement>(null);
  const downAt = useRef<[number, number] | null>(null);

  useEffect(() => {
    if (autoFocus) ref.current?.focus();
  }, [autoFocus]);

  const ring = focused && (isTv || traditional);
  const size = isTv ? 62 : 56;
  const scale = pressed ? 0.9 : ring ? (isTv ? 1.12 : 1.08) : hovered ? 1.04 : 1.0;

  const target: KeyLook = {
    scale,
    c1: pressed
      ? withAlpha(AppColors.auroraGold, 0.55)
      : withAlpha(AppColors.moonlight, ring ? 0.28 : hovered ? 0.2 : 0.12),
    c2: pressed ? withAlpha(AppColors.deepRose, 0.45) : withAlpha(AppColors.inkDeep, 0.35),
    border: ring
      ? AppColors.auroraGold
      : pressed
        ? AppColors.auroraGold
        : withAlpha(AppColors.moonlight, hovered ? 0.55 : 0.24),
    borderWidth: ring ? (isTv ? 3.0 : 2.5) : 1.4,
    shadows: [
      ...(ring
        ? [{ color: withAlpha(AppColors.auroraGold, 0.65), blur: isTv ? 20 : 16, spread: isTv ? 2 : 1, dx: 0, dy: 0 }]
        : hovered || pressed
          ? [{ color: withAlpha(AppColors.auroraGold, pressed ? 0.5 : 0.28), blur: 18, spread: -2, dx: 0, dy: 0 }]
          : []),
      { color: withAlpha(AppColors.black, 0.3), blur: 8, spread: 0, dx: 0, dy: 3 },
    ],
  };
  const look = useImplicit(target, JSON.stringify(target), lerpKey, orZero(AppMotion.fast), AppMotion.easeOutStrong);

  const a11yLabel = digit != null ? `Digit ${digit}` : (label ?? 'Backspace');
  const hint = digit != null ? `Enters ${digit}` : label === 'Clear' ? 'Clears all entered digits' : 'Deletes the last digit';
  const fg = pressed ? AppColors.inkDeep : AppColors.petalWhite;

  const cancel = () => {
    downAt.current = null;
    setPressed(false);
  };

  return (
    <div style={{ padding: isTv ? 7 : 6 }}>
      <button
        ref={ref}
        type="button"
        aria-label={a11yLabel}
        aria-description={hint}
        className="bare-button"
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        onKeyDown={(e) => {
          if (TvMode.isSelectKey(e.key)) {
            e.preventDefault();
            e.stopPropagation();
            onPressed();
          }
        }}
        onClick={(e) => e.preventDefault()}
        onPointerEnter={(e: PointerEvent) => e.pointerType === 'mouse' && setHovered(true)}
        onPointerLeave={(e: PointerEvent) => {
          if (e.pointerType === 'mouse') setHovered(false);
        }}
        onPointerDown={(e: PointerEvent) => {
          if (e.button !== 0) return;
          e.preventDefault();
          downAt.current = [e.clientX, e.clientY];
          setPressed(true);
          Haptics.selectionClick();
        }}
        onPointerMove={(e: PointerEvent) => {
          const start = downAt.current;
          if (start && Math.hypot(e.clientX - start[0], e.clientY - start[1]) > 18) cancel();
        }}
        onPointerUp={() => {
          if (!downAt.current) return;
          downAt.current = null;
          setPressed(false);
          if (document.activeElement !== ref.current) ref.current?.focus({ preventScroll: true });
          onPressed();
        }}
        onPointerCancel={cancel}
        style={{
          position: 'relative',
          width: size,
          height: size,
          transform: `scale(${look.scale})`,
          transformOrigin: '0 0',
        }}
      >
        {look.shadows.map((s, i) => (
          <div key={i} style={shadowLayer({ color: s.color, blur: s.blur, spread: s.spread, offset: [s.dx, s.dy] }, { circle: true })} />
        ))}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: '50%',
            backgroundImage: linear([look.c1, look.c2], { begin: Align.topLeft, end: Align.bottomRight, size: [size, size] }),
            backgroundOrigin: 'border-box',
            border: `${look.borderWidth}px solid ${look.border}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {digit != null ? (
            <span className="t-outfit" style={{ fontSize: isTv ? 26 : 24, fontWeight: 500, color: fg }}>
              {digit}
            </span>
          ) : (
            <Icon
              name={icon!}
              variant={iconVariant}
              size={isTv ? 23 : 21}
              color={pressed ? AppColors.inkDeep : ring ? AppColors.petalWhite : AppColors.blushGold}
              label={label ?? 'Action'}
            />
          )}
        </div>
      </button>
    </div>
  );
}
