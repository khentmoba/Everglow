// Port of lib/features/canvas/presentation: canvas_screen.dart,
// canvas_painter.dart, canvas_toolbar.dart and
// lib/shared/widgets/partner_doodle_indicator.dart.
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { useCallback, useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react';
import {
  presenceService,
  isActivelyDoodlingAt,
  isOnlineAt,
  emptyPresence,
  type PresenceStatus,
} from '../../core/services/presence';
import { useAuth } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography, Fonts } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { AlertDialog, TextButton, showDialog } from '../../shared/widgets/Dialogs';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowErrorState } from '../../shared/widgets/EverglowStates';
import { Icon } from '../../shared/widgets/Icon';
import {
  canvasService,
  isTextAnnotation,
  mapCanvasPointToViewport,
  simplifyCanvasPoints,
  type DoodleStroke,
} from './canvasService';

type CanvasTool = 'pen' | 'eraser' | 'text';
const ERASER_RADIUS = 15;

function parseColor(hex: string): string {
  const s = hex.replace('#', '');
  if (/^[0-9a-fA-F]{6}$/.test(s)) return `#${s}`;
  if (/^[0-9a-fA-F]{8}$/.test(s)) {
    const a = parseInt(s.slice(0, 2), 16) / 255;
    return withAlpha(`#${s.slice(2)}`, a);
  }
  return AppColors.roseQuartz;
}

function drawStroke(ctx: CanvasRenderingContext2D, w: number, h: number, stroke: DoodleStroke) {
  if (isTextAnnotation(stroke)) {
    if (stroke.points.length === 0) return;
    const pos = mapCanvasPointToViewport(stroke.points[0].x, stroke.points[0].y, w, h, stroke.canvasAspectRatio);
    const color = parseColor(stroke.color);
    const size = Math.min(48, Math.max(12, stroke.strokeWidth * 5));
    ctx.save();
    ctx.font = `600 ${size}px Roboto, ${Fonts.body}`;
    ctx.textBaseline = 'top';
    ctx.fillStyle = color;
    ctx.shadowColor = withAlpha(color, 0.4);
    ctx.shadowBlur = 4;
    ctx.fillText(stroke.text ?? '', pos.x, pos.y);
    ctx.restore();
    return;
  }
  if (stroke.points.length < 2) return;
  const color = parseColor(stroke.color);
  const pts = stroke.points.map((p) => mapCanvasPointToViewport(p.x, p.y, w, h, stroke.canvasAspectRatio));
  // PointMode.polygon draws each segment on its own, so overlapping round caps
  // darken the translucent shadow at every joint, like Flutter.
  const segments = (width: number, style: string) => {
    ctx.lineWidth = width;
    ctx.strokeStyle = style;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (let i = 1; i < pts.length; i++) {
      ctx.beginPath();
      ctx.moveTo(pts[i - 1].x, pts[i - 1].y);
      ctx.lineTo(pts[i].x, pts[i].y);
      ctx.stroke();
    }
  };
  segments(stroke.strokeWidth * 2.5, withAlpha(color, 0.3));
  segments(stroke.strokeWidth, color);
}

function paintSurface(canvas: HTMLCanvasElement, strokes: DoodleStroke[]) {
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = withAlpha(AppColors.velvet, 0.25);
  ctx.fillRect(0, 0, w, h);
  ctx.fillStyle = withAlpha(AppColors.roseQuartz, 0.22);
  for (let x = 24; x < w; x += 24) {
    for (let y = 24; y < h; y += 24) {
      ctx.beginPath();
      ctx.arc(x, y, 1.1, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  for (const s of strokes) drawStroke(ctx, w, h, s);
}

export function CanvasPage() {
  const auth = useAuth();
  const userId = auth.uid ?? 'unknown';
  const [retry, setRetry] = useState(0);
  const [saved, setSaved] = useState<{ data: DoodleStroke[] | null; error: unknown }>({ data: null, error: null });
  const live = useSource(() => canvasService.getLiveStrokesStream(), [], [] as DoodleStroke[]);
  const [active, setActive] = useState<DoodleStroke | null>(null);
  const activeRef = useRef<DoodleStroke | null>(null);
  const [tool, setTool] = useState<CanvasTool>('pen');
  const [color, setColor] = useState('#FFC0CB');
  const [width, setWidth] = useState(3.0);
  const [session, setSession] = useState<DoodleStroke[]>([]);
  const [redo, setRedo] = useState<DoodleStroke[]>([]);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const lastSync = useRef(0);
  const lastPresence = useRef(0);
  const dragging = useRef(false);

  useEffect(() => {
    setSaved({ data: null, error: null });
    return canvasService.getStrokesStream()({
      data: (data) => setSaved({ data, error: null }),
      error: (error) => setSaved((s) => ({ data: s.data, error })),
    });
  }, [retry]);

  useEffect(() => () => void presenceService.clearDoodling(userId), [userId]);

  const history = saved.data ?? [];
  const othersLive = live.filter((s) => s.userId !== userId);

  useLayoutEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const draw = () => paintSurface(canvas, [...history, ...othersLive, ...(active ? [active] : [])]);
    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(canvas);
    return () => ro.disconnect();
  });

  const bumpPresence = useCallback(() => {
    const now = Date.now();
    if (now - lastPresence.current < 1500) return;
    lastPresence.current = now;
    void presenceService.markDoodling(userId);
  }, [userId]);

  const localPoint = (clientX: number, clientY: number) => {
    const r = canvasRef.current!.getBoundingClientRect();
    return { lx: clientX - r.left, ly: clientY - r.top, w: r.width, h: r.height };
  };

  const erase = (clientX: number, clientY: number) => {
    const { lx, ly, w, h } = localPoint(clientX, clientY);
    for (const stroke of history) {
      for (const p of stroke.points) {
        const sp = mapCanvasPointToViewport(p.x, p.y, w, h, stroke.canvasAspectRatio);
        if ((sp.x - lx) ** 2 + (sp.y - ly) ** 2 < ERASER_RADIUS * ERASER_RADIUS) {
          void canvasService.deleteStroke(stroke.id);
          break;
        }
      }
    }
  };

  const saveText = (text: string, x: number, y: number, aspect: number) => {
    if (text.trim() === '') return;
    const stroke: DoodleStroke = {
      id: '',
      userId,
      color,
      strokeWidth: width,
      canvasAspectRatio: aspect,
      points: [{ x, y }],
      text: text.trim(),
      createdAt: null,
    };
    canvasService
      .saveStroke(stroke)
      .then((s) => {
        setSession((list) => [...list, s]);
        setRedo([]);
      })
      .catch((e) => Logger.e('Canvas: text save failed', e));
  };

  const textTool = (clientX: number, clientY: number) => {
    const { lx, ly, w, h } = localPoint(clientX, clientY);
    const x = lx / w;
    const y = ly / h;
    const aspect = w / h;
    let text = '';
    void showDialog<boolean>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        title={<span style={{ ...AppTypography.cormorantBold, fontSize: 24 }}>Add Text</span>}
        content={
          <input
            autoFocus
            placeholder="Type something..."
            onChange={(e) => (text = e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                saveText(text, x, y, aspect);
                close(true);
              }
            }}
            className="money-input"
            style={
              {
                ...AppTypography.outfitWhite,
                fontSize: 16,
                width: '100%',
                boxSizing: 'border-box',
                padding: '16px 12px',
                background: AppColors.twilight,
                border: 'none',
                outline: 'none',
                borderRadius: 16,
                caretColor: AppColors.deepRose,
                '--hint-color': withAlpha(AppColors.roseQuartz, 0.5),
                '--hint-size': '16px',
              } as CSSProperties
            }
          />
        }
        actions={[
          <TextButton key="cancel" color={AppColors.roseQuartz} onPressed={() => close(false)}>
            Cancel
          </TextButton>,
          <TextButton
            key="add"
            color={AppColors.blushGold}
            style={{ fontWeight: 700 }}
            onPressed={() => {
              saveText(text, x, y, aspect);
              close(true);
            }}
          >
            Add
          </TextButton>,
        ]}
      />
    ));
  };

  const onDown = (e: React.PointerEvent) => {
    if (e.button !== 0) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    dragging.current = true;
    if (tool === 'eraser') erase(e.clientX, e.clientY);
    else if (tool === 'text') textTool(e.clientX, e.clientY);
    else {
      const { lx, ly, w, h } = localPoint(e.clientX, e.clientY);
      const stroke: DoodleStroke = {
        id: '',
        userId,
        color,
        strokeWidth: width,
        canvasAspectRatio: w / h,
        points: [{ x: Math.min(1, Math.max(0, lx / w)), y: Math.min(1, Math.max(0, ly / h)) }],
        createdAt: null,
        text: null,
      };
      activeRef.current = stroke;
      setActive(stroke);
      void canvasService.updateActiveStroke(userId, stroke);
      lastSync.current = Date.now();
    }
    bumpPresence();
  };

  const onMove = (e: React.PointerEvent) => {
    if (!dragging.current) return;
    if (tool === 'eraser') erase(e.clientX, e.clientY);
    else if (activeRef.current) {
      const { lx, ly, w, h } = localPoint(e.clientX, e.clientY);
      const p = { x: Math.min(1, Math.max(0, lx / w)), y: Math.min(1, Math.max(0, ly / h)) };
      const cur = activeRef.current;
      const last = cur.points[cur.points.length - 1];
      if ((p.x - last.x) ** 2 + (p.y - last.y) ** 2 > 0.000001) {
        const next = { ...cur, points: [...cur.points, p] };
        activeRef.current = next;
        setActive(next);
        const now = Date.now();
        if (now - lastSync.current > 250) {
          void canvasService.updateActiveStroke(userId, next);
          lastSync.current = now;
        }
      }
    }
    bumpPresence();
  };

  const onUp = () => {
    dragging.current = false;
    const cur = activeRef.current;
    if (!cur) return;
    void canvasService.clearActiveStroke(userId);
    if (cur.points.length >= 2) {
      canvasService
        .saveStroke({ ...cur, points: simplifyCanvasPoints(cur.points) })
        .then((s) => {
          setSession((list) => [...list, s]);
          setRedo([]);
        })
        .catch((e) => Logger.e('Canvas: stroke save failed', e));
    }
    activeRef.current = null;
    setActive(null);
  };

  const undo = async () => {
    const last = session[session.length - 1];
    if (!last) return;
    setSession((l) => l.slice(0, -1));
    try {
      await canvasService.deleteStroke(last.id);
      setRedo((r) => [...r, last]);
    } catch (e) {
      setSession((l) => [...l, last]);
      Logger.e('Canvas: undo failed to remove stroke', e);
    }
  };

  const redoLast = async () => {
    const s = redo[redo.length - 1];
    if (!s) return;
    setRedo((r) => r.slice(0, -1));
    try {
      const out = await canvasService.saveStroke(s);
      setSession((l) => [...l, out]);
    } catch (e) {
      setRedo((r) => [...r, s]);
      Logger.e('Canvas: redo failed to save stroke', e);
    }
  };

  const confirmClear = () =>
    void showDialog<void>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        title={<span style={{ ...AppTypography.cormorantBold, fontSize: 22 }}>Clear Canvas?</span>}
        content={
          <span
            style={{
              ...AppTypography.outfitWhite,
              fontSize: 14,
              lineHeight: lineHeight(14),
              color: withAlpha(AppColors.petalWhite, 0.8),
            }}
          >
            This will permanently delete all doodles for everyone. Are you sure?
          </span>
        }
        actions={[
          <TextButton key="cancel" color={withAlpha(AppColors.roseQuartz, 0.6)} onPressed={() => close(null)}>
            Cancel
          </TextButton>,
          <TextButton
            key="clear"
            color={AppColors.error}
            style={{ fontWeight: 700 }}
            onPressed={() => {
              void canvasService.clearAllStrokes();
              close(null);
            }}
          >
            Clear
          </TextButton>,
        ]}
      />
    ));

  const isLoading = saved.data == null;
  return (
    <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep, display: 'flex', flexDirection: 'column' }}>
      <div style={{ paddingTop: 'env(safe-area-inset-top)', flexShrink: 0 }}>
        <EverglowFeatureHeader
          title="Everglow Canvas"
          subtitle="draw something together"
          icon="brush"
          hue={AppColors.softLavender}
        />
      </div>
      <div style={{ position: 'relative', flex: 1, minHeight: 0, overflow: 'hidden' }}>
        <EverglowBackground
          baseColor={AppColors.inkDeep}
          glows={[
            { color: AppColors.softLavender, alignment: [-0.7, -0.9], size: 0.9, opacity: 0.14 },
            { color: AppColors.auroraTeal, alignment: [0.9, 0.8], size: 0.7, opacity: 0.08 },
          ]}
        />
        {saved.error != null ? (
          <div style={{ position: 'absolute', inset: 0 }}>
            <EverglowErrorState
              message={`Could not load canvas: ${String(saved.error)}`}
              onRetry={() => setRetry((r) => r + 1)}
              icon="brush_outlined"
            />
          </div>
        ) : (
          <>
            <canvas ref={canvasRef} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} />
            {isLoading && (
              <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <CircularProgress size={36} strokeWidth={2} color={AppColors.roseQuartz} />
              </div>
            )}
            {!isLoading && history.length + othersLive.length === 0 && active == null && (
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  paddingBottom: 96,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 10,
                  pointerEvents: 'none',
                }}
              >
                <div
                  style={{
                    width: 96,
                    height: 96,
                    borderRadius: '50%',
                    border: `2px dashed ${withAlpha(AppColors.softLavender, 0.45)}`,
                    background: `radial-gradient(circle, ${withAlpha(AppColors.softLavender, 0.18)}, transparent 70%)`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Icon name="brush" size={40} color={AppColors.softLavender} />
                </div>
                <span
                  style={{
                    ...AppTypography.cormorantRegular,
                    fontSize: 28,
                    letterSpacing: 1.2,
                    fontWeight: 600,
                    lineHeight: lineHeight(28),
                  }}
                >
                  Draw something together
                </span>
                <span style={{ ...AppTypography.handwrittenBody, fontSize: 19, color: withAlpha(AppColors.roseQuartz, 0.8) }}>
                  pick a colour below and start anywhere
                </span>
              </div>
            )}
          </>
        )}
        <div
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
          style={{ position: 'absolute', inset: 0, touchAction: 'none', userSelect: 'none' }}
        />
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            display: 'flex',
            justifyContent: 'center',
            pointerEvents: 'none',
          }}
        >
          <CanvasToolbar
            activeTool={tool}
            activeColor={color}
            strokeWidth={width}
            onToolChanged={setTool}
            onColorChanged={setColor}
            onStrokeWidthChanged={setWidth}
            onClear={confirmClear}
            onUndo={undo}
            onRedo={redoLast}
            canUndo={session.length > 0}
            canRedo={redo.length > 0}
          />
        </div>
        <div
          style={{
            position: 'absolute',
            top: 8,
            left: 0,
            right: 0,
            display: 'flex',
            justifyContent: 'center',
            pointerEvents: 'none',
          }}
        >
          <PartnerDoodleIndicator />
        </div>
      </div>
    </div>
  );
}

const PALETTE: [string, string][] = [
  ['#FFC0CB', 'Pink'],
  ['#B0E0E6', 'Powder Blue'],
  ['#FFFACD', 'Lemon Chiffon'],
  ['#98FB98', 'Pale Green'],
  ['#E6E6FA', 'Lavender'],
];

function CanvasToolbar(p: {
  activeTool: CanvasTool;
  activeColor: string;
  strokeWidth: number;
  onToolChanged: (t: CanvasTool) => void;
  onColorChanged: (c: string) => void;
  onStrokeWidthChanged: (w: number) => void;
  onClear: () => void;
  onUndo: () => void;
  onRedo: () => void;
  canUndo: boolean;
  canRedo: boolean;
}) {
  const muted = withAlpha(AppColors.petalWhite, 0.2);
  return (
    <div style={{ padding: '0 16px 32px', maxWidth: '100%', boxSizing: 'border-box', pointerEvents: 'auto' }}>
      <div
        style={{
          padding: '9.5px 13.5px',
          background: withAlpha(AppColors.velvet, 0.85),
          borderRadius: 32,
          boxShadow: `inset 0 0 0 1.5px ${withAlpha(AppColors.moonlight, 0.18)}`,
        }}
      >
        <div className="no-scrollbar" style={{ overflowX: 'auto', overflowY: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', width: 'max-content' }}>
            <ToolButton icon="edit" active={p.activeTool === 'pen'} onTap={() => p.onToolChanged('pen')} label="Pen tool" />
            <ToolButton
              icon="auto_fix_normal"
              active={p.activeTool === 'eraser'}
              onTap={() => p.onToolChanged('eraser')}
              label="Eraser tool"
            />
            <ToolButton
              icon="text_fields"
              active={p.activeTool === 'text'}
              onTap={() => p.onToolChanged('text')}
              label="Text tool"
            />
            <Divider />
            <ToolButton icon="undo" onTap={p.onUndo} color={p.canUndo ? AppColors.roseQuartz : muted} label="Undo" />
            <ToolButton icon="redo" onTap={p.onRedo} color={p.canRedo ? AppColors.roseQuartz : muted} label="Redo" />
            <Divider />
            {PALETTE.map(([hex, name]) => {
              const on = p.activeColor === hex && p.activeTool === 'pen';
              return (
                <button
                  key={hex}
                  type="button"
                  className="bare-button"
                  aria-label={`${name} color`}
                  onClick={() => {
                    p.onToolChanged('pen');
                    p.onColorChanged(hex);
                  }}
                  style={{
                    width: 28,
                    height: 28,
                    margin: '0 6px',
                    borderRadius: '50%',
                    background: hex,
                    boxShadow: [
                      `inset 0 0 0 ${on ? 2.5 : 2}px ${on ? AppColors.roseQuartz : 'transparent'}`,
                      on ? `0 0 10px 2px ${withAlpha(hex, 0.6)}` : '',
                    ]
                      .filter(Boolean)
                      .join(', '),
                    transition: 'box-shadow 200ms',
                    flexShrink: 0,
                  }}
                />
              );
            })}
            <Divider />
            <WidthSlider value={p.strokeWidth} onChange={p.onStrokeWidthChanged} />
            <Divider />
            <ToolButton icon="delete_outline" onTap={p.onClear} color={withAlpha(AppColors.error, 0.8)} label="Clear canvas" />
          </div>
        </div>
      </div>
    </div>
  );
}

function Divider() {
  return (
    <div style={{ width: 1, height: 24, margin: '0 8px', background: withAlpha(AppColors.moonlight, 0.1), flexShrink: 0 }} />
  );
}

function ToolButton({
  icon,
  active = false,
  onTap,
  color,
  label,
}: {
  icon: string;
  active?: boolean;
  onTap: () => void;
  color?: string;
  label: string;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      aria-label={label}
      onClick={onTap}
      style={{
        padding: 10,
        margin: '0 4px',
        borderRadius: '50%',
        background: active ? withAlpha(AppColors.deepRose, 0.2) : 'transparent',
        transition: 'background 200ms',
        display: 'flex',
        flexShrink: 0,
      }}
    >
      <Icon name={icon} size={24} color={active ? AppColors.roseQuartz : (color ?? withAlpha(AppColors.petalWhite, 0.6))} />
    </button>
  );
}

/** Material 3 (2023) Slider in an 80x48 box: 24px overlay inset, 3px track (active 5px), 6px thumb. */
function WidthSlider({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  const min = 1;
  const max = 12;
  const t = (value - min) / (max - min);
  const left = 24;
  const trackW = 80 - 48;
  const x = left + t * trackW;
  return (
    <div style={{ position: 'relative', width: 80, height: 48, flexShrink: 0 }} aria-label={`Stroke width: ${Math.round(value)}`}>
      <div
        style={{
          position: 'absolute',
          left: x,
          right: 24,
          top: 22.5,
          height: 3,
          borderRadius: '0 1.5px 1.5px 0',
          background: withAlpha(AppColors.moonlight, 0.15),
        }}
      />
      <div
        style={{
          position: 'absolute',
          left,
          width: x - left,
          top: 21.5,
          height: 5,
          borderRadius: '2.5px 0 0 2.5px',
          background: AppColors.roseQuartz,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: x - 6,
          top: 18,
          width: 12,
          height: 12,
          borderRadius: '50%',
          background: AppColors.blushGold,
          boxShadow: '0 1px 2px rgba(0,0,0,0.3)',
        }}
      />
      <input
        type="range"
        min={min}
        max={max}
        step="any"
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', margin: 0, opacity: 0, cursor: 'pointer' }}
      />
    </div>
  );
}

function formatElapsed(ms: number) {
  const s = Math.floor(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  const r = s % 60;
  return r === 0 ? `${m}m` : `${m}m ${r}s`;
}

function PartnerDoodleIndicator() {
  const auth = useAuth();
  const partnerUid = auth.partnerUid;
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);
  const status = useSource<PresenceStatus | null>(
    () => (partnerUid ? presenceService.watchPresence(partnerUid) : null),
    [partnerUid],
    null,
  );
  if (!partnerUid) return null;
  const s = status ?? emptyPresence(partnerUid);
  const doodling = isActivelyDoodlingAt(s, now);
  if (!doodling && !isOnlineAt(s, now)) return null;
  const accent = doodling ? AppColors.warmAmber : withAlpha(AppColors.roseQuartz, 0.7);
  const accentBase = doodling ? AppColors.warmAmber : AppColors.roseQuartz;
  const dot = doodling ? AppColors.warmAmber : AppColors.success;
  return (
    <div
      style={{
        padding: '8px 14px',
        background: withAlpha(AppColors.velvet, 0.78),
        borderRadius: 20,
        border: `1px solid ${withAlpha(accentBase, 0.4)}`,
        boxShadow: doodling ? `0 0 14px 1px ${withAlpha(accentBase, 0.25)}` : undefined,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <div style={{ width: 10, height: 10, borderRadius: '50%', background: dot, boxShadow: `0 0 8px ${withAlpha(dot, 0.4)}` }} />
      <div style={{ width: 8 }} />
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 12, lineHeight: lineHeight(12) }}>
            {doodling ? `${auth.partnerName} is doodling` : 'Not active doodling'}
          </span>
          {doodling && (
            <>
              <div style={{ width: 6 }} />
              <span style={{ ...AppTypography.outfitWhite, fontSize: 12, lineHeight: lineHeight(12) }}>✨</span>
              <div style={{ width: 4 }} />
              <span
                style={{
                  ...AppTypography.outfitHeading,
                  fontSize: 12,
                  lineHeight: lineHeight(12),
                  color: accent,
                  fontVariantNumeric: 'tabular-nums',
                }}
              >
                {formatElapsed(s.lastDoodleAt ? now - s.lastDoodleAt.getTime() : 0)}
              </span>
            </>
          )}
        </div>
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 9,
            lineHeight: lineHeight(9),
            letterSpacing: doodling ? 0.8 : 0.6,
            color: withAlpha(AppColors.petalWhite, doodling ? 0.75 : 0.7),
          }}
        >
          {doodling ? 'active doodle' : 'not active doodling'}
        </span>
      </div>
    </div>
  );
}
