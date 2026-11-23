// Port of lib/features/heartbeat/presentation/widgets/partner_status_indicator.dart.
import { useEffect, useRef, useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Curves, reduceAmbientMotion } from '../../core/theme/motion';
import { shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { HeartNeeds, isCurrentAt, moodService, type UserMood } from './moodService';

const PINK_ACCENT = '#FF4081';
const BLUE = '#2196F3';

export function PartnerStatusIndicator() {
  const auth = useAuth();
  const partnerUsername = auth.partnerUsername ?? '';
  const partnerName = auth.partnerName;
  const mood = useSource(
    () => (partnerUsername ? moodService.watchLatestMood(partnerUsername) : null),
    [partnerUsername],
    null,
  );
  const [sheetOpen, setSheetOpen] = useState(false);

  if (!mood || !isCurrentAt(mood, new Date())) return null;

  return (
    <>
      <Tooltip message={`${partnerName} is feeling ${mood.moodEmoji}`}>
        <button
          type="button"
          className="bare-button"
          onClick={() => setSheetOpen(true)}
          aria-label={`${partnerName} is feeling ${mood.moodEmoji}`}
          style={{ borderRadius: 27 }}
        >
          <MoodHeart score={mood.moodScore} emoji={mood.moodEmoji} />
        </button>
      </Tooltip>
      {sheetOpen && (
        <PartnerCheckInModal
          mood={mood}
          partnerName={partnerName}
          username={auth.currentUser ?? ''}
          onClose={() => setSheetOpen(false)}
        />
      )}
    </>
  );
}

function MoodHeart({ score, emoji }: { score: number; emoji: string }) {
  const { width, height } = useViewport();
  const reduceAmbient = reduceAmbientMotion(width, height);
  const heartRef = useRef<HTMLSpanElement | null>(null);

  // The 4s pulse runs every frame; write the transform straight to the DOM so
  // it never re-renders this widget (and its callers) ~60 times a second.
  useEffect(() => {
    if (reduceAmbient) {
      if (heartRef.current) heartRef.current.style.transform = 'scale(1)';
      return;
    }
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      raf = requestAnimationFrame(tick);
      if (document.hidden) return;
      const cycle = ((now - start) % 4000) / 2000;
      const t = cycle <= 1 ? cycle : 2 - cycle;
      if (heartRef.current) {
        heartRef.current.style.transform = `scale(${(1 + 0.2 * Curves.easeInOut(t)).toFixed(4)})`;
      }
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [reduceAmbient]);

  const isStressed = score <= 2;
  const isAmazing = score === 5;

  return (
    <div style={{ position: 'relative', width: 54, height: 54 }}>
      {isAmazing && (
        <div style={shadowLayer({ color: PINK_ACCENT, blur: 10, spread: 2 }, { circle: true })} aria-hidden />
      )}
      {isStressed && (
        <div style={shadowLayer({ color: withAlpha(BLUE, 0.3), blur: 5, spread: 1 }, { circle: true })} aria-hidden />
      )}
      <div
        style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.2), blur: 15, offset: [0, 5] }, { circle: true })}
        aria-hidden
      />
      <div
        style={{
          position: 'relative',
          width: 54,
          height: 54,
          borderRadius: '50%',
          background: withAlpha(AppColors.moonlight, 0.12),
          border: `1.5px solid ${withAlpha(AppColors.blushGold, 0.55)}`,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <span
          ref={heartRef}
          style={{
            fontSize: isAmazing ? 26 : 22,
            lineHeight: 1,
            display: 'inline-block',
          }}
        >
          {emoji}
        </span>
      </div>
    </div>
  );
}

function PartnerCheckInModal({
  mood,
  partnerName,
  username,
  onClose,
}: {
  mood: UserMood;
  partnerName: string;
  username: string;
  onClose: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [acknowledged, setAcknowledged] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const isAck = acknowledged || mood.acknowledgedBy != null;

  const handleAck = async () => {
    setSaving(true);
    setError(null);
    try {
      await moodService.acknowledge(mood, username);
      setAcknowledged(true);
    } catch {
      setError('Could not send. Try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      onClick={onClose}
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
          background: AppColors.velvet,
          borderRadius: '24px 24px 0 0',
          padding: 24,
        }}
      >
        <div style={{ ...AppTypography.titleLarge, marginBottom: 12 }}>{partnerName} today</div>
        <div style={{ fontSize: 14 }}>Feeling {mood.moodEmoji}</div>
        {mood.need != null && (
          <>
            <div style={{ height: 12 }} />
            <div style={{ fontSize: 14 }}>{HeartNeeds[mood.need]}</div>
            <div style={{ height: 16 }} />
            <button
              type="button"
              className="bare-button"
              disabled={saving || isAck}
              onClick={handleAck}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: 8,
                padding: '10px 18px',
                borderRadius: 999,
                background: isAck ? withAlpha(AppColors.moonlight, 0.12) : AppColors.deepRose,
                color: AppColors.petalWhite,
                fontSize: 14,
                fontWeight: 600,
              }}
            >
              <Icon name="favorite_border" size={18} color={AppColors.petalWhite} />
              <span>{isAck ? 'You let them know you are here' : saving ? 'Sending...' : 'I am here for you'}</span>
            </button>
          </>
        )}
        {error && <div style={{ color: AppColors.error, marginTop: 8 }}>{error}</div>}
      </div>
    </div>
  );
}
