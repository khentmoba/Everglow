// Port of lib/features/heartbeat/presentation/widgets/mood_picker.dart + heart_emoji.dart.
import { useState } from 'react';
import { useAuth } from '../../core/services/auth';
import { useValue } from '../../core/system/store';
import { useViewport } from '../../core/system/viewport';
import { AppColors, Derived, withAlpha } from '../../core/theme/colors';
import { AppRadius } from '../../core/theme/layout';
import { linear, shadowLayer } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { guardianController } from '../guardian/guardianController';
import { HeartNeeds, isCurrentAt, moodController, moodService, type HeartNeed } from './moodService';

const MOODS = [
  { emoji: '💜', score: 1, color: AppColors.softLavender, label: 'heavy' },
  { emoji: '☁️', score: 2, color: AppColors.mutedPurple, label: 'low' },
  { emoji: '🌸', score: 3, color: AppColors.roseQuartz, label: 'okay' },
  { emoji: '💖', score: 4, color: AppColors.auroraRose, label: 'loved' },
  { emoji: '✨', score: 5, color: AppColors.deepRose, label: 'radiant' },
] as const;

export function MoodPicker() {
  const { width, height } = useViewport();
  const auth = useAuth();
  const [need, setNeed] = useState<HeartNeed | null>(null);
  const isSaving = useValue(moodController.isSaving);
  const selectedScore = useValue(moodController.selectedScore);
  const saveError = useValue(moodController.saveError);
  const partnerName = auth.partnerName;
  const currentUser = auth.currentUser ?? '';
  const latestMood = useSource(
    () => (currentUser ? moodService.watchLatestMood(currentUser) : null),
    [currentUser],
    null,
  );

  const boxWidth = Math.max(0, Math.min(360, width - 48));
  const maxHeight = Math.max(120, Math.min(600, height - 190));

  return (
    <div style={{ position: 'relative', width: boxWidth }}>
      <div
        style={shadowLayer(
          { color: withAlpha(AppColors.deepRose, 0.3), blur: 30, spread: 5 },
          { radius: AppRadius.x3 },
        )}
        aria-hidden
      />
      <div
        style={shadowLayer(
          { color: withAlpha(AppColors.auroraGold, 0.15), blur: 40, spread: -6 },
          { radius: AppRadius.x3 },
        )}
        aria-hidden
      />
      <div
        role="region"
        aria-label="How is your heart today? 5 moods, tap to select"
        style={{
          position: 'relative',
          width: boxWidth,
          maxHeight,
          overflowY: 'auto',
          padding: '16px 24px',
          borderRadius: AppRadius.x3,
          border: `1.5px solid ${withAlpha(AppColors.auroraGold, 0.4)}`,
          background: linear([withAlpha(AppColors.velvet, 0.95), withAlpha(AppColors.inkDeep, 0.95)], {
            begin: [-1, -1],
            end: [1, 1],
            size: [boxWidth, 240],
          }),
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <div style={{ paddingBottom: 12 }}>
          <span style={{ ...AppTypography.cormorantBold, fontSize: 16, letterSpacing: 0.5 }}>
            How is your heart today?
          </span>
        </div>

        {latestMood && isCurrentAt(latestMood, new Date()) && latestMood.acknowledgedBy != null && (
          <div style={{ paddingBottom: 12 }}>{partnerName} is here for you.</div>
        )}

        <div>Anything you need? Optional, just for today.</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: '4px 6px', marginTop: 4 }}>
          {(Object.keys(HeartNeeds) as HeartNeed[]).map((key) => {
            const selected = need === key;
            return (
              <button
                key={key}
                type="button"
                className="bare-button"
                disabled={isSaving}
                onClick={() => setNeed(selected ? null : key)}
                style={{
                  padding: '6px 12px',
                  borderRadius: 999,
                  background: selected ? withAlpha(AppColors.deepRose, 0.4) : Derived.surfaceGlass,
                  border: `1px solid ${selected ? AppColors.auroraRose : Derived.border}`,
                  ...AppTypography.titleSmall,
                }}
              >
                {HeartNeeds[key]}
              </button>
            );
          })}
        </div>

        {saveError && <div style={{ color: AppColors.error, marginTop: 6 }}>{saveError}</div>}

        <div style={{ height: 12 }} />
        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 4 }}>
          {MOODS.map((m) => (
            <Tooltip key={m.score} message={`${m.label} • ${m.score} of 5`}>
              <button
                type="button"
                className="bare-button"
                aria-label={`${m.label} mood, ${m.score} of 5, ${m.emoji}`}
                onClick={async () => {
                  if (isSaving) return;
                  await moodController.submitMood({
                    username: currentUser,
                    score: m.score,
                    emoji: m.emoji,
                    uid: auth.uid,
                    need,
                  });
                  if (moodController.saveError.value == null) {
                    guardianController.dismissMoodPrompt();
                    showSnackBar(`Sending your love to ${partnerName}...`, { background: AppColors.deepRose });
                  }
                }}
                style={{
                  padding: 8,
                  borderRadius: '50%',
                  transform: selectedScore === m.score ? 'scale(1.3)' : 'scale(1)',
                  transition: 'transform 300ms cubic-bezier(0.175, 0.885, 0.32, 1.275)',
                  boxShadow:
                    selectedScore === m.score
                      ? `0 0 15px 5px ${withAlpha(m.color, 0.5)}`
                      : undefined,
                }}
              >
                <span style={{ fontSize: 32, lineHeight: 1.2, display: 'block' }}>{m.emoji}</span>
              </button>
            </Tooltip>
          ))}
        </div>
      </div>
    </div>
  );
}
