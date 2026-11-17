// Port of lib/features/dashboard/presentation/widgets/note_dialog.dart, opened the
// way letterbox_view.dart and letterbox_archive_screen.dart open it.
import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { Curves, motionReduced, orZero } from '../../core/theme/motion';
import { Align, boxShadow, letterSpacing, linear, lineHeight, mixedLineHeight, radial, shadowLayer, sigma } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useViewport } from '../../core/system/viewport';
import { showDialog } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import type { HiddenNote } from './letterboxService';

const MONTHS = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/** `showGeneralDialog` with a 400ms easeOutBack scale and fade over a black 50% barrier. */
export function showNoteDialog(note: HiddenNote): Promise<void> {
  return showDialog<void>((close) => <NoteDialog note={note} close={() => close(null)} />, {
    insetPadding: '24px 20px',
    barrierColor: 'rgba(0,0,0,0.5)',
    fadeMs: 400,
  }).then(() => undefined);
}

const textShadow = (color: string, blur: number, y: number) => `0 ${y}px ${(2 * sigma(blur)).toFixed(2)}px ${color}`;

function NoteDialog({ note, close }: { note: HiddenNote; close: () => void }) {
  const { height } = useViewport();
  const [entered, setEntered] = useState(false);
  useEffect(() => {
    const raf = requestAnimationFrame(() => setEntered(true));
    return () => cancelAnimationFrame(raf);
  }, []);
  const d = note.unlockDate;
  const dateString = `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
  const isShort = note.content.length <= 90 && !note.content.includes('\n');
  const [toast, setToast] = useState(false);
  const toastTimer = useRef(0);
  useEffect(() => () => window.clearTimeout(toastTimer.current), []);
  const onSeal = () => {
    if (motionReduced()) return;
    setToast(true);
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(false), 1600);
  };

  return (
    // The Dialog's own Material fills the inset area (its child is a Center), so the
    // theme's dialog border is drawn around the whole area, well outside the card.
    <div
      style={{
        alignSelf: 'stretch',
        width: '100%',
        minWidth: 280,
        boxSizing: 'border-box',
        borderRadius: AppRadius.x2,
        boxShadow: `inset 0 0 0 1px ${Derived.border}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        transform: `scale(${entered ? 1 : 0})`,
        opacity: entered ? 1 : 0,
        transition: `transform ${orZero(400)}ms cubic-bezier(0.175, 0.885, 0.32, 1.275), opacity ${orZero(400)}ms linear`,
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: 480,
          maxHeight: '100%',
          position: 'relative',
          borderRadius: 28,
          background: linear(['#381E3E', AppColors.velvet, AppColors.inkDeep], {
            begin: Align.topLeft,
            end: Align.bottomRight,
            stops: [0, 0.45, 1],
          }),
          boxShadow: [
            boxShadow([
              { color: withAlpha(AppColors.inkDeep, 0.8), blur: 40, offset: [0, 20] },
              { color: withAlpha(AppColors.deepRose, 0.25), blur: 28, spread: 2 },
              { color: withAlpha(AppColors.auroraGold, 0.12), blur: 16, offset: [0, 2] },
            ]),
            `inset 0 0 0 1.2px ${withAlpha(AppColors.blushGold, 0.35)}`,
          ].join(', '),
        }}
      >
        <div style={{ position: 'relative', borderRadius: 28, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          <StationeryBorder />
          <EnvelopeHeader onSeal={onSeal} close={close} />
          <SealToast shown={toast} />
          <div
            className="no-scrollbar"
            style={{
              maxHeight: height * 0.58,
              overflowY: 'auto',
              padding: '10px 20px 14px',
              display: 'flex',
              flexDirection: 'column',
              position: 'relative',
            }}
          >
            <div
              style={{
                alignSelf: 'center',
                maxWidth: '100%',
                boxSizing: 'border-box',
                padding: '4px 12px',
                borderRadius: 16,
                background: withAlpha(AppColors.inkDeep, 0.45),
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.25)}`,
                display: 'flex',
                alignItems: 'center',
              }}
            >
              <Icon name="auto_awesome" size={10} color={AppColors.auroraGold} />
              <div style={{ width: 5, flexShrink: 0 }} />
              <span
                style={{
                  ...AppTypography.outfitBold,
                  fontSize: 9.5,
                  lineHeight: lineHeight(9.5),
                  ...letterSpacing(0.8),
                  color: withAlpha(AppColors.blushGold, 0.85),
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {dateString.toUpperCase()}
              </span>
            </div>
            <div style={{ height: 18, flexShrink: 0 }} />
            <div
              style={{
                ...AppTypography.handwrittenTitle,
                fontSize: 32,
                lineHeight: (/\p{Extended_Pictographic}/u.test(note.title) ? mixedLineHeight : lineHeight)(32, 1.2),
                color: AppColors.blushGold,
                textAlign: 'center',
                textShadow: textShadow(withAlpha(AppColors.inkDeep, 0.9), 6, 2),
              }}
            >
              {note.title.length > 0 ? note.title : 'A Secret Letter'}
            </div>
            <div style={{ height: 12, flexShrink: 0 }} />
            <FlourishDivider />
            <div style={{ height: 20, flexShrink: 0 }} />
            <div
              style={{
                ...AppTypography.handwrittenBody,
                fontSize: isShort ? 28 : 22,
                lineHeight: lineHeight(isShort ? 28 : 22, 1.5),
                color: withAlpha(AppColors.petalWhite, 0.95),
                textAlign: isShort ? 'center' : 'start',
                whiteSpace: 'pre-wrap',
                overflowWrap: 'break-word',
              }}
            >
              {note.content}
            </div>
            <div style={{ height: 28, flexShrink: 0 }} />
            <SignOff isShort={isShort} />
          </div>
          <Footer close={close} />
        </div>
      </div>
    </div>
  );
}

function EnvelopeHeader({ onSeal, close }: { onSeal: () => void; close: () => void }) {
  const seal = useRef<HTMLDivElement>(null);
  const pulse = () => {
    onSeal();
    if (motionReduced() || !seal.current) return;
    // TweenSequence: 1 → 1.25 easeOut (40%), then 1.25 → 1 bounceOut (60%), 360ms.
    const frames: Keyframe[] = [];
    for (let i = 0; i <= 36; i++) {
      const t = i / 36;
      const s = t < 0.4 ? 1 + 0.25 * Curves.easeOut(t / 0.4) : 1.25 - 0.25 * Curves.bounceOut((t - 0.4) / 0.6);
      frames.push({ transform: `scale(${s})`, offset: t });
    }
    seal.current.animate(frames, { duration: 360 });
  };
  return (
    <div
      style={{
        position: 'relative',
        height: 62,
        flexShrink: 0,
        background: withAlpha(AppColors.twilight, 0.65),
        boxShadow: `inset 0 -1px 0 ${withAlpha(AppColors.blushGold, 0.15)}`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <FlapLine side="left" />
      <FlapLine side="right" />
      <div style={{ position: 'absolute', left: 18, display: 'flex', alignItems: 'center' }}>
        <Icon name="favorite" size={13} color={AppColors.auroraRose} />
        <div style={{ width: 6 }} />
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 10,
            lineHeight: lineHeight(10),
            ...letterSpacing(1.6),
            color: withAlpha(AppColors.blushGold, 0.8),
          }}
        >
          LETTERBOX
        </span>
      </div>
      <Tooltip message="Sealed with love">
        <div
          ref={seal}
          role="button"
          tabIndex={0}
          aria-label="Sealed with love"
          onClick={pulse}
          onKeyDown={(e) => e.key === 'Enter' && pulse()}
          style={{
            width: 44,
            height: 44,
            borderRadius: '50%',
            background: radial([AppColors.auroraRose, AppColors.deepRose, AppColors.roseDark], {
              center: [-0.25, -0.3],
              radius: 0.85,
              size: [44, 44],
            }),
            boxShadow: [
              `inset 0 0 0 1.5px ${withAlpha(AppColors.blushGold, 0.65)}`,
              boxShadow([
                { color: withAlpha(AppColors.deepRose, 0.5), blur: 10, offset: [0, 3] },
                { color: 'rgba(0,0,0,0.4)', blur: 6, offset: [0, 2] },
              ]),
            ].join(', '),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: '50%',
              background: withAlpha(AppColors.rosePressed, 0.5),
              boxShadow: `inset 0 0 0 0.8px ${withAlpha(AppColors.blushGold, 0.3)}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              textShadow: textShadow('rgba(0,0,0,0.54)', 2.5, 1.2),
            }}
          >
            <Icon name="favorite" size={18} color={AppColors.blushGold} />
          </div>
        </div>
      </Tooltip>
      <button
        type="button"
        className="bare-button"
        aria-label="Close"
        onClick={close}
        style={{
          position: 'absolute',
          right: 14,
          width: 32,
          height: 32,
          borderRadius: '50%',
          background: withAlpha(AppColors.moonlight, 0.08),
          boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.moonlight, 0.15)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: 'pointer',
        }}
      >
        <Icon name="close" size={16} color={AppColors.roseQuartz} />
      </button>
    </div>
  );
}

/** `_EnvelopeFlapPainter`: a 1px line from each top corner to 24px beside the middle. */
function FlapLine({ side }: { side: 'left' | 'right' }) {
  const left = side === 'left';
  return (
    <svg
      aria-hidden
      style={{ position: 'absolute', top: 0, [side]: 0, width: 'calc(50% - 24px)', height: 31, overflow: 'visible' }}
    >
      <line
        x1={left ? '0' : '100%'}
        y1="0"
        x2={left ? '100%' : '0'}
        y2="100%"
        stroke={withAlpha(AppColors.blushGold, 0.16)}
        strokeWidth={1}
      />
    </svg>
  );
}

function SealToast({ shown }: { shown: boolean }) {
  const ms = 250;
  return (
    <div
      style={{
        flexShrink: 0,
        height: shown ? 28 : 0,
        marginTop: shown ? 4 : 0,
        opacity: shown ? 1 : 0,
        overflow: 'hidden',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        transition: `height ${ms}ms linear, margin-top ${ms}ms linear, opacity ${ms}ms linear`,
      }}
    >
      <div
        style={{
          padding: '3px 12px',
          borderRadius: 12,
          background: linear([AppColors.deepRose, AppColors.auroraRose]),
          boxShadow: boxShadow([{ color: withAlpha(AppColors.deepRose, 0.4), blur: 8, offset: [0, 2] }]),
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <Icon name="favorite" size={11} color={AppColors.petalWhite} />
        <div style={{ width: 5 }} />
        <span
          style={{
            ...AppTypography.outfitBold,
            fontSize: 10.5,
            lineHeight: lineHeight(10.5),
            ...letterSpacing(0.4),
            color: AppColors.petalWhite,
            whiteSpace: 'nowrap',
          }}
        >
          Sealed with love for Clair
        </span>
      </div>
    </div>
  );
}

function FlourishDivider() {
  const rule = (dir: 'to right' | 'to left'): CSSProperties => ({
    width: 44,
    height: 1,
    background: `linear-gradient(${dir}, transparent, ${withAlpha(AppColors.blushGold, 0.4)})`,
  });
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={rule('to right')} />
      <div style={{ width: 8 }} />
      <Icon name="favorite" size={9} color={withAlpha(AppColors.auroraRose, 0.75)} />
      <div style={{ width: 8 }} />
      <div style={rule('to left')} />
    </div>
  );
}

function SignOff({ isShort }: { isShort: boolean }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: isShort ? 'center' : 'flex-end' }}>
      <span
        style={{
          ...AppTypography.handwrittenTitle,
          fontSize: 22,
          lineHeight: lineHeight(22),
          fontStyle: 'italic',
          color: withAlpha(AppColors.softLavender, 0.85),
        }}
      >
        Forever &amp; always,
      </span>
      <div style={{ height: 4 }} />
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <span
          style={{
            ...AppTypography.outfitMedium,
            fontSize: 11.5,
            lineHeight: lineHeight(11.5),
            ...letterSpacing(0.6),
            color: withAlpha(AppColors.blushGold, 0.8),
          }}
        >
          With all my love
        </span>
        <div style={{ width: 6 }} />
        <Icon name="favorite" size={13} color={AppColors.auroraRose} />
      </div>
    </div>
  );
}

function Footer({ close }: { close: () => void }) {
  return (
    <div style={{ padding: '4px 16px 16px', display: 'flex', justifyContent: 'center', flexShrink: 0, position: 'relative' }}>
      <div style={{ position: 'relative', maxWidth: '100%' }}>
        <div
          aria-hidden
          style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.15), blur: 10, offset: [0, 3] }, { radius: 24 })}
        />
        <button
          type="button"
          className="bare-button"
          onClick={close}
          style={{
            position: 'relative',
            maxWidth: '100%',
            // Container adds its 1px border to the padding.
            padding: '9px 19px',
            borderRadius: 24,
            background: linear([withAlpha(AppColors.deepRose, 0.28), withAlpha(AppColors.plum, 0.38)]),
            boxShadow: `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.3)}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <Icon name="favorite_outline" size={14} color={AppColors.blushGold} />
          <div style={{ width: 6, flexShrink: 0 }} />
          <span
            style={{
              ...AppTypography.outfitBold,
              fontSize: 12,
              lineHeight: lineHeight(12),
              ...letterSpacing(0.3),
              color: AppColors.petalWhite,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}
          >
            Keep close to heart
          </span>
        </button>
      </div>
    </div>
  );
}

/** `_StationeryBorderPainter`: an inset frame, corner brackets and four small sparkles. */
function StationeryBorder() {
  const frame = withAlpha(AppColors.blushGold, 0.12);
  const fl = withAlpha(AppColors.blushGold, 0.22);
  const star = withAlpha(AppColors.blushGold, 0.24);
  const o = 18;
  const len = 14;
  const sparkle = (cx: string, cy: string, key: string) => (
    <svg
      key={key}
      aria-hidden
      width="9"
      height="9"
      viewBox="-4.5 -4.5 9 9"
      style={{ position: 'absolute', left: cx, top: cy, marginLeft: -4.5, marginTop: -4.5, overflow: 'visible' }}
    >
      <path d="M0,-4.5 Q0,0 4.5,0 Q0,0 0,4.5 Q0,0 -4.5,0 Q0,0 0,-4.5 Z" fill={star} />
    </svg>
  );
  const corner = (v: 'top' | 'bottom', h: 'left' | 'right') => (
    <div
      key={v + h}
      aria-hidden
      style={{
        position: 'absolute',
        [v]: o - 0.6,
        [h]: o - 0.6,
        width: len + 1.2,
        height: len + 1.2,
        boxSizing: 'border-box',
        [`border${v === 'top' ? 'Top' : 'Bottom'}`]: `1.2px solid ${fl}`,
        [`border${h === 'left' ? 'Left' : 'Right'}`]: `1.2px solid ${fl}`,
        borderRadius: 0,
      }}
    />
  );
  return (
    <div aria-hidden style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
      <div
        style={{
          position: 'absolute',
          inset: 9.5,
          borderRadius: 20.5,
          border: `1px solid ${frame}`,
        }}
      />
      {corner('top', 'left')}
      {corner('top', 'right')}
      {corner('bottom', 'left')}
      {corner('bottom', 'right')}
      {sparkle(`${o + 14}px`, `${o + 14}px`, 'tl')}
      {sparkle(`calc(100% - ${o + 14}px)`, `${o + 14}px`, 'tr')}
      {sparkle(`${o + 14}px`, `calc(100% - ${o + 14}px)`, 'bl')}
      {sparkle(`calc(100% - ${o + 14}px)`, `calc(100% - ${o + 14}px)`, 'br')}
    </div>
  );
}
