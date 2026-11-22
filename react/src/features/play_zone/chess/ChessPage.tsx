// Port of chess_game_screen.dart + chess_game_widgets.dart (the look; rules live in chessGame.ts).
import { useEffect, useReducer, useState, type CSSProperties, type ReactNode } from 'react';
import { useController } from '../../../core/anim/controller';
import { useViewport } from '../../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../../core/theme/colors';
import { AppRadius } from '../../../core/theme/layout';
import { boxShadow, insetBorder, letterSpacing, lineHeight, shadowLayer, type BoxShadow } from '../../../core/theme/paint';
import { AppTypography } from '../../../core/theme/typography';
import { AlertDialog, TextButton, showDialog } from '../../../shared/widgets/Dialogs';
import { EverglowBackground } from '../../../shared/widgets/EverglowBackground';
import { EverglowFeatureHeader } from '../../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../../shared/widgets/Icon';
import { showSnackBar } from '../../../shared/widgets/SnackBar';
import { Tooltip } from '../../../shared/widgets/Tooltip';
import { usePlayZoneBack } from '../table_tennis/TTFrame';
import { ChessGame, isWhitePiece, material, pieceGlyph, toPgn } from './chessGame';

const E2: BoxShadow[] = [{ blur: 16, offset: [0, 6], color: 'rgba(0,0,0,0.25)' }];
const E3: BoxShadow[] = [{ blur: 24, offset: [0, 10], color: 'rgba(0,0,0,0.3)' }];
const E4: BoxShadow[] = [{ blur: 32, offset: [0, 14], color: 'rgba(0,0,0,0.35)' }];
const GLOW_ROSE: BoxShadow[] = [...E2, { blur: 16, color: withAlpha(AppColors.deepRose, 0.35) }];
const WARNING = AppColors.warmAmber;
const LIGHT_SQ = '#F0D9B5';
const DARK_SQ = '#B58863';
const INK = '#2B2B2B';

const text = (size: number, weight: number, color: string, extra: CSSProperties = {}): CSSProperties => ({
  ...AppTypography.outfitWhite,
  fontSize: size,
  fontWeight: weight,
  color,
  ...extra,
});

/** Shadows painted under a see-through box, as Flutter does. */
function Shadowed({
  shadows,
  radius,
  style,
  children,
}: {
  shadows: BoxShadow[];
  radius: number | string;
  style?: CSSProperties;
  children: ReactNode;
}) {
  return (
    <div style={{ position: 'relative', ...style }}>
      {shadows.map((s, i) => (
        <div key={i} aria-hidden style={shadowLayer(s, { radius })} />
      ))}
      <div style={{ position: 'relative', height: '100%' }}>{children}</div>
    </div>
  );
}

export function ChessPage() {
  const back = usePlayZoneBack();
  const [game] = useState(() => new ChessGame());
  const [, rerender] = useReducer((n: number) => n + 1, 0);
  const pulse = useController(900);
  const { width } = useViewport();
  const isWide = width >= 860;

  useEffect(() => {
    if (game.isCheck) pulse.repeat({ reverse: true });
    else {
      pulse.stop();
      pulse.value = 0;
    }
  });

  const update = (fn: () => unknown) => {
    fn();
    rerender();
  };
  const flip = () => update(() => (game.flipped = !game.flipped));
  const reset = () => update(() => game.reset());

  const confirmReset = () => {
    if (game.sanHistory.length === 0 && game.undoStack.length === 0) return reset();
    void showDialog<void>((close) => (
      <AlertDialog
        background={AppColors.velvet}
        radius={AppRadius.x2}
        borderColor={withAlpha(AppColors.moonlight, 0.12)}
        title={<span style={{ ...AppTypography.cormorantBold, color: AppColors.petalWhite, fontSize: 20 }}>New game?</span>}
        content={<span style={text(13, 500, Derived.textMedium)}>Current position will be lost. Start fresh?</span>}
        actions={[
          <TextButton key="cancel" onPressed={() => close(null)} color={Derived.textMuted} style={{ fontWeight: 500 }}>
            Cancel
          </TextButton>,
          <FilledButton
            key="new"
            onPressed={() => {
              close(null);
              reset();
            }}
          >
            New game
          </FilledButton>,
        ]}
      />
    ));
  };

  const mW = material(game.capturedByWhite);
  const mB = material(game.capturedByBlack);
  const f = game.flipped;
  const topBar = (
    <PlayerBar
      label={f ? 'White • Khent' : 'Black • Clair'}
      isWhite={f}
      isTurn={(game.turn === 'w') === f}
      captured={f ? game.capturedByWhite : game.capturedByBlack}
      materialDiff={f ? mW - mB : mB - mW}
    />
  );
  const bottomBar = (
    <PlayerBar
      label={f ? 'Black • Clair' : 'White • Khent'}
      isWhite={!f}
      isTurn={(game.turn === 'w') !== f}
      captured={f ? game.capturedByBlack : game.capturedByWhite}
      materialDiff={f ? mB - mW : mW - mB}
    />
  );
  const board = <BoardSection game={game} pulse={pulse.value} onTap={(sq) => update(() => game.tap(sq))} />;
  const side = (
    <SidePanel
      game={game}
      materialWhite={mW}
      materialBlack={mB}
      onUndo={() => update(() => game.undo())}
      onReset={confirmReset}
      onFlip={flip}
    />
  );

  return (
    <div style={{ position: 'fixed', inset: 0 }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.blushGold, alignment: [-0.6, -0.85], size: 0.85, opacity: 0.1 },
          { color: AppColors.softLavender, alignment: [0.85, 0.9], size: 0.7, opacity: 0.07 },
        ]}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          padding:
            'env(safe-area-inset-top, 0px) env(safe-area-inset-right, 0px) env(safe-area-inset-bottom, 0px) env(safe-area-inset-left, 0px)',
          display: 'flex',
          flexDirection: 'column',
          willChange: 'transform',
        }}
      >
        <EverglowFeatureHeader
          title="Couple Chess"
          subtitle="Lila • synced via Firestore • Dusk Petal edition"
          icon="grid_on"
          hue={AppColors.blushGold}
          onBack={back}
          actions={[
            <HeaderIcon key="flip" icon="swap_vert" tooltip="Flip board" onTap={flip} />,
            <HeaderIcon key="new" icon="restart_alt" tooltip="New game" onTap={confirmReset} />,
          ]}
        />
        <StatusBar game={game} pulse={pulse.value} />
        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          {isWide ? (
            <div style={{ flex: 1, minHeight: 0, padding: '8px 16px 12px', display: 'flex', alignItems: 'flex-start' }}>
              <div
                style={{ flex: 1, minWidth: 0, height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
              >
                <div style={{ width: '100%', maxWidth: 640, display: 'flex', flexDirection: 'column' }}>
                  {topBar}
                  <div style={{ height: 8 }} />
                  <div style={{ aspectRatio: '1' }}>{board}</div>
                  <div style={{ height: 8 }} />
                  {bottomBar}
                </div>
              </div>
              <div style={{ width: 16 }} />
              <div className="no-scrollbar" style={{ width: 360, maxHeight: '100%', overflowY: 'auto', flexShrink: 0 }}>
                {side}
              </div>
            </div>
          ) : (
            <div className="no-scrollbar" style={{ flex: 1, minHeight: 0, overflowY: 'auto' }}>
              <div style={{ padding: '6px 12px 12px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div style={{ alignSelf: 'stretch' }}>{topBar}</div>
                <div style={{ height: 8 }} />
                <div style={{ width: '100%', maxWidth: 560, aspectRatio: '1' }}>{board}</div>
                <div style={{ height: 8 }} />
                <div style={{ alignSelf: 'stretch' }}>{bottomBar}</div>
                <div style={{ height: 14 }} />
                <div style={{ alignSelf: 'stretch' }}>{side}</div>
              </div>
            </div>
          )}
        </div>
      </div>
      {game.promotionFrom != null && (
        <PromotionSheet
          isWhite={isWhitePiece(game.board.get(game.promotionFrom) ?? 'P')}
          onPick={(c) => update(() => game.pickPromotion(c))}
        />
      )}
      {(game.isCheckmate || game.isStalemate) && (
        <GameOverOverlay isMate={game.isCheckmate} turn={game.turn} onNewGame={reset} onBack={back} />
      )}
    </div>
  );
}

function FilledButton({ onPressed, children }: { onPressed: () => void; children: ReactNode }) {
  return (
    <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
      <button
        type="button"
        className="bare-button"
        onClick={onPressed}
        style={{ height: 40, padding: '0 24px', borderRadius: AppRadius.full, background: AppColors.deepRose, cursor: 'pointer' }}
      >
        <span
          style={{ ...AppTypography.labelLarge, ...AppTypography.outfitBold, fontSize: 13, lineHeight: lineHeight(13, 1.26) }}
        >
          {children}
        </span>
      </button>
    </div>
  );
}

function HeaderIcon({ icon, tooltip, onTap }: { icon: string; tooltip: string; onTap: () => void }) {
  const [hover, setHover] = useState(false);
  return (
    <Tooltip message={tooltip}>
      <button
        type="button"
        className="bare-button"
        aria-label={tooltip}
        onClick={onTap}
        onMouseEnter={() => setHover(true)}
        onMouseLeave={() => setHover(false)}
        style={{
          width: 36,
          height: 36,
          borderRadius: '50%',
          background: hover ? withAlpha(AppColors.moonlight, 0.12) : Derived.panelGlass,
          border: `1px solid ${withAlpha(AppColors.moonlight, hover ? 0.18 : 0.1)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transition: 'background 140ms, border-color 140ms',
          cursor: 'pointer',
        }}
      >
        <Icon name={icon} size={18} color={AppColors.blushGold} />
      </button>
    </Tooltip>
  );
}

function StatusBar({ game, pulse: p }: { game: ChessGame; pulse: number }) {
  const { turn, isCheck, isCheckmate: isMate, isStalemate: isStale } = game;
  const moveCount = game.sanHistory.length;
  let label: string;
  let dot: string;
  let icon: string;
  if (isMate) {
    label = `Checkmate • ${turn === 'w' ? 'Black' : 'White'} wins`;
    dot = AppColors.error;
    icon = 'emoji_events';
  } else if (isStale) {
    label = 'Stalemate • Draw';
    dot = WARNING;
    icon = 'handshake';
  } else if (isCheck) {
    label = `${turn === 'w' ? 'White' : 'Black'} in check!`;
    dot = AppColors.error;
    icon = 'warning_amber';
  } else {
    label = `${turn === 'w' ? 'White' : 'Black'} to move`;
    dot = turn === 'w' ? AppColors.petalWhite : INK;
    icon = 'circle';
  }
  const pulse = isCheck ? 0.6 + 0.4 * p : 1;
  return (
    <div style={{ padding: '0 16px' }}>
      <div
        style={{
          padding: '10px 14px',
          borderRadius: AppRadius.lg,
          background:
            isMate || isStale
              ? withAlpha(AppColors.deepRose, 0.14)
              : isCheck
                ? withAlpha(AppColors.error, 0.1 * pulse + 0.08)
                : withAlpha(AppColors.moonlight, 0.07),
          border: `1px solid ${isCheck || isMate ? withAlpha(AppColors.error, 0.35) : withAlpha(AppColors.blushGold, 0.14)}`,
          boxShadow: isCheck ? boxShadow([{ blur: 12, color: withAlpha(AppColors.error, 0.18 * pulse) }]) : undefined,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            width: 10,
            height: 10,
            boxSizing: 'border-box',
            borderRadius: '50%',
            background: dot,
            border: `1px solid ${withAlpha(AppColors.petalWhite, turn === 'w' ? 0.9 : 0)}`,
            boxShadow: boxShadow([{ blur: 6, color: withAlpha(dot, 0.45) }]),
            transition: 'background 220ms, border-color 220ms, box-shadow 220ms',
            flexShrink: 0,
          }}
        />
        <div style={{ width: 10 }} />
        <Icon
          name={icon}
          variant={icon === 'circle' ? 'filled' : 'round'}
          size={14}
          color={isCheck || isMate ? AppColors.error : withAlpha(AppColors.blushGold, 0.9)}
        />
        <div style={{ width: 6 }} />
        <span style={{ ...AppTypography.outfitBold, flex: 1, fontSize: 12.5, ...letterSpacing(0.2) }}>{label}</span>
        <div
          style={{
            padding: '4px 8px',
            background: withAlpha(AppColors.inkDeep, 0.45),
            borderRadius: AppRadius.full,
            border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
          }}
        >
          <span style={{ ...text(10, 600, withAlpha(AppColors.petalWhite, 0.62)), display: 'block', ...letterSpacing(0.3) }}>
            {moveCount === 0 ? 'New game' : `${moveCount} ply • ${Math.ceil(moveCount / 2)} moves`}
          </span>
        </div>
      </div>
    </div>
  );
}

/**
 * A chess glyph laid out like Flutter's Text. The glyphs come from fallback
 * fonts (♟ from Everglow Emoji, 950/250 of 1024; the rest from Noto Sans
 * Symbols 2, 1069/630 of 1000), and Flutter keeps a fallback run at its
 * natural ascent and descent: `height` only shapes the Outfit part of the line
 * (split 1000/260). Measured on the board: the browser's half-leading line
 * sits pieces 3px off.
 */
function ChessGlyph({
  char,
  size,
  height = 20 / 14,
  style,
  boxStyle,
}: {
  char: string;
  size: number;
  height?: number;
  style?: CSSProperties;
  boxStyle?: CSSProperties;
}) {
  const [a, d] = char === '♟' ? [950 / 1024, 250 / 1024] : [1.069, 0.63];
  const ascent = Math.max((1000 / 1260) * height, a) * size;
  const descent = Math.max((260 / 1260) * height, d) * size;
  // With line-height: normal the browser puts the baseline at the taller of Outfit's ascent (1em) and the glyph font's.
  const natural = Math.max(1, a) * size;
  return (
    <div style={{ height: ascent + descent, flexShrink: 0, ...boxStyle }}>
      <span
        style={{
          display: 'block',
          fontSize: size,
          lineHeight: 'normal',
          letterSpacing: 0,
          marginTop: ascent - natural + ((char === '♟' ? -0.5 : 0.5) * size) / 30,
          ...style,
        }}
      >
        {char}
      </span>
    </div>
  );
}

const CAPTURE_ORDER = ['p', 'n', 'b', 'r', 'q'];
const CAPTURE_GLYPH: Record<string, string> = { p: '♟', n: '♞', b: '♝', r: '♜', q: '♛' };

function PlayerBar({
  label,
  isWhite,
  isTurn,
  captured,
  materialDiff,
}: {
  label: string;
  isWhite: boolean;
  isTurn: boolean;
  captured: string[];
  materialDiff: number;
}) {
  const counts: Record<string, number> = {};
  for (const p of captured) counts[p.toLowerCase()] = (counts[p.toLowerCase()] ?? 0) + 1;
  const ring = isTurn ? 1.6 : 1;
  return (
    <div
      style={{
        padding: '10px 12px',
        background: isTurn ? withAlpha(AppColors.deepRose, 0.13) : Derived.panelGlass,
        borderRadius: AppRadius.lg,
        border: `1px solid ${isTurn ? withAlpha(AppColors.deepRose, 0.28) : withAlpha(AppColors.moonlight, 0.1)}`,
        boxShadow: isTurn ? boxShadow([{ blur: 10, color: withAlpha(AppColors.deepRose, 0.14) }]) : undefined,
        display: 'flex',
        alignItems: 'center',
        transition: 'background 220ms, border-color 220ms, box-shadow 220ms',
      }}
    >
      <div
        style={{
          width: 36,
          height: 36,
          borderRadius: '50%',
          background: `linear-gradient(90deg, ${isWhite ? `${AppColors.petalWhite}, #E8E0D6` : `${INK}, #111111`})`,
          ...insetBorder(isTurn ? withAlpha(AppColors.blushGold, 0.55) : withAlpha(AppColors.moonlight, 0.12), ring),
          boxShadow: `inset 0 0 0 ${ring}px ${isTurn ? withAlpha(AppColors.blushGold, 0.55) : withAlpha(AppColors.moonlight, 0.12)}, ${boxShadow([{ blur: 6, color: 'rgba(0,0,0,0.25)' }])}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon
          name={isWhite ? 'circle' : 'circle_outlined'}
          variant={isWhite ? 'filled' : 'round'}
          size={18}
          color={isWhite ? INK : withAlpha(AppColors.petalWhite, 0.85)}
        />
      </div>
      <div style={{ width: 10 }} />
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center' }}>
          <span style={{ ...AppTypography.outfitBold, fontSize: 12.5 }}>{label}</span>
          {isTurn && (
            <>
              <div style={{ width: 6 }} />
              <div style={{ padding: '2px 6px', background: AppColors.deepRose, borderRadius: AppRadius.full }}>
                <span style={{ ...text(8, 800, AppColors.petalWhite), display: 'block', ...letterSpacing(0.6) }}>TURN</span>
              </div>
            </>
          )}
          {materialDiff > 0 && (
            <>
              <div style={{ width: 6 }} />
              <span style={{ ...AppTypography.outfitBold, fontSize: 11, color: AppColors.success }}>+{materialDiff}</span>
            </>
          )}
        </div>
        <div style={{ height: 3 }} />
        <div style={{ height: 16, display: 'flex', alignItems: 'flex-start', overflow: 'hidden', gap: 2 }}>
          {captured.length === 0 ? (
            <span style={text(10, 500, withAlpha(AppColors.petalWhite, 0.38))}>No captures</span>
          ) : (
            CAPTURE_ORDER.map((k) => {
              const cnt = counts[k] ?? 0;
              if (cnt === 0) return null;
              return (
                <div key={k} style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>
                  <ChessGlyph char={CAPTURE_GLYPH[k]} size={13} style={{ color: withAlpha(AppColors.petalWhite, 0.85) }} />
                  {cnt > 1 && <span style={text(9, 700, withAlpha(AppColors.petalWhite, 0.62))}>×{cnt}</span>}
                </div>
              );
            })
          )}
        </div>
      </div>
      {isTurn && (
        <div
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: AppColors.success,
            boxShadow: boxShadow([{ blur: 6, color: withAlpha(AppColors.success, 0.5) }]),
            flexShrink: 0,
          }}
        />
      )}
    </div>
  );
}

function orderedSquares(flipped: boolean) {
  const out: string[] = [];
  for (let r = 0; r < 8; r++) {
    const rank = flipped ? 1 + r : 8 - r;
    for (let f = 0; f < 8; f++) out.push(String.fromCharCode(97 + (flipped ? 7 - f : f)) + rank);
  }
  return out;
}

function BoardSection({ game, pulse, onTap }: { game: ChessGame; pulse: number; onTap: (sq: string) => void }) {
  const squares = orderedSquares(game.flipped);
  const coord = (isLight: boolean): CSSProperties => ({
    position: 'absolute',
    fontSize: 9,
    fontWeight: 700,
    lineHeight: '9px',
    color: isLight ? DARK_SQ : LIGHT_SQ,
  });
  return (
    <Shadowed
      shadows={[...E3, { blur: 18, color: withAlpha(AppColors.inkDeep, 0.55) }]}
      radius={AppRadius.x2}
      style={{ height: '100%' }}
    >
      <div
        style={{
          height: '100%',
          boxSizing: 'border-box',
          padding: 1.2,
          borderRadius: AppRadius.x2,
          ...insetBorder(withAlpha(AppColors.blushGold, 0.22), 1.2),
        }}
      >
        <div
          style={{
            position: 'relative',
            height: '100%',
            borderRadius: AppRadius.x2,
            overflow: 'hidden',
            background: `linear-gradient(135deg, ${AppColors.plum}, ${AppColors.twilight})`,
            display: 'grid',
            gridTemplateColumns: 'repeat(8, 1fr)',
            gridTemplateRows: 'repeat(8, 1fr)',
          }}
        >
          {squares.map((sq, idx) => {
            const rank = Number(sq[1]);
            const file = sq.charCodeAt(0) - 97;
            const isLight = (rank + file) % 2 === 0;
            const piece = game.board.get(sq);
            const isSelected = game.selected === sq;
            const isLegal = game.legalTargets.has(sq);
            const isLast = sq === game.lastFrom || sq === game.lastTo;
            const isKingCheck = sq === game.kingInCheck;
            const isCapture = isLegal && piece != null;
            const white = piece != null && isWhitePiece(piece);
            return (
              <div
                key={sq}
                onClick={() => onTap(sq)}
                style={{
                  position: 'relative',
                  cursor: 'pointer',
                  background: isKingCheck
                    ? 'rgba(229, 62, 62, 0.82)'
                    : isSelected
                      ? withAlpha(AppColors.deepRose, 0.38)
                      : isLast
                        ? withAlpha(AppColors.blushGold, isLight ? 0.42 : 0.34)
                        : isLight
                          ? LIGHT_SQ
                          : DARK_SQ,
                  ...(isSelected ? insetBorder(AppColors.blushGold, 1.6) : {}),
                  transition: 'background 140ms',
                }}
              >
                {((!game.flipped && file === 0) || (game.flipped && file === 7)) && (
                  <span style={{ ...coord(isLight), top: 2, left: 3 }}>{idx % 8 === 0 ? sq[1] : ''}</span>
                )}
                {((!game.flipped && rank === 1) || (game.flipped && rank === 8)) && (
                  <span style={{ ...coord(isLight), bottom: 1, right: 3 }}>{String.fromCharCode(97 + file)}</span>
                )}
                {isLegal && !isCapture && (
                  <div
                    style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                  >
                    <div
                      style={{
                        width: 14,
                        height: 14,
                        boxSizing: 'border-box',
                        borderRadius: '50%',
                        background: withAlpha(AppColors.inkDeep, 0.22),
                        border: `1px solid ${withAlpha(AppColors.petalWhite, 0.12)}`,
                        boxShadow: boxShadow([{ blur: 4, color: 'rgba(0,0,0,0.18)' }]),
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <div style={{ width: 7, height: 7, borderRadius: '50%', background: INK }} />
                    </div>
                  </div>
                )}
                {isCapture && (
                  <div
                    style={{
                      position: 'absolute',
                      inset: 3,
                      borderRadius: '50%',
                      boxShadow: `inset 0 0 0 3.5px ${withAlpha(AppColors.deepRose, 0.78)}, ${boxShadow([{ blur: 2, color: 'rgba(0,0,0,0.12)' }])}`,
                      pointerEvents: 'none',
                    }}
                  />
                )}
                {piece != null && (
                  <div
                    style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                  >
                    <ChessGlyph
                      char={pieceGlyph(piece)}
                      size={30}
                      height={1}
                      style={{
                        color: white ? AppColors.petalWhite : '#111111',
                        textShadow: `0 1.5px ${(2 * (4 * 0.57735 + 0.5)).toFixed(2)}px rgba(0,0,0,${white ? 0.28 : 0.45})${
                          white ? `, 0 0 ${(2 * (0.5 * 0.57735 + 0.5)).toFixed(2)}px ${AppColors.petalWhite}` : ''
                        }`,
                      }}
                      boxStyle={{ transform: `scale(${isSelected ? 1.06 : 1})`, transition: 'transform 140ms' }}
                    />
                  </div>
                )}
                {isKingCheck && (
                  <div
                    style={{
                      position: 'absolute',
                      inset: 0,
                      pointerEvents: 'none',
                      boxShadow: `inset 0 0 0 1.2px ${withAlpha(AppColors.petalWhite, 0.55 * pulse)}, ${boxShadow([
                        { blur: 10, color: withAlpha(AppColors.error, 0.35 * pulse) },
                      ])}`,
                    }}
                  />
                )}
              </div>
            );
          })}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: AppRadius.x2,
              border: `1px solid ${withAlpha(AppColors.petalWhite, 0.04)}`,
              pointerEvents: 'none',
            }}
          />
        </div>
      </div>
    </Shadowed>
  );
}

function SidePanel({
  game,
  materialWhite,
  materialBlack,
  onUndo,
  onReset,
  onFlip,
}: {
  game: ChessGame;
  materialWhite: number;
  materialBlack: number;
  onUndo: () => void;
  onReset: () => void;
  onFlip: () => void;
}) {
  const sans = game.sanHistory;
  const diff = materialWhite - materialBlack;
  const materialText = diff === 0 ? 'Even material' : diff > 0 ? `White +${diff}` : `Black +${-diff}`;
  const panel: CSSProperties = {
    background: Derived.panelGlass,
    borderRadius: AppRadius.x2,
    border: `1px solid ${withAlpha(AppColors.moonlight, 0.11)}`,
  };
  const rows = Math.ceil(sans.length / 2);
  return (
    <div style={{ display: 'flex', flexDirection: 'column' }}>
      <Shadowed shadows={E2} radius={AppRadius.x2}>
        <div style={{ ...panel, padding: 12 }}>
          <div style={{ display: 'flex' }}>
            <PillButton icon="undo" label="Undo" enabled={game.undoStack.length > 0} onTap={onUndo} />
            <div style={{ width: 8 }} />
            <PillButton icon="swap_vert" label={game.flipped ? 'White view' : 'Black view'} onTap={onFlip} />
            <div style={{ width: 8 }} />
            <PillButton icon="restart_alt" label="New" rose onTap={onReset} />
          </div>
          <div style={{ height: 10 }} />
          <div
            style={{
              padding: '8px 10px',
              background: withAlpha(AppColors.inkDeep, 0.42),
              borderRadius: AppRadius.lg,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <div style={{ padding: 6, borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.14), display: 'flex' }}>
              <Icon name="auto_graph" size={14} color={AppColors.blushGold} />
            </div>
            <div style={{ width: 8 }} />
            <span style={{ ...text(11, 600, withAlpha(AppColors.petalWhite, 0.78)), flex: 1 }}>{materialText}</span>
            <span style={text(10, 500, withAlpha(AppColors.petalWhite, 0.44))}>{sans.length} ply</span>
          </div>
        </div>
      </Shadowed>
      <div style={{ height: 12 }} />
      <Shadowed shadows={E2} radius={AppRadius.x2}>
        <div style={{ ...panel, display: 'flex', flexDirection: 'column' }}>
          <div style={{ padding: '14px 14px 10px', display: 'flex', alignItems: 'center' }}>
            <div
              style={{
                padding: '4px 8px',
                background: withAlpha(AppColors.deepRose, 0.14),
                borderRadius: AppRadius.full,
                border: `1px solid ${withAlpha(AppColors.deepRose, 0.18)}`,
                display: 'flex',
                alignItems: 'center',
              }}
            >
              <Icon name="history" size={12} color={AppColors.deepRose} />
              <div style={{ width: 4 }} />
              <span style={{ ...text(10, 800, AppColors.deepRose), ...letterSpacing(0.6) }}>Moves</span>
            </div>
            <div style={{ flex: 1 }} />
            {sans.length > 0 && (
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  void navigator.clipboard?.writeText(toPgn(sans)).catch(() => {});
                  showSnackBar('PGN copied', { background: AppColors.deepRose, duration: 2000 });
                }}
                style={{
                  padding: '4px 8px',
                  background: withAlpha(AppColors.moonlight, 0.08),
                  borderRadius: AppRadius.full,
                  display: 'flex',
                  alignItems: 'center',
                  cursor: 'pointer',
                }}
              >
                <Icon name="content_copy" size={11} color={AppColors.blushGold} />
                <div style={{ width: 4 }} />
                <span style={text(10, 600, AppColors.blushGold)}>Copy PGN</span>
              </button>
            )}
          </div>
          {sans.length === 0 ? (
            <div style={{ padding: '4px 14px 18px' }}>
              <div
                style={{
                  padding: '22px 14px',
                  background: withAlpha(AppColors.inkDeep, 0.35),
                  borderRadius: AppRadius.lg,
                  border: `1px solid ${withAlpha(AppColors.moonlight, 0.06)}`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                }}
              >
                <Icon name="sports_esports" variant="outlined" size={22} color={withAlpha(AppColors.petalWhite, 0.22)} />
                <div style={{ height: 8 }} />
                <span style={text(12, 600, withAlpha(AppColors.petalWhite, 0.55))}>No moves yet</span>
                <div style={{ height: 4 }} />
                <span
                  style={{
                    ...text(10, 500, withAlpha(AppColors.petalWhite, 0.38)),
                    lineHeight: lineHeight(10, 1.4),
                    textAlign: 'center',
                  }}
                >
                  Tap a piece to see legal moves • Dots = quiet • Ring = capture
                </span>
              </div>
            </div>
          ) : (
            <div className="no-scrollbar" style={{ maxHeight: 220, overflowY: 'auto', padding: '0 8px 12px' }}>
              {Array.from({ length: rows }, (_, i) => {
                const w = sans[i * 2];
                const b = i * 2 + 1 < sans.length ? sans[i * 2 + 1] : null;
                const isLastRow = i === rows - 1;
                return (
                  <div
                    key={i}
                    style={{
                      marginBottom: 4,
                      padding: '7px 8px',
                      background: isLastRow ? withAlpha(AppColors.blushGold, 0.08) : 'transparent',
                      borderRadius: AppRadius.sm,
                      boxShadow: isLastRow ? `inset 0 0 0 1px ${withAlpha(AppColors.blushGold, 0.14)}` : undefined,
                      display: 'flex',
                      alignItems: 'center',
                    }}
                  >
                    <span style={{ ...text(11, 700, withAlpha(AppColors.petalWhite, 0.42)), width: 28, flexShrink: 0 }}>
                      {i + 1}.
                    </span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <MovePill text={w} isWhite isLast={isLastRow && b == null} />
                    </div>
                    <div style={{ width: 6 }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      {b != null ? (
                        <MovePill text={b} isWhite={false} isLast={isLastRow} />
                      ) : (
                        <span style={text(11, 500, withAlpha(AppColors.petalWhite, 0.22))}>—</span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
          <div style={{ padding: '0 12px 12px' }}>
            <span
              style={{
                ...text(9.5, 500, withAlpha(AppColors.petalWhite, 0.34)),
                lineHeight: lineHeight(9.5, 1.4),
                display: 'block',
              }}
            >
              Tip: tap your piece again to deselect • King in check pulses red • Last move glows gold
            </span>
          </div>
        </div>
      </Shadowed>
      <div style={{ height: 12 }} />
      <div
        style={{
          padding: 12,
          background: withAlpha(AppColors.moonlight, 0.06),
          borderRadius: AppRadius.lg,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.08)}`,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <LegendDot color={AppColors.deepRose} label="Selected" />
        <div style={{ width: 10 }} />
        <LegendDot color={AppColors.blushGold} label="Last move" />
        <div style={{ width: 10 }} />
        <LegendDot color={AppColors.error} label="Check" />
        <div style={{ flex: 1 }} />
        <Icon name="touch_app" size={12} color={withAlpha(AppColors.petalWhite, 0.32)} />
        <div style={{ width: 4 }} />
        <span style={text(10, 500, withAlpha(AppColors.petalWhite, 0.42))}>Tap to move</span>
      </div>
    </div>
  );
}

function LegendDot({ color, label }: { color: string; label: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <div
        style={{
          width: 8,
          height: 8,
          boxSizing: 'border-box',
          borderRadius: '50%',
          background: color,
          border: `1px solid ${withAlpha(AppColors.petalWhite, 0.15)}`,
        }}
      />
      <div style={{ width: 5 }} />
      <span style={text(10, 600, withAlpha(AppColors.petalWhite, 0.62))}>{label}</span>
    </div>
  );
}

function MovePill({ text: label, isWhite, isLast }: { text: string; isWhite: boolean; isLast: boolean }) {
  return (
    <div
      style={{
        padding: '5px 8px',
        background: isLast
          ? isWhite
            ? withAlpha(AppColors.petalWhite, 0.92)
            : '#1A1A1E'
          : isWhite
            ? withAlpha(AppColors.petalWhite, 0.08)
            : withAlpha(AppColors.inkDeep, 0.35),
        borderRadius: AppRadius.sm,
        border: `1px solid ${isLast ? withAlpha(AppColors.blushGold, 0.35) : withAlpha(AppColors.moonlight, 0.08)}`,
      }}
    >
      <span style={{ ...text(11.5, 700, isLast && isWhite ? '#1A1A1E' : AppColors.petalWhite), display: 'block' }}>{label}</span>
    </div>
  );
}

function PillButton({
  icon,
  label,
  onTap,
  enabled = true,
  rose = false,
}: {
  icon: string;
  label: string;
  onTap: () => void;
  enabled?: boolean;
  rose?: boolean;
}) {
  const [hover, setHover] = useState(false);
  const hot = hover && enabled;
  return (
    <button
      type="button"
      className="bare-button"
      disabled={!enabled}
      onClick={onTap}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        flex: 1,
        minWidth: 0,
        padding: 10,
        background: rose
          ? hot
            ? AppColors.deepRose
            : withAlpha(AppColors.deepRose, 0.92)
          : withAlpha(AppColors.moonlight, hot ? 0.1 : 0.07),
        borderRadius: AppRadius.full,
        border: `1px solid ${rose ? AppColors.deepRose : withAlpha(AppColors.moonlight, hot ? 0.16 : 0.1)}`,
        boxShadow: rose && hover ? boxShadow(GLOW_ROSE) : undefined,
        transition: 'background 140ms, border-color 140ms, box-shadow 140ms',
        cursor: enabled ? 'pointer' : 'default',
      }}
    >
      <div style={{ opacity: enabled ? 1 : 0.38, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name={icon} size={14} color={rose ? AppColors.petalWhite : AppColors.blushGold} />
        <div style={{ width: 5 }} />
        <span style={{ ...text(11, 700, AppColors.petalWhite), ...letterSpacing(0.2) }}>{label}</span>
      </div>
    </button>
  );
}

const PROMO_CHOICES = ['q', 'r', 'b', 'n'];
const PROMO_LABELS = ['Queen', 'Rook', 'Bishop', 'Knight'];

function PromotionSheet({ onPick, isWhite }: { onPick: (c: string) => void; isWhite: boolean }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: 'rgba(0,0,0,0.52)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          margin: 20,
          padding: '18px 18px 16px',
          background: AppColors.velvet,
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.18)}`,
          boxShadow: boxShadow(E4),
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <div style={{ padding: '5px 10px', background: withAlpha(AppColors.blushGold, 0.14), borderRadius: AppRadius.full }}>
          <span style={{ ...text(10, 800, AppColors.blushGold), display: 'block', ...letterSpacing(0.7) }}>Pawn promotion</span>
        </div>
        <div style={{ height: 10 }} />
        <span style={{ ...AppTypography.cormorantBold, fontSize: 20, color: AppColors.petalWhite }}>Choose your piece</span>
        <div style={{ height: 4 }} />
        <span style={text(12, 500, Derived.textMuted)}>Your pawn reached the end — crown it.</span>
        <div style={{ height: 18 }} />
        <div style={{ display: 'flex', gap: 10 }}>
          {PROMO_CHOICES.map((c, i) => (
            <button
              key={c}
              type="button"
              className="bare-button"
              onClick={() => onPick(c)}
              style={{
                width: 74,
                height: 86,
                borderRadius: AppRadius.lg,
                background: c === 'q' ? withAlpha(AppColors.deepRose, 0.14) : withAlpha(AppColors.moonlight, 0.07),
                ...insetBorder(
                  c === 'q' ? withAlpha(AppColors.deepRose, 0.28) : withAlpha(AppColors.moonlight, 0.12),
                  c === 'q' ? 1.4 : 1,
                ),
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
              }}
            >
              <ChessGlyph
                char={pieceGlyph(isWhite ? c.toUpperCase() : c)}
                size={32}
                style={{ textShadow: `0 0 ${(2 * (4 * 0.57735 + 0.5)).toFixed(2)}px rgba(0,0,0,0.35)` }}
              />
              <div style={{ height: 4 }} />
              <span style={text(10, 700, withAlpha(AppColors.petalWhite, 0.78))}>{PROMO_LABELS[i]}</span>
            </button>
          ))}
        </div>
        <div style={{ height: 10 }} />
        <span style={text(10, 500, withAlpha(AppColors.petalWhite, 0.32))}>Queen is usually strongest</span>
      </div>
    </div>
  );
}

function GameOverOverlay({
  isMate,
  turn,
  onNewGame,
  onBack,
}: {
  isMate: boolean;
  turn: string;
  onNewGame: () => void;
  onBack: () => void;
}) {
  const winner = turn === 'w' ? 'Black' : 'White';
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: 'rgba(0,0,0,0.48)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          margin: 22,
          padding: '20px 20px 18px',
          background: AppColors.twilight,
          borderRadius: AppRadius.x2,
          border: `1px solid ${withAlpha(AppColors.blushGold, 0.18)}`,
          boxShadow: boxShadow(E4),
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            width: 52,
            height: 52,
            borderRadius: '50%',
            background: `linear-gradient(90deg, ${isMate ? `${AppColors.deepRose}, ${AppColors.auroraRose}` : `${AppColors.auroraGold}, ${AppColors.warmAmber}`})`,
            boxShadow: boxShadow([{ blur: 14, color: withAlpha(isMate ? AppColors.deepRose : AppColors.auroraGold, 0.35) }]),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={isMate ? 'emoji_events' : 'handshake'} size={26} color={AppColors.petalWhite} />
        </div>
        <div style={{ height: 12 }} />
        <span style={{ ...AppTypography.cormorantBold, fontSize: 24, color: AppColors.petalWhite }}>
          {isMate ? 'Checkmate!' : 'Stalemate'}
        </span>
        <div style={{ height: 4 }} />
        <span style={{ ...text(12.5, 500, Derived.textMuted), lineHeight: lineHeight(12.5, 1.4), textAlign: 'center' }}>
          {isMate ? `${winner} wins — beautiful game.` : 'Draw by stalemate — no legal moves, but no check.'}
        </span>
        <div style={{ height: 16 }} />
        <div style={{ display: 'flex' }}>
          <button
            type="button"
            className="bare-button"
            onClick={onBack}
            style={{
              padding: '10px 16px',
              background: withAlpha(AppColors.moonlight, 0.08),
              borderRadius: AppRadius.full,
              border: `1px solid ${withAlpha(AppColors.moonlight, 0.14)}`,
              cursor: 'pointer',
            }}
          >
            <span style={text(12, 700, AppColors.petalWhite)}>Back to Play Zone</span>
          </button>
          <div style={{ width: 10 }} />
          <button
            type="button"
            className="bare-button"
            onClick={onNewGame}
            style={{
              padding: '10px 18px',
              background: `linear-gradient(90deg, ${AppColors.deepRose}, ${AppColors.auroraRose})`,
              borderRadius: AppRadius.full,
              boxShadow: boxShadow([{ blur: 10, color: withAlpha(AppColors.deepRose, 0.28) }]),
              cursor: 'pointer',
            }}
          >
            <span style={{ ...AppTypography.outfitBold, fontSize: 12 }}>New game</span>
          </button>
        </div>
      </div>
    </div>
  );
}
