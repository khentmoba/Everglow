// Port of lib/features/play_zone/presentation/screens/scribble_game_screen.dart.
import { useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { useAuth } from '../../core/services/auth';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { Icon } from '../../shared/widgets/Icon';
import { usePlayZoneBack } from './table_tennis/TTFrame';

const words = ['love', 'sunset', 'cat', 'kiss', 'dance', 'everglow', 'star', 'moon', 'beach', 'guitar'];

/** `(_words..shuffle()).first`: Dart's in-place shuffle, so picks follow the same order. */
function pickWord() {
  for (let n = words.length; n > 1;) {
    const pos = Math.floor(Math.random() * n);
    n -= 1;
    [words[n], words[pos]] = [words[pos], words[n]];
  }
  return words[0];
}

type Point = [number, number];

export function ScribblePage() {
  const auth = useAuth();
  const back = usePlayZoneBack();
  const [strokes, setStrokes] = useState<Point[][]>([]);
  const [current, setCurrent] = useState<Point[]>([]);
  const [word, setWord] = useState(pickWord);
  const [guess, setGuess] = useState('');
  const [status, setStatus] = useState('Draw the word — partner guesses!');
  const drawing = useRef(false);

  // Flutter maps touches against the whole screen, not the white board, so
  // points are page coordinates drawn from the board's corner (kept as-is).
  const point = (e: React.PointerEvent): Point => [e.clientX, e.clientY];

  const clear = () => {
    setStrokes([]);
    setCurrent([]);
  };

  const newWord = () => {
    setWord(pickWord());
    clear();
    setStatus('New word — draw!');
  };

  const submitGuess = () => {
    const g = guess.trim().toLowerCase();
    if (!g) return;
    setStatus(g === word ? `🎉 Correct! It was "${word}"` : `❌ "${g}" — try again!`);
    setGuess('');
  };

  const all = current.length ? [...strokes, current] : strokes;
  const row: CSSProperties = { position: 'relative', padding: '0 16px', display: 'flex', alignItems: 'center' };

  return (
    <div style={{ position: 'fixed', inset: 0 }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[{ color: AppColors.auroraTeal, alignment: [-0.7, -0.8], size: 0.85, opacity: 0.12 }]}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          padding:
            'env(safe-area-inset-top, 0px) env(safe-area-inset-right, 0px) env(safe-area-inset-bottom, 0px) env(safe-area-inset-left, 0px)',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <EverglowFeatureHeader
          title="Scribble"
          subtitle="draw & guess • Firestore sync ready"
          icon="brush"
          hue={AppColors.auroraTeal}
          onBack={back}
        />
        <div style={row}>
          <div
            style={{
              flex: 1,
              padding: '10px 14px',
              background: withAlpha(AppColors.moonlight, 0.08),
              borderRadius: 12,
              border: `1px solid ${withAlpha(AppColors.blushGold, 0.15)}`,
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <Icon name="lightbulb" size={16} color={AppColors.warmAmber} />
            <div style={{ width: 8 }} />
            <span style={{ ...AppTypography.outfitBold, fontSize: 13, color: AppColors.warmAmber }}>Word: {word}</span>
            <div style={{ flex: 1 }} />
            <span style={{ ...AppTypography.outfitWhite, fontSize: 10, color: withAlpha(AppColors.petalWhite, 0.5) }}>
              by {auth.currentUser ?? ''}
            </span>
          </div>
        </div>
        <div style={{ height: 10 }} />
        <div style={row}>
          <div
            style={{
              flex: 1,
              padding: '8px 12px',
              background: withAlpha(AppColors.inkDeep, 0.5),
              borderRadius: 10,
              display: 'flex',
              alignItems: 'center',
            }}
          >
            <Icon name="info_outline" size={14} color={AppColors.softLavender} />
            <div style={{ width: 6 }} />
            <span style={{ ...AppTypography.outfitWhite, flex: 1, fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.7) }}>
              {status}
            </span>
          </div>
        </div>
        <div style={{ height: 10 }} />
        <div
          style={{
            flex: 1,
            minHeight: 0,
            margin: '0 16px',
            background: AppColors.petalWhite,
            borderRadius: 16,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.2)}`,
          }}
        >
          <div
            style={{ position: 'relative', width: '100%', height: '100%', touchAction: 'none' }}
            onPointerDown={(e) => {
              e.currentTarget.setPointerCapture(e.pointerId);
              drawing.current = true;
              setCurrent([point(e)]);
            }}
            onPointerMove={(e) => {
              if (!drawing.current) return;
              const p = point(e);
              setCurrent((c) => [...c, p]);
            }}
            onPointerUp={() => {
              if (!drawing.current) return;
              drawing.current = false;
              setCurrent((c) => {
                setStrokes((s) => [...s, c]);
                return [];
              });
            }}
            onPointerCancel={() => {
              drawing.current = false;
              setCurrent([]);
            }}
          >
            <svg
              aria-hidden
              style={{ position: 'absolute', left: 0, top: 0, width: 1, height: 1, overflow: 'visible', pointerEvents: 'none' }}
            >
              {all.map((s, i) =>
                s.length > 1 ? (
                  <polyline
                    key={i}
                    points={s.map((p) => p.join(',')).join(' ')}
                    fill="none"
                    stroke="#000"
                    strokeWidth={4}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                ) : null,
              )}
            </svg>
          </div>
        </div>
        <div style={{ height: 12 }} />
        <div style={row}>
          <GuessField value={guess} onChange={setGuess} onSubmit={submitGuess} />
          <div style={{ width: 8 }} />
          <ElevatedButton onPressed={submitGuess} background={AppColors.deepRose} radius={12}>
            <span style={{ ...AppTypography.labelLarge, lineHeight: lineHeight(14, 1.26) }}>Guess</span>
          </ElevatedButton>
        </div>
        <div style={{ height: 10 }} />
        <div style={row}>
          <OutlinedIconButton onPressed={clear} />
          <div style={{ flex: 1 }} />
          <ElevatedButton
            onPressed={newWord}
            background={AppColors.auroraTeal}
            radius={24}
            icon={<Icon name="refresh" size={16} color={AppColors.petalWhite} />}
          >
            <span
              style={{ ...AppTypography.labelLarge, ...AppTypography.outfitBold, fontSize: 12, lineHeight: lineHeight(12, 1.26) }}
            >
              New word
            </span>
          </ElevatedButton>
        </div>
        <div style={{ height: 16 }} />
      </div>
    </div>
  );
}

/** M3 filled TextField, no border, 14/10 padding, 48px tall. The hint is white on white, as in Flutter. */
function GuessField({ value, onChange, onSubmit }: { value: string; onChange: (v: string) => void; onSubmit: () => void }) {
  const text: CSSProperties = {
    ...AppTypography.outfitWhite,
    fontSize: 13,
    letterSpacing: 0.5,
    lineHeight: lineHeight(13, 1.5),
    color: AppColors.twilight,
  };
  return (
    <div
      style={{
        flex: 1,
        minWidth: 0,
        height: 48,
        boxSizing: 'border-box',
        padding: '0 14px',
        background: AppColors.petalWhite,
        borderRadius: 12,
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
      }}
    >
      {value === '' && (
        <span
          aria-hidden
          style={{
            ...AppTypography.outfitWhite,
            position: 'absolute',
            left: 14,
            fontSize: 16,
            letterSpacing: 0.5,
            lineHeight: lineHeight(16, 1.5),
            color: withAlpha(AppColors.petalWhite, 0.4),
            pointerEvents: 'none',
          }}
        >
          Type guess...
        </span>
      )}
      <input
        value={value}
        aria-label="Type guess..."
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && onSubmit()}
        style={{
          ...text,
          width: '100%',
          border: 0,
          outline: 'none',
          background: 'transparent',
          padding: 0,
          caretColor: AppColors.deepRose,
        }}
      />
    </div>
  );
}

/** ElevatedButton with the app theme: 28/18 padding, elevation 1. */
function ElevatedButton({
  onPressed,
  background,
  radius,
  icon,
  children,
}: {
  onPressed: () => void;
  background: string;
  radius: number;
  icon?: ReactNode;
  children: ReactNode;
}) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onPressed}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        padding: '18px 28px',
        minHeight: 40,
        borderRadius: radius,
        // M3 hover: the foreground colour at 8% over the fill.
        background: hovered
          ? `linear-gradient(${withAlpha(AppColors.petalWhite, 0.08)}, ${withAlpha(AppColors.petalWhite, 0.08)}), ${background}`
          : background,
        color: AppColors.petalWhite,
        boxShadow: '0 1px 2px rgba(0,0,0,0.3), 0 1px 3px 1px rgba(0,0,0,0.15)',
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        cursor: 'pointer',
        flexShrink: 0,
      }}
    >
      {icon}
      {children}
    </button>
  );
}

/** OutlinedButton.icon: 40px stadium, 16/24 padding, 1px warm amber border. */
function OutlinedIconButton({ onPressed }: { onPressed: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <div style={{ height: 48, display: 'flex', alignItems: 'center' }}>
      <button
        type="button"
        className="bare-button"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          height: 40,
          background: hovered ? withAlpha(AppColors.deepRose, 0.08) : 'transparent',
          padding: '0 24px 0 16px',
          borderRadius: 20,
          border: `1px solid ${withAlpha(AppColors.warmAmber, 0.3)}`,
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          cursor: 'pointer',
        }}
      >
        <Icon name="clear" size={16} color={AppColors.warmAmber} />
        <span
          style={{
            ...AppTypography.labelLarge,
            fontWeight: 500,
            fontSize: 12,
            color: AppColors.warmAmber,
            lineHeight: lineHeight(12, 1.26),
          }}
        >
          Clear
        </span>
      </button>
    </div>
  );
}
