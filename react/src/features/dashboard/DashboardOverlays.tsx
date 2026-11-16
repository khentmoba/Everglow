// Port of lib/features/dashboard/presentation/widgets/dashboard_overlays.dart
// and dashboard_actions.dart.
import { useState, type ReactNode } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../../core/services/auth';
import { useValue } from '../../core/system/store';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { CssCurves, orZero } from '../../core/theme/motion';
import { shadowLayer, insetBorder } from '../../core/theme/paint';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { EverglowGuardian } from '../guardian/EverglowGuardian';
import { guardianController } from '../guardian/guardianController';
import { MoodPicker } from '../heartbeat/MoodPicker';
import { moodController } from '../heartbeat/moodService';
import { PartnerStatusIndicator } from '../heartbeat/PartnerStatusIndicator';

export const kTopActionsInset = 24;
export const kTopActionsSize = 54;
export const kTopActionsGap = 14;
export const kTopActionsReserve = kTopActionsInset + kTopActionsSize + 20;
export const kTopActionsRowRight = 24 + kTopActionsSize + kTopActionsGap;
export const kMoodPromptTop = kTopActionsReserve + 34;

export function DashboardOverlays() {
  const auth = useAuth();
  const navigate = useNavigate();
  const isMoodPromptVisible = useValue(guardianController.isMoodPromptVisible);

  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
      {/* Bottom-right: Motchi avatar + Guardian */}
      <div
        style={{
          position: 'absolute',
          bottom: 24,
          right: 24,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-end',
          pointerEvents: 'auto',
        }}
      >
        <FloatingAction tooltip="Open Motchi AI assistant" onTap={() => navigate('/motchi')}>
          <img
            src="/images/motchi_avatar.webp"
            alt="Motchi"
            width={48}
            height={48}
            style={{ width: 48, height: 48, borderRadius: '50%', objectFit: 'cover', display: 'block' }}
          />
        </FloatingAction>
        <div style={{ height: 12 }} />
        <EverglowGuardian />
      </div>

      {/* Top-left: Creator tools for Khent */}
      {auth.currentUser === 'khentsgdz' && (
        <div style={{ position: 'absolute', top: kTopActionsInset, left: 24, pointerEvents: 'auto' }}>
          <FloatingAction tooltip="Open creator tools" onTap={() => navigate('/motchi')}>
            <Icon name="favorite" size={26} color={AppColors.roseQuartz} />
          </FloatingAction>
        </div>
      )}

      {/* Top-right row: Partner status, mood toggle, canvas */}
      <div
        style={{
          position: 'absolute',
          top: kTopActionsInset,
          right: kTopActionsRowRight,
          display: 'flex',
          alignItems: 'center',
          gap: kTopActionsGap,
          pointerEvents: 'auto',
        }}
      >
        <PartnerStatusIndicator />
        <DashboardActions />
        <FloatingAction tooltip="Open Everglow Canvas" onTap={() => navigate('/canvas')}>
          <Icon name="brush" size={26} color={AppColors.roseQuartz} />
        </FloatingAction>
      </div>

      {/* Top-right: Sanctuary chat */}
      <div style={{ position: 'absolute', top: kTopActionsInset, right: 24, pointerEvents: 'auto' }}>
        <FloatingAction tooltip="Open Sanctuary chat" filled onTap={() => navigate('/sanctuary')}>
          <Icon name="chat_bubble_outline" size={26} color={AppColors.petalWhite} />
        </FloatingAction>
      </div>

      {isMoodPromptVisible && (
        <div style={{ position: 'absolute', top: kMoodPromptTop, right: 24, pointerEvents: 'auto', zIndex: 20 }}>
          <MoodPicker />
        </div>
      )}
    </div>
  );
}

function DashboardActions() {
  const hasSubmitted = useValue(moodController.hasSubmittedToday);
  const isVisible = useValue(guardianController.isMoodPromptVisible);
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);

  const label = isVisible ? 'Dismiss mood picker' : 'Open mood picker';
  const tip = isVisible ? 'Dismiss mood picker' : hasSubmitted ? 'Update your check-in' : 'Open mood picker';

  return (
    <Tooltip message={tip}>
      <div style={{ position: 'relative', width: 54, height: 54 }}>
        {hovered && (
          <div
            style={shadowLayer({ color: withAlpha(AppColors.blushGold, 0.4), blur: 22, spread: -2 }, { circle: true })}
            aria-hidden
          />
        )}
        <div
          style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.2), blur: 15, offset: [0, 5] }, { circle: true })}
          aria-hidden
        />
        <button
          type="button"
          className="bare-button"
          aria-label={label}
          onMouseEnter={() => setHovered(true)}
          onMouseLeave={() => {
            setHovered(false);
            setPressed(false);
          }}
          onPointerDown={() => setPressed(true)}
          onPointerUp={() => setPressed(false)}
          onPointerCancel={() => setPressed(false)}
          onClick={() => {
            if (isVisible) guardianController.dismissMoodPrompt();
            else guardianController.triggerMoodPrompt();
          }}
          style={{
            position: 'relative',
            width: 54,
            height: 54,
            borderRadius: '50%',
            background: withAlpha(AppColors.moonlight, hovered ? 0.22 : 0.12),
            ...insetBorder(withAlpha(AppColors.blushGold, hovered ? 0.85 : 0.55), 1.5),
            transform: `scale(${pressed ? 0.9 : hovered ? 1.08 : 1})`,
            transition: `transform ${orZero(160)}ms ${CssCurves.easeOutStrong}, background ${orZero(160)}ms ${CssCurves.easeOutStrong}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Icon name={isVisible ? 'favorite' : 'favorite_border'} size={26} color={AppColors.roseQuartz} />
        </button>
      </div>
    </Tooltip>
  );
}

function FloatingAction({
  children,
  onTap,
  tooltip,
  filled = false,
}: {
  children: ReactNode;
  onTap: () => void;
  tooltip: string;
  filled?: boolean;
}) {
  const [hovered, setHovered] = useState(false);
  const [pressed, setPressed] = useState(false);

  return (
    <Tooltip message={tooltip}>
      <div style={{ position: 'relative', width: kTopActionsSize, height: kTopActionsSize }}>
        {hovered && (
          <div
            style={shadowLayer(
              {
                color: withAlpha(filled ? AppColors.auroraRose : AppColors.blushGold, 0.4),
                blur: 22,
                spread: -2,
              },
              { circle: true },
            )}
            aria-hidden
          />
        )}
        <div
          style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.25), blur: 15, offset: [0, 5] }, { circle: true })}
          aria-hidden
        />
        <button
          type="button"
          className="bare-button"
          aria-label={tooltip}
          onMouseEnter={() => setHovered(true)}
          onMouseLeave={() => {
            setHovered(false);
            setPressed(false);
          }}
          onPointerDown={() => setPressed(true)}
          onPointerUp={() => setPressed(false)}
          onPointerCancel={() => setPressed(false)}
          onClick={onTap}
          style={{
            position: 'relative',
            width: kTopActionsSize,
            height: kTopActionsSize,
            borderRadius: '50%',
            background: filled ? AppColors.deepRose : withAlpha(AppColors.moonlight, hovered ? 0.22 : 0.12),
            ...insetBorder(filled ? withAlpha(AppColors.auroraRose, 0.7) : withAlpha(AppColors.blushGold, hovered ? 0.85 : 0.55), 1.5),
            transform: `scale(${pressed ? 0.9 : hovered ? 1.08 : 1})`,
            transition: `transform ${orZero(160)}ms ${CssCurves.easeOutStrong}, background ${orZero(160)}ms ${CssCurves.easeOutStrong}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {children}
        </button>
      </div>
    </Tooltip>
  );
}
