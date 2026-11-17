// Port of lib/features/starlight_jar/presentation/screens/starlight_jar_widget.dart
// and widgets/glass_jar.dart.
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { useAuth } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { useViewport } from '../../core/system/viewport';
import { AppColors, M3Scheme, withAlpha } from '../../core/theme/colors';
import { Curves, reduceAmbientMotion } from '../../core/theme/motion';
import { boxShadow, letterSpacing, lineHeight, mixedLineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { DartRandom, dartStringHash } from '../../shared/utils/dart';
import { Confetti } from '../../shared/widgets/Confetti';
import { showDialog } from '../../shared/widgets/Dialogs';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { FilledField } from '../../shared/widgets/FilledField';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { awardDaily } from '../xp/xpService';
import { drawOrigamiStar } from './origamiStar';
import { DropStarDialog, NoteDisplayDialog, type StarDropResult } from './StarlightDialogs';
import { STAR_CATEGORIES, STAR_CATEGORY_INFO, starlightService, type StarNote } from './starlightService';

const JAR_W = 280;
const JAR_H = 350;
const CONFETTI_COLORS = [
  AppColors.blushGold,
  AppColors.roseQuartz,
  AppColors.softLavender,
  AppColors.petalWhite,
  '#FFF176',
  '#80DEEA',
];
const STAR_COLORS = [
  AppColors.auroraGold,
  AppColors.blushGold,
  AppColors.auroraRose,
  AppColors.roseQuartz,
  AppColors.auroraLilac,
  AppColors.softLavender,
  AppColors.auroraTeal,
];

type Motion = {
  baseX: number;
  baseY: number;
  baseSize: number;
  ampX: number;
  ampY: number;
  speedX: number;
  speedY: number;
  phaseX: number;
  phaseY: number;
  rotSpeed: number;
  twinklePhase: number;
  baseRotation: number;
  color: string;
};

/** _StarMotion.fromSeed(note.id.hashCode): the same Random(seed) draws, so every star sits where Flutter puts it. */
const motions = new Map<number, Motion>();
function motionFor(id: string): Motion {
  const seed = dartStringHash(id);
  let m = motions.get(seed);
  if (!m) {
    const r = new DartRandom(seed);
    const d = () => r.nextDouble();
    m = {
      baseX: 32 + d() * 196,
      baseY: 52 + d() * 224,
      baseSize: 20 + d() * 8,
      ampX: 6 + d() * 10,
      ampY: 5 + d() * 8,
      speedX: 0.45 + d() * 0.4,
      speedY: 0.35 + d() * 0.35,
      phaseX: d() * 2 * Math.PI,
      phaseY: d() * 2 * Math.PI,
      rotSpeed: 0.15 + d() * 0.35,
      twinklePhase: d() * 2 * Math.PI,
      baseRotation: d() * 2 * Math.PI,
      color: STAR_COLORS[0],
    };
    m.color = STAR_COLORS[r.nextInt(STAR_COLORS.length)];
    motions.set(seed, m);
  }
  return m;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/** _JarStarFieldPainter.paint at idle time `t` (0..1 over 14s). */
function paintField(ctx: CanvasRenderingContext2D, notes: StarNote[], t: number) {
  const left = 18;
  const top = 40;
  const right = JAR_W - 18;
  const bottom = JAR_H - 18;
  const tau = 2 * Math.PI;
  for (const note of notes) {
    const m = motionFor(note.id);
    const tX = t * m.speedX;
    const tY = t * m.speedY;
    const rawDx = m.baseX + Math.sin(tX * tau + m.phaseX) * m.ampX + Math.sin(tX * tau * 0.37 + m.phaseX * 1.7) * m.ampX * 0.3;
    const rawDy = m.baseY + Math.cos(tY * tau + m.phaseY) * m.ampY + Math.cos(tY * tau * 0.43 + m.phaseY * 1.3) * m.ampY * 0.25;
    const wave = Math.sin(t * tau * 1.8 + m.twinklePhase);
    ctx.save();
    ctx.translate(clamp(rawDx, left, Math.max(left, right)), clamp(rawDy, top, Math.max(top, bottom)));
    ctx.rotate(m.baseRotation + Math.sin(t * tau * m.rotSpeed) * 0.35);
    drawOrigamiStar(ctx, {
      color: m.color,
      size: m.baseSize * (0.94 + Math.sin(t * tau * 1.1 + m.phaseX) * 0.08),
      opacity: clamp(0.86 + wave * 0.14, 0.7, 1),
      glowIntensity: clamp(0.68 + wave * 0.32, 0.35, 1),
      sparkle: clamp(wave - 0.6, 0, 0.4) / 0.4,
    });
    ctx.restore();
  }
}

/** A StarWidget: a `size` box at `left/top` with the star painted in its centre. */
function paintStar(ctx: CanvasRenderingContext2D, color: string, left: number, top: number, size: number, rotation: number) {
  ctx.save();
  ctx.translate(left + size / 2, top + size / 2);
  ctx.rotate(rotation);
  drawOrigamiStar(ctx, { color, size });
  ctx.restore();
}

/** An AnimationController run from `from` to `to` over `ms`, calling `frame` with the raw value. */
function run(ms: number, frame: (v: number) => void, from = 0, to = 1): Promise<void> {
  return new Promise((resolve) => {
    const start = performance.now();
    const tick = (now: number) => {
      const p = Math.min(1, (now - start) / ms);
      frame(from + (to - from) * p);
      if (p < 1) requestAnimationFrame(tick);
      else resolve();
    };
    requestAnimationFrame(tick);
  });
}

/** The jar's shake: TweenSequence 0 → .12 → -.12 → .08 → -.05 → 0 with weights 1,2,2,2,1. */
function shakeAt(v: number): number {
  const keys: Array<[number, number]> = [
    [0, 0],
    [1 / 8, 0.12],
    [3 / 8, -0.12],
    [5 / 8, 0.08],
    [7 / 8, -0.05],
    [1, 0],
  ];
  for (let i = 1; i < keys.length; i++) {
    const [t1, a1] = keys[i];
    const [t0, a0] = keys[i - 1];
    if (v <= t1) return a0 + ((a1 - a0) * (v - t0)) / (t1 - t0);
  }
  return 0;
}

export function StarlightJarWidget() {
  const auth = useAuth();
  const viewport = useViewport();
  const serverNotes = useSource(() => starlightService.getStarNotes(), [], [] as StarNote[]);
  const [optimistic, setOptimistic] = useState<StarNote[]>([]);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [onThisDay, setOnThisDay] = useState<StarNote[]>([]);
  const [tapScale, setTapScale] = useState(1);
  const [shake, setShake] = useState(0);
  const [confetti, setConfetti] = useState(0);

  const pending = optimistic.filter(
    (o) => !serverNotes.some((s) => s.content === o.content && s.author.toLowerCase() === o.author.toLowerCase()),
  );
  const notes = [...pending, ...serverNotes];
  const query = search.trim().toLowerCase();
  const filtered = notes.filter(
    (n) =>
      (query === '' || n.content.toLowerCase().includes(query) || n.tags.some((t) => t.toLowerCase().includes(query))) &&
      (selectedCategory == null || n.category === selectedCategory),
  );

  useEffect(() => {
    let alive = true;
    void starlightService.getStarsFromThisDay().then((n) => alive && n.length > 0 && setOnThisDay(n));
    return () => {
      alive = false;
    };
  }, []);

  // The star field canvas, repainted from refs by the idle loop and the drop/float animations.
  const canvas = useRef<HTMLCanvasElement>(null);
  const fieldNotes = useRef<StarNote[]>([]);
  const idleT = useRef(0);
  const drop = useRef<{ start: [number, number]; end: [number, number]; v: number } | null>(null);
  const float = useRef<number | null>(null);
  const draw = useCallback(() => {
    const el = canvas.current;
    const ctx = el?.getContext('2d');
    if (!el || !ctx) return;
    const dpr = window.devicePixelRatio || 1;
    if (el.width !== Math.round(JAR_W * dpr)) {
      el.width = Math.round(JAR_W * dpr);
      el.height = Math.round(JAR_H * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, JAR_W, JAR_H);
    paintField(ctx, fieldNotes.current, idleT.current);
    const d = drop.current;
    if (d) {
      const p = Curves.bounceOut(d.v);
      paintStar(
        ctx,
        AppColors.blushGold,
        d.start[0] + (d.end[0] - d.start[0]) * p,
        d.start[1] + (d.end[1] - d.start[1]) * p,
        24,
        d.v * Math.PI * 2,
      );
    }
    const f = float.current;
    if (f != null) {
      const v = Curves.easeOutExpo(f);
      paintStar(ctx, AppColors.deepRose, 128, 250 + (60 - 250) * v, 24 + 16 * v, f * Math.PI);
    }
  }, []);

  fieldNotes.current = filtered;
  useEffect(draw);

  const idle = !reduceAmbientMotion(viewport.width, viewport.height);
  useEffect(() => {
    if (!idle) return;
    const start = performance.now() - idleT.current * 14000;
    let raf = 0;
    const tick = (now: number) => {
      idleT.current = ((now - start) / 14000) % 1;
      draw();
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [idle, draw]);

  const busy = useRef(false);
  const shaking = useRef(false);

  const showNote = async (note: StarNote) => {
    await showDialog<null>((close) => <NoteDisplayDialog note={note} close={() => close(null)} />, {
      barrierDismissible: false,
      insetPadding: '0',
    });
    if (float.current != null) {
      await run(
        500,
        (v) => {
          float.current = v;
          draw();
        },
        float.current,
        0,
      );
    }
    float.current = null;
    draw();
  };

  const floatAndReveal = async (note: StarNote) => {
    await run(500, (v) => {
      float.current = v;
      draw();
    });
    await showNote(note);
  };

  const emptyJar = () =>
    showSnackBar('No stars in the jar yet — drop one first!', { background: AppColors.velvet, duration: 2000 });

  const onJarTap = async () => {
    if (busy.current || shaking.current) return;
    busy.current = true;
    try {
      setTapScale(0.95);
      shaking.current = true;
      await run(600, (v) => setShake(shakeAt(v)));
      shaking.current = false;
      setTapScale(1);
      const note = await starlightService.getRandomStarNote();
      if (note) await floatAndReveal(note);
      else emptyJar();
    } finally {
      busy.current = false;
    }
  };

  const surprise = async () => {
    if (busy.current || shaking.current) return;
    const note = await starlightService.getRandomStarNote();
    if (!note) {
      emptyJar();
      return;
    }
    busy.current = true;
    try {
      setConfetti((c) => c + 1);
      await floatAndReveal(note);
    } finally {
      busy.current = false;
    }
  };

  const startDrop = (content: string, author: string) => {
    const end: [number, number] = [60 + Math.random() * 160, 220 + Math.random() * 60];
    drop.current = { start: [128, -40], end, v: 0 };
    void run(1000, (v) => {
      if (drop.current) drop.current.v = v;
      draw();
    }).then(() => {
      drop.current = null;
      setOptimistic((list) => [
        ...list,
        {
          id: `optimistic_${Date.now()}`,
          content,
          author: author.toLowerCase(),
          timestamp: new Date(),
          category: 'gratitude',
          tags: [],
        },
      ]);
    });
  };

  const openDrop = async () => {
    const result = await showDialog<StarDropResult>((close) => <DropStarDialog close={close} />, {
      barrierColor: 'transparent',
      insetPadding: '0',
    });
    if (!result || result.content.trim() === '') return;
    const author = auth.currentUser ?? 'unknown';
    const uid = auth.uid;
    startDrop(result.content, author);
    try {
      await starlightService.addStar(result.content, author, result.category, result.tags);
      if (uid) {
        try {
          await awardDaily(uid, 'star', { amount: 15, dailyCap: 3 });
        } catch (e) {
          Logger.e('Starlight: XP award failed', e);
        }
      }
    } catch (e) {
      Logger.e('Optimistic action failed and rolled back', e);
      setOptimistic((list) => list.filter((n) => n.content !== result.content));
      showSnackBar('Failed to save star. Please try again.', { duration: 2000 });
    }
  };

  return (
    <div style={{ position: 'relative', overflow: 'hidden' }}>
      <Confetti colors={CONFETTI_COLORS} frequency={0.06} particles={20} duration={2000} play={confetti} />
      <EverglowFeatureHeader
        title="Starlight Jar"
        subtitle="gratitude under the stars"
        icon="auto_awesome"
        hue={AppColors.blushGold}
      />

      {onThisDay.length > 0 && <OnThisDayCard note={onThisDay[0]} onTap={() => void showNote(onThisDay[0])} />}

      <div style={{ padding: '6px 20px' }}>
        <FilledField
          value={search}
          onChange={setSearch}
          hint="Search stars…"
          hintAlpha={0.55}
          radius={14}
          padding={[12, 10]}
          fontSize={13}
          borderColor={M3Scheme.onSurfaceVariant}
          focusColor={AppColors.blushGold}
          prefixIcon={<Icon name="search" variant="filled" size={18} color={AppColors.blushGold} />}
          suffix={
            search.trim() !== '' && (
              <button
                type="button"
                className="bare-button"
                aria-label="Clear search"
                onClick={() => setSearch('')}
                style={{
                  width: 48,
                  height: 48,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                }}
              >
                <Icon name="clear" variant="filled" size={16} color={withAlpha(AppColors.petalWhite, 0.4)} />
              </button>
            )
          }
        />
        <div style={{ height: 8 }} />
        <div className="no-scrollbar" style={{ overflowX: 'auto', display: 'flex' }}>
          <CategoryChip label="All" selected={selectedCategory == null} onTap={() => setSelectedCategory(null)} />
          {STAR_CATEGORIES.map((cat) => (
            <CategoryChip
              key={cat}
              label={STAR_CATEGORY_INFO[cat]?.[1] ?? cat}
              selected={selectedCategory === cat}
              onTap={() => setSelectedCategory(cat)}
            />
          ))}
        </div>
      </div>

      <div style={{ height: 4 }} />

      <div style={{ height: 390, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ position: 'relative', width: JAR_W, height: 370, flexShrink: 0 }}>
          <button
            type="button"
            className="bare-button"
            aria-label="Glass jar containing gratitude notes"
            onClick={() => void onJarTap()}
            style={{
              position: 'absolute',
              top: 20,
              left: 0,
              width: JAR_W,
              height: JAR_H,
              borderRadius: '40px 40px 80px 80px',
              transform: `scale(${tapScale}) rotate(${shake}rad)`,
              transition: 'transform 150ms cubic-bezier(0.19, 1, 0.22, 1)',
              cursor: 'pointer',
            }}
          >
            <GlassJar />
          </button>

          {notes.length > 0 && (
            <div
              style={{
                position: 'absolute',
                top: 22,
                left: 0,
                right: 0,
                display: 'flex',
                justifyContent: 'center',
                pointerEvents: 'none',
              }}
            >
              <div
                style={{
                  padding: '4px 12px',
                  borderRadius: 12,
                  background: withAlpha(AppColors.deepRose, 0.8),
                  boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.3), blur: 8 }]),
                }}
              >
                <div
                  style={{
                    ...AppTypography.outfitWhite,
                    fontSize: 11,
                    lineHeight: lineHeight(11),
                    fontWeight: 700,
                    color: AppColors.petalWhite,
                    ...letterSpacing(0.5),
                  }}
                >
                  {notes.length} {notes.length === 1 ? 'star' : 'stars'}
                </div>
              </div>
            </div>
          )}

          <div
            style={{
              position: 'absolute',
              top: 20,
              left: 0,
              width: JAR_W,
              height: JAR_H,
              borderRadius: 28,
              overflow: 'hidden',
              pointerEvents: 'none',
            }}
          >
            <canvas ref={canvas} aria-hidden style={{ width: JAR_W, height: JAR_H, display: 'block' }} />
          </div>
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          right: 20,
          bottom: 24,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <Fab mini background={AppColors.blushGold} label="Surprise me" onPressed={() => void surprise()}>
          <Icon name="casino" size={20} color={AppColors.velvet} />
        </Fab>
        <div style={{ height: 10 }} />
        <Fab background={AppColors.deepRose} label="Drop a star" onPressed={() => void openDrop()}>
          <Icon name="star" variant="filled" size={24} color={AppColors.petalWhite} />
        </Fab>
      </div>
    </div>
  );
}

function OnThisDayCard({ note, onTap }: { note: StarNote; onTap: () => void }) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label="On This Day memory from the past. Tap to view."
      onClick={onTap}
      style={{
        display: 'flex',
        alignItems: 'center',
        width: 'calc(100% - 40px)',
        margin: '6px 20px',
        padding: '10px 16px',
        boxSizing: 'border-box',
        background: `linear-gradient(to right, ${withAlpha(AppColors.blushGold, 0.15)}, ${withAlpha(AppColors.deepRose, 0.15)})`,
        borderRadius: 16,
        border: `1px solid ${withAlpha(AppColors.blushGold, 0.65)}`,
        textAlign: 'left',
        cursor: 'pointer',
      }}
    >
      <span style={{ fontSize: 18, lineHeight: mixedLineHeight(18) }}>📅</span>
      <div style={{ width: 10 }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 13,
            lineHeight: lineHeight(13),
            fontWeight: 700,
            color: AppColors.blushGold,
          }}
        >
          On This Day
        </div>
        <div
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 11,
            lineHeight: lineHeight(11),
            color: withAlpha(AppColors.petalWhite, 0.6),
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
          }}
        >
          {note.content}
        </div>
      </div>
      <Icon name="chevron_right" variant="filled" size={20} color={withAlpha(AppColors.blushGold, 0.65)} />
    </button>
  );
}

function CategoryChip({ label, selected, onTap }: { label: string; selected: boolean; onTap: () => void }) {
  return (
    <div style={{ paddingRight: 6, flexShrink: 0 }}>
      <button
        type="button"
        className="bare-button"
        onClick={onTap}
        style={{
          padding: '4px 10px',
          borderRadius: 10,
          background: selected ? withAlpha(AppColors.deepRose, 0.6) : 'transparent',
          border: `1px solid ${selected ? AppColors.blushGold : withAlpha(AppColors.blushGold, 0.15)}`,
          transition: 'background 200ms, border-color 200ms',
          ...AppTypography.outfitWhite,
          fontSize: 11,
          lineHeight: lineHeight(11),
          fontWeight: selected ? 700 : 500,
          color: selected ? AppColors.petalWhite : withAlpha(AppColors.petalWhite, 0.7),
          whiteSpace: 'nowrap',
          cursor: 'pointer',
        }}
      >
        {label}
      </button>
    </div>
  );
}

/** GlassJar: a rounded glass body, a highlight streak and the lid. */
function GlassJar() {
  return (
    <div style={{ position: 'relative', width: JAR_W, height: JAR_H }}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: withAlpha(AppColors.petalWhite, 0.12),
          border: `2px solid ${withAlpha(AppColors.petalWhite, 0.22)}`,
          borderRadius: '40px 40px 80px 80px',
          boxSizing: 'border-box',
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: 40,
          top: 60,
          width: 20,
          height: 100,
          borderRadius: 10,
          background: withAlpha(AppColors.petalWhite, 0.2),
        }}
      />
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: (JAR_W - JAR_W * 0.6) / 2,
          width: JAR_W * 0.6,
          height: 30,
          borderRadius: 10,
          background: withAlpha(AppColors.roseQuartz, 0.5),
          border: `1px solid ${withAlpha(AppColors.petalWhite, 0.3)}`,
          boxSizing: 'border-box',
        }}
      />
    </div>
  );
}

/** Material 3 FloatingActionButton (theme elevation 0): 56px radius 16, or mini 40px radius 12 in a 48px tap slot. */
function Fab({
  mini = false,
  background,
  label,
  onPressed,
  children,
}: {
  mini?: boolean;
  background: string;
  label: string;
  onPressed: () => void;
  children: ReactNode;
}) {
  const [hovered, setHovered] = useState(false);
  const size = mini ? 40 : 56;
  return (
    <div
      style={{
        width: mini ? 48 : size,
        height: mini ? 48 : size,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <button
        type="button"
        className="bare-button"
        aria-label={label}
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          width: size,
          height: size,
          borderRadius: mini ? 12 : 16,
          background: hovered
            ? `linear-gradient(${withAlpha(mini ? AppColors.velvet : AppColors.petalWhite, 0.08)}, ${withAlpha(mini ? AppColors.velvet : AppColors.petalWhite, 0.08)}), ${background}`
            : background,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
        }}
      >
        {children}
      </button>
    </div>
  );
}
