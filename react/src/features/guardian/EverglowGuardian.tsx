// Port of lib/features/guardian/presentation/widgets/everglow_guardian.dart.
import { useEffect, useRef, useState } from 'react';
import { useValue } from '../../core/system/store';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Curves, motionReduced, orZero, reduceAmbientMotion } from '../../core/theme/motion';
import { linear } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { Icon } from '../../shared/widgets/Icon';
import { CatVisuals } from './CatVisuals';
import { guardianController } from './guardianController';
import { ThoughtBubble } from './ThoughtBubble';

type Particle = { angle: number; color: string };

export function EverglowGuardian() {
  const { width, height } = useViewport();
  const reduced = motionReduced();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const isAIMode = useValue(guardianController.isAIMode);
  const visible = useValue(guardianController.isMessageVisible);
  const message = useValue(guardianController.currentMessage);

  const [particles, setParticles] = useState<Particle[]>([]);
  const [floatY, setFloatY] = useState(0);
  const [bounceScale, setBounceScale] = useState(1);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [chatText, setChatText] = useState('');
  const particleTimer = useRef<number | null>(null);
  const longPressTimer = useRef<number | null>(null);
  const didLongPress = useRef(false);

  useEffect(() => {
    guardianController.welcome();
    return () => {
      if (particleTimer.current) clearTimeout(particleTimer.current);
    };
  }, []);

  // Idle floating animation (3s easeInOut reverse repeat, 0 to -15px)
  useEffect(() => {
    if (reduceAmbient || reduced) {
      setFloatY(0);
      return;
    }
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const cycle = ((now - start) % 6000) / 3000;
      const t = cycle <= 1 ? cycle : 2 - cycle;
      setFloatY(-15 * Curves.easeInOut(t));
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reduceAmbient, reduced]);

  const playBounce = () => {
    if (reduced) return;
    const dur = orZero(600);
    if (dur === 0) return;
    const start = performance.now();
    const step = (now: number) => {
      const p = Math.min(1, (now - start) / dur);
      if (p < 0.3) {
        setBounceScale(1 + 0.3 * Curves.easeOut(p / 0.3));
      } else {
        setBounceScale(1.3 - 0.3 * Curves.bounceOut((p - 0.3) / 0.7));
      }
      if (p < 1) requestAnimationFrame(step);
      else setBounceScale(1);
    };
    requestAnimationFrame(step);
  };

  useEffect(() => {
    playBounce();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const createParticles = () => {
    if (particleTimer.current) clearTimeout(particleTimer.current);
    setParticles(
      Array.from({ length: 6 }, (_, i) => ({
        angle: Math.PI * 2 * (i / 6),
        color: withAlpha(AppColors.roseQuartz, 0.8),
      })),
    );
    particleTimer.current = window.setTimeout(() => setParticles([]), 800);
  };

  const handleTap = () => {
    if (didLongPress.current) {
      didLongPress.current = false;
      return;
    }
    if (guardianController.isAIMode.value) {
      setSheetOpen(true);
    } else {
      guardianController.react();
      playBounce();
      createParticles();
    }
  };

  const sendChat = () => {
    const trimmed = chatText.trim();
    if (!trimmed) return;
    setChatText('');
    setSheetOpen(false);
    void guardianController.sendAIMessage(trimmed);
    createParticles();
  };

  const content = message?.content ?? '';

  return (
    <div style={{ position: 'relative', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
      {particles.map((p) => (
        <div
          key={p.angle}
          style={{
            position: 'absolute',
            bottom: 40 + 60 * Math.sin(p.angle),
            right: 40 + 60 * Math.cos(p.angle),
            pointerEvents: 'none',
          }}
        >
          <Icon name={isAIMode ? 'auto_awesome' : 'favorite'} variant="filled" size={12} color={p.color} />
        </div>
      ))}

      {isAIMode && (
        <div
          style={{
            position: 'absolute',
            bottom: -4,
            right: -4,
            width: 16,
            height: 16,
            borderRadius: '50%',
            background: AppColors.blushGold,
            border: `2px solid ${AppColors.twilight}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 2,
          }}
        >
          <Icon name="auto_awesome" size={10} color={AppColors.petalWhite} />
        </div>
      )}

      {visible && content && (
        <div style={{ position: 'absolute', bottom: 90, right: 0, zIndex: 3 }}>
          <ThoughtBubble message={content} />
        </div>
      )}

      <button
        type="button"
        className="bare-button"
        aria-label="Everglow Guardian Cat"
        onPointerDown={() => {
          didLongPress.current = false;
          longPressTimer.current = window.setTimeout(() => {
            didLongPress.current = true;
            guardianController.toggleAIMode();
            if (guardianController.isAIMode.value) createParticles();
          }, 500);
        }}
        onPointerUp={() => {
          if (longPressTimer.current) clearTimeout(longPressTimer.current);
        }}
        onPointerCancel={() => {
          if (longPressTimer.current) clearTimeout(longPressTimer.current);
        }}
        onClick={handleTap}
        style={{
          transform: `translateY(${floatY.toFixed(2)}px) scale(${(reduced ? 1 : bounceScale).toFixed(4)})`,
        }}
      >
        {reduceAmbient ? (
          <img
            src="/images/guardian_cat.png"
            alt="Everglow Guardian Cat"
            width={80}
            height={80}
            style={{ display: 'block' }}
          />
        ) : (
          <CatVisuals size={80} autoRotate={false} />
        )}
      </button>

      {sheetOpen && (
        <div
          onClick={() => setSheetOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: withAlpha(AppColors.inkDeep, 0.72),
            zIndex: 1100,
            display: 'flex',
            alignItems: 'flex-end',
            justifyContent: 'center',
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxWidth: 600,
              padding: '20px 20px 20px',
              background: AppColors.moonlight,
              borderRadius: '24px 24px 0 0',
            }}
          >
            <div style={{ width: 40, height: 4, margin: '0 auto 20px', borderRadius: 2, background: withAlpha(AppColors.blushGold, 0.65) }} />
            <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
              <Icon name="auto_awesome" size={20} color={AppColors.blushGold} />
              <div style={{ width: 8 }} />
              <span style={{ ...AppTypography.outfitBold, fontSize: 16 }}>Talk to Guardian</span>
              <div style={{ flex: 1 }} />
              <button
                type="button"
                className="bare-button"
                onClick={() => {
                  guardianController.toggleAIMode();
                  setSheetOpen(false);
                }}
                style={{
                  padding: '6px 12px',
                  borderRadius: 20,
                  border: `1px solid ${withAlpha(AppColors.blushGold, 0.6)}`,
                  ...AppTypography.outfitWhite,
                  fontSize: 12,
                  color: AppColors.blushGold,
                }}
              >
                Exit AI Mode
              </button>
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <input
                value={chatText}
                onChange={(e) => setChatText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && sendChat()}
                placeholder="Tell Guardian something..."
                autoFocus
                style={{
                  flex: 1,
                  background: withAlpha(AppColors.twilight, 0.4),
                  border: 'none',
                  borderRadius: 14,
                  padding: '14px 18px',
                  ...AppTypography.outfitWhite,
                  fontSize: 14,
                  outline: 'none',
                }}
              />
              <button
                type="button"
                className="bare-button"
                onClick={sendChat}
                style={{
                  width: 46,
                  height: 46,
                  borderRadius: 14,
                  background: linear([AppColors.blushGold, AppColors.deepRose]),
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Icon name="send" size={20} color={AppColors.petalWhite} />
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
