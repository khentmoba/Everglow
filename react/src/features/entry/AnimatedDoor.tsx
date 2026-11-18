// Port of lib/features/entry/presentation/widgets/animated_door.dart.
import { useEffect, useRef, type ReactNode } from 'react';
import { useController } from '../../core/anim/controller';
import { isLowEndDevice, reduceAmbientMotion } from '../../core/system/device';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { cubic, Curves, orLinear, orZero } from '../../core/theme/motion';
import { Align, boxShadow, letterSpacing, linear, radial, shadowLayer, type BoxShadow } from '../../core/theme/paint';

export function archPath(w: number, h: number, x = 0, y = 0): string {
  const r = Math.min(w / 2, h * 0.24);
  return (
    `M${x} ${y + h} L${x} ${y + r} Q${x} ${y} ${x + r} ${y} ` +
    `L${x + w - r} ${y} Q${x + w} ${y} ${x + w} ${y + r} L${x + w} ${y + h} Z`
  );
}

const clipArch = (w: number, h: number) => `path('${archPath(w, h)}')`;

export function doorScale(viewport: { width: number; height: number }): number {
  return Math.min(1, Math.min((viewport.width - 24) / 330, (viewport.height - 48) / 560));
}

const entranceCurve = cubic(0.16, 1.0, 0.3, 1.0);
const handleCurve = cubic(0.34, 1.56, 0.64, 1.0);

type Props = {
  isUnlocked: boolean;
  isError: boolean;
  isRevealing: boolean;
  keypad: ReactNode;
  onEntranceComplete?: () => void;
};

export function AnimatedDoor({ isUnlocked, isError, isRevealing, keypad, onEntranceComplete }: Props) {
  const viewport = useViewport();
  const entranceMs = isLowEndDevice() ? 500 : 1400;
  const entrance = useController(orZero(entranceMs));
  const swing = useController(orZero(1700));
  const handle = useController(orZero(700));
  const zoom = useController(orZero(1100));
  const breathe = useController(3000);
  const entranceDone = useRef(false);
  const wasUnlocked = useRef(isUnlocked);
  const wasRevealing = useRef(isRevealing);

  useEffect(() => {
    const complete = () => {
      if (entranceDone.current) return;
      entranceDone.current = true;
      onEntranceComplete?.();
    };
    void entrance.forward().then(complete);
    const fallback = window.setTimeout(complete, entranceMs + 400);
    return () => clearTimeout(fallback);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const ambientOff = reduceAmbientMotion(viewport);
  useEffect(() => {
    if (ambientOff) breathe.stop();
    else if (!breathe.isAnimating) breathe.repeat({ reverse: true });
  }, [ambientOff, breathe]);

  useEffect(() => {
    if (isUnlocked && !wasUnlocked.current) {
      void (async () => {
        await handle.forward();
        await new Promise((r) => setTimeout(r, 180));
        await swing.forward();
      })();
    }
    wasUnlocked.current = isUnlocked;
  }, [isUnlocked, handle, swing]);

  useEffect(() => {
    if (isRevealing && !wasRevealing.current) void zoom.forward();
    wasRevealing.current = isRevealing;
  }, [isRevealing, zoom]);

  const scale = doorScale(viewport);
  const e = orLinear(entranceCurve)(entrance.value);
  const s = orLinear(Curves.easeInOutCubic)(swing.value);
  const h = orLinear(handleCurve)(handle.value);
  const z = orLinear(Curves.easeInQuint)(zoom.value);
  const b = breathe.value;

  const zoomScale = 1 + 4 * z;
  const breatheScale = 1 + 0.012 * b;
  const entranceBounce = 0.92 + 0.08 * e;
  const opacity = Math.min(1, Math.max(0, e * (1 - z)));

  return (
    <div
      style={{
        position: 'relative',
        width: 330,
        height: 560,
        flexShrink: 0,
        transform: `scale(${entranceBounce * zoomScale * breatheScale * scale})`,
        opacity,
      }}
    >
      <Halo breathe={b} />
      <Sparkles progress={b} />
      {isUnlocked && <LightBloom t={s} />}
      <DoorFrame />
      <div
        style={{
          position: 'absolute',
          left: 7,
          top: 7,
          width: 316,
          height: 546,
          transformOrigin: 'left center',
          transform: `perspective(1000px) rotateY(${90 * s}deg)`,
        }}
      >
        <DoorPanel swing={s} handle={h} isError={isError} isUnlocked={isUnlocked} keypad={keypad} />
      </div>
    </div>
  );
}

function Halo({ breathe }: { breathe: number }) {
  // BoxShape.circle in a 330x560 box: a 330px circle in the middle.
  const shadows: BoxShadow[] = [
    { color: withAlpha(AppColors.deepRose, 0.22 + 0.08 * breathe), blur: 90, spread: 24 },
    { color: withAlpha(AppColors.blushGold, 0.1), blur: 140, spread: 40 },
  ];
  return (
    <div style={{ position: 'absolute', left: 0, top: 115, width: 330, height: 330, pointerEvents: 'none' }}>
      {shadows.map((sh, i) => (
        <div key={i} style={shadowLayer(sh, { circle: true })} />
      ))}
    </div>
  );
}

function Sparkles({ progress }: { progress: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current!;
    const dpr = window.devicePixelRatio || 1;
    const w = 330;
    const h = 560;
    if (canvas.width !== w * dpr) {
      canvas.width = w * dpr;
      canvas.height = h * dpr;
    }
    const ctx = canvas.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    for (let i = 0; i < 26; i++) {
      const seed = i * 137.0;
      const x = ((seed * 1.61) % 1.0) * w;
      const y = ((seed * 3.71) % 1.0) * h;
      const twinkle = 0.25 + 0.55 * (0.5 + 0.5 * Math.sin(progress * Math.PI * 4 + seed));
      const radius = 0.8 + (seed % 1.0) * 1.4;
      ctx.fillStyle = withAlpha(AppColors.auroraGold, twinkle * 0.55);
      ctx.beginPath();
      ctx.arc(x, y, radius, 0, Math.PI * 2);
      ctx.fill();
    }
  }, [progress]);
  return <canvas ref={ref} style={{ position: 'absolute', inset: 0, width: 330, height: 560, pointerEvents: 'none' }} />;
}

function LightBloom({ t }: { t: number }) {
  const w = 300 * (0.35 + 0.65 * t);
  const h = 560 * (0.45 + 0.55 * t);
  return (
    <div
      style={{
        position: 'absolute',
        left: (330 - w) / 2,
        top: (560 - h) / 2,
        width: w,
        height: h,
      }}
    >
      <div style={shadowLayer({ color: withAlpha(AppColors.petalWhite, 0.5 * t), blur: 70, spread: 30 })} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          backgroundImage: radial(
            [withAlpha(AppColors.blushGold, 0.85 * t), withAlpha(AppColors.auroraRose, 0.35 * t), AppColors.transparent],
            { center: [0.2, 0], radius: 0.9, stops: [0, 0.45, 1], size: [w, h] },
          ),
        }}
      />
    </div>
  );
}

function DoorFrame() {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        clipPath: clipArch(330, 560),
        backgroundImage: linear([withAlpha(AppColors.blushGold, 0.9), AppColors.velvet, AppColors.twilight], {
          begin: Align.topCenter,
          end: Align.bottomCenter,
          stops: [0, 0.28, 1],
        }),
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: 7,
          top: 7,
          width: 316,
          height: 546,
          boxSizing: 'border-box',
          clipPath: clipArch(316, 546),
          backgroundImage: linear([AppColors.inkDeep, AppColors.twilight], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            size: [316, 546],
          }),
          backgroundOrigin: 'border-box',
          border: `1.2px solid ${withAlpha(AppColors.moonlight, 0.22)}`,
        }}
      />
    </div>
  );
}

function DoorPanel({
  swing,
  handle,
  isError,
  isUnlocked,
  keypad,
}: {
  swing: number;
  handle: number;
  isError: boolean;
  isUnlocked: boolean;
  keypad: ReactNode;
}) {
  const colors = isError
    ? [withAlpha(AppColors.error, 0.75), withAlpha(AppColors.deepRose, 0.9)]
    : [AppColors.velvet, AppColors.twilight];
  const shadows: BoxShadow[] = [
    {
      color: withAlpha(AppColors.black, 0.55 - 0.25 * swing),
      blur: 26,
      offset: [12 * (1 - swing), 12 * (1 - swing)],
    },
    {
      color: isError ? withAlpha(AppColors.error, 0.35) : withAlpha(AppColors.deepRose, 0.25),
      blur: 40,
      spread: -8,
    },
  ];
  return (
    <div style={{ position: 'absolute', inset: 0, clipPath: clipArch(316, 546) }}>
      {shadows.map((sh, i) => (
        <div key={i} style={shadowLayer(sh)} />
      ))}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          backgroundImage: linear(colors, {
            begin: Align.topLeft,
            end: Align.bottomRight,
            stops: [0, 1 - 0.45 * swing],
            size: [316, 546],
          }),
        }}
      />
      {isUnlocked && <PanelBevels />}
      <div style={{ position: 'absolute', top: 34, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
        <Nameplate />
      </div>
      <div
        className="t-hand"
        style={{
          position: 'absolute',
          top: 92,
          left: 0,
          right: 0,
          textAlign: 'center',
          fontSize: 15,
          lineHeight: 1,
          color: withAlpha(AppColors.blushGold, 0.9),
        }}
      >
        Khent &amp; Clair
      </div>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          padding: '64px 44px 42px 24px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {keypad}
      </div>
      {isUnlocked && (
        <>
          <div style={{ position: 'absolute', right: 14, top: 262, transform: `rotate(${handle * (Math.PI / 5)}rad)` }}>
            <Lever />
          </div>
          <div style={{ position: 'absolute', right: 38, top: 330 }}>
            <Escutcheon />
          </div>
        </>
      )}
    </div>
  );
}

function PanelBevels() {
  // Column of Expanded(3), Expanded(1), Expanded(3) in 546px.
  const unit = 546 / 7;
  const box = (topArch: boolean, height: number) => (
    <div style={{ height, padding: '16px 34px', boxSizing: 'border-box' }}>
      <div
        style={{
          height: '100%',
          boxSizing: 'border-box',
          borderRadius: `${topArch ? 26 : 10}px ${topArch ? 26 : 10}px 10px 10px`,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.18)}`,
          backgroundOrigin: 'border-box',
          backgroundImage: linear(
            [withAlpha(AppColors.moonlight, 0.09), AppColors.transparent, withAlpha(AppColors.inkDeep, 0.28)],
            { begin: Align.topLeft, end: Align.bottomRight, size: [316 - 68, height - 32] },
          ),
        }}
      />
    </div>
  );
  return (
    <div style={{ position: 'absolute', inset: 0 }}>
      {box(true, unit * 3)}
      {box(false, unit)}
      {box(true, unit * 3)}
    </div>
  );
}

function Nameplate() {
  return (
    <div style={{ position: 'relative', padding: '9px 22px', borderRadius: 14 }}>
      <div style={shadowLayer({ color: withAlpha(AppColors.blushGold, 0.35), blur: 18 }, { radius: 14 })} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: 14,
          backgroundImage: linear([withAlpha(AppColors.blushGold, 0.85), withAlpha(AppColors.auroraGold, 0.65)]),
        }}
      />
      <span
        className="t-outfit"
        style={{
          ...letterSpacing(3.4),
          display: 'block',
          color: AppColors.inkDeep,
          fontWeight: 800,
          fontSize: 13,
        }}
      >
        EVERGLOW
      </span>
    </div>
  );
}

function Lever() {
  return (
    <div style={{ position: 'relative', width: 78, height: 40 }}>
      <div
        style={{
          position: 'absolute',
          // Flutter squeezes this 42x42 box to 42x40 inside the 40px-tall
          // lever, and a circle in that box is 40px wide, centered.
          left: 1,
          top: 0,
          width: 40,
          height: 40,
          boxSizing: 'border-box',
          borderRadius: '50%',
          backgroundImage: linear([AppColors.auroraGold, AppColors.blushGold], {
            begin: Align.topLeft,
            end: Align.bottomRight,
          }),
          backgroundOrigin: 'border-box',
          border: `1.2px solid ${withAlpha(AppColors.petalWhite, 0.35)}`,
          boxShadow: boxShadow([
            { color: withAlpha(AppColors.auroraGold, 0.5), blur: 14 },
            { color: withAlpha(AppColors.black, 0.4), blur: 6, offset: [1, 2] },
          ]),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <div style={{ width: 10, height: 14, borderRadius: 4, background: withAlpha(AppColors.inkDeep, 0.75) }} />
      </div>
      <div
        style={{
          position: 'absolute',
          left: 20,
          top: 12.5,
          width: 60,
          height: 15,
          borderRadius: '0 12px 12px 0',
          backgroundImage: linear([AppColors.auroraGold, AppColors.blushGold], {
            begin: Align.topCenter,
            end: Align.bottomCenter,
          }),
          boxShadow: boxShadow([{ color: withAlpha(AppColors.black, 0.45), blur: 7, offset: [2, 3] }]),
        }}
      />
    </div>
  );
}

function Escutcheon() {
  return (
    <div
      style={{
        width: 46,
        height: 56,
        boxSizing: 'border-box',
        borderRadius: 12,
        backgroundImage: linear([AppColors.blushGold, AppColors.auroraGold], {
          begin: Align.topLeft,
          end: Align.bottomRight,
          size: [46, 56],
        }),
        backgroundOrigin: 'border-box',
        border: `1px solid ${withAlpha(AppColors.petalWhite, 0.3)}`,
        boxShadow: boxShadow([{ color: withAlpha(AppColors.black, 0.4), blur: 6, offset: [1, 2] }]),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          width: 16,
          height: 22,
          borderRadius: 8,
          background: withAlpha(AppColors.inkDeep, 0.85),
          display: 'flex',
          alignItems: 'flex-end',
          justifyContent: 'center',
        }}
      >
        <div style={{ width: 7, height: 8, marginBottom: 3, borderRadius: '0 0 4px 4px', background: AppColors.inkDeep }} />
      </div>
    </div>
  );
}
