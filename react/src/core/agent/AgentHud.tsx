// Port of lib/core/agent/agent_hud.dart: the floating developer toolbar in
// agent mode (local testing only, never on the live site).
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Icon } from '../../shared/widgets/Icon';
import { useValue } from '../system/store';
import { authService } from '../services/auth';
import { AppColors, withAlpha } from '../theme/colors';
import { boxShadow, letterSpacing } from '../theme/paint';
import { AppTypography } from '../theme/typography';
import { paddedTapTargets, visualDensity } from '../system/platform';
import { AgentMode } from './agentMode';

const ROUTES: Array<{ label: string; route: string; icon: string }> = [
  { label: 'Dashboard', route: '/dashboard', icon: 'home' },
  { label: 'Cinema', route: '/cinema', icon: 'movie' },
  { label: 'Anime', route: '/anime', icon: 'smart_display' },
  { label: 'Mangacelestia', route: '/manga', icon: 'auto_stories' },
  { label: 'Books', route: '/books', icon: 'menu_book' },
  { label: 'Sanctuary', route: '/sanctuary', icon: 'chat_bubble' },
  { label: 'Gallery', route: '/gallery', icon: 'photo_library' },
  { label: 'Journal', route: '/journal', icon: 'book' },
  { label: 'Tonight', route: '/tonight', icon: 'nightlife' },
  { label: 'Play Zone', route: '/play-zone', icon: 'sports_esports' },
  { label: 'Academy', route: '/academy', icon: 'school' },
  { label: 'Garden', route: '/garden', icon: 'local_florist' },
  { label: 'Starlight', route: '/starlight', icon: 'star' },
  { label: 'Calendar', route: '/calendar', icon: 'calendar_month' },
  { label: 'Trip Kit', route: '/trips', icon: 'flight_takeoff' },
  { label: 'Canvas', route: '/canvas', icon: 'palette' },
  { label: 'Bucket List', route: '/bucket-list', icon: 'checklist' },
  { label: 'Money', route: '/money', icon: 'account_balance_wallet' },
  { label: 'Jukebox', route: '/jukebox', icon: 'music_note' },
  { label: 'Doorway', route: '/', icon: 'meeting_room' },
];

const PROFILE_LABEL: Record<string, string> = {
  khentsgdz: 'Khent (Couple)',
  clairjassen: 'Clair (Couple)',
  breyan: 'Cinema (Guest)',
};

function viewportReport(): string {
  const vv = window.visualViewport;
  const standalone = window.matchMedia('(display-mode: standalone)').matches;
  return [
    'Screen measurement 2 (CSS pixels)',
    `Installed: ${standalone}`,
    `Screen: ${screen.width} x ${screen.height}`,
    `Window: ${window.innerWidth} x ${window.innerHeight}`,
    `Visual: ${vv?.height.toFixed(0)} offset=${vv?.offsetTop.toFixed(0)} scale=${vv?.scale}`,
  ].join('\n');
}

/** Rendered once at the app root, above every page. */
export function AgentHudOverlay() {
  const active = useValue(AgentMode.isActive);
  const show = useValue(AgentMode.showHud);
  if (!active || !show) return null;
  return (
    <div
      style={{
        position: 'fixed',
        left: 'calc(16px + var(--safe-left, env(safe-area-inset-left, 0px)))',
        right: 'calc(16px + var(--safe-right, env(safe-area-inset-right, 0px)))',
        bottom: 'calc(16px + var(--safe-bottom, env(safe-area-inset-bottom, 0px)))',
        zIndex: 1000,
        display: 'flex',
        justifyContent: 'center',
        pointerEvents: 'none',
      }}
    >
      <AgentHud />
    </div>
  );
}

function AgentHud() {
  const collapsed = useValue(AgentMode.hudCollapsed);
  const profile = useValue(AgentMode.activeProfile);
  const navigate = useNavigate();
  const [report, setReport] = useState<string | null>(null);

  if (collapsed) {
    return (
      <div style={{ flex: 1, display: 'flex', justifyContent: 'flex-end', pointerEvents: 'none' }}>
        <button
          className="bare-button"
          aria-label="Expand agent toolbar"
          onClick={() => (AgentMode.hudCollapsed.value = false)}
          style={{
            pointerEvents: 'auto',
            padding: 10,
            borderRadius: '50%',
            background: withAlpha(AppColors.velvet, 0.92),
            border: `1.5px solid ${withAlpha(AppColors.auroraGold, 0.6)}`,
            boxShadow: boxShadow([{ color: withAlpha(AppColors.black, 0.4), blur: 12, offset: [0, 4] }]),
            display: 'flex',
          }}
        >
          <Icon name="bolt" size={20} color={AppColors.auroraGold} />
        </button>
      </div>
    );
  }

  const cycleProfile = () => {
    const next = profile === 'khentsgdz' ? 'clairjassen' : profile === 'clairjassen' ? 'breyan' : 'khentsgdz';
    AgentMode.switchProfile(next);
    authService.enableAgentSession(next);
  };

  // Material 3 TextButton: 12/8 padding, at least 64x40 (less 4px per
  // density step), inside a 48px tap target on phones.
  const buttonMinHeight = 40 + visualDensity * 4;
  const tapHeight = paddedTapTargets ? Math.max(48, buttonMinHeight) : buttonMinHeight;

  return (
    <div
      style={{
        pointerEvents: 'auto',
        width: '100%',
        maxWidth: 820,
        padding: '8px 12px',
        background: withAlpha(AppColors.inkDeep, 0.95),
        borderRadius: 20,
        border: `1px solid ${withAlpha(AppColors.auroraGold, 0.45)}`,
        boxShadow: boxShadow([{ color: withAlpha(AppColors.black, 0.5), blur: 18, offset: [0, 6] }]),
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', alignSelf: 'stretch' }}>
        <Icon name="bolt" size={16} color={AppColors.auroraGold} />
        <div style={{ width: 6 }} />
        <div style={{ ...AppTypography.outfitHeading, fontSize: 10.5, ...letterSpacing(1.2), color: AppColors.auroraGold }}>
          AGENT SANDBOX
        </div>
        <div style={{ width: 10 }} />
        <button
          className="bare-button"
          onClick={cycleProfile}
          style={{
            padding: '3px 8px',
            background: withAlpha(AppColors.velvet, 0.8),
            borderRadius: 8,
            border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <div style={{ fontSize: 11, color: AppColors.petalWhite, fontWeight: 600, ...letterSpacing(0.25) }}>
            {PROFILE_LABEL[profile] ?? profile}
          </div>
          <div style={{ width: 4 }} />
          <Icon name="swap_horiz" size={13} color={AppColors.blushGold} />
        </button>
        <div style={{ flex: 1 }} />
        <button
          className="bare-button"
          aria-label="Collapse HUD (clean screenshot mode)"
          onClick={() => (AgentMode.hudCollapsed.value = true)}
          style={{ padding: 4, borderRadius: 999, display: 'flex' }}
        >
          <Icon name="keyboard_arrow_down" size={18} color={AppColors.blushGold} />
        </button>
      </div>
      <div style={{ height: 6 }} />
      <button
        className="bare-button"
        onClick={() => setReport((r) => (r == null ? viewportReport() : null))}
        style={{ height: tapHeight, display: 'flex', alignItems: 'center' }}
      >
        <div
          style={{
            minWidth: 64 + visualDensity * 4,
            minHeight: buttonMinHeight,
            padding: '8px 12px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <div style={{ ...AppTypography.labelLarge, color: AppColors.auroraGold, ...letterSpacing(0.6) }}>
            {report == null ? 'Screen edges' : 'Close measurement'}
          </div>
        </div>
      </button>
      {report != null && (
        <div style={{ maxHeight: 280, overflowY: 'auto', alignSelf: 'stretch' }}>
          <div style={{ color: AppColors.petalWhite, fontSize: 12, lineHeight: 1.35, whiteSpace: 'pre-wrap' }}>{report}</div>
        </div>
      )}
      <div className="no-scrollbar" style={{ overflowX: 'auto', alignSelf: 'stretch' }}>
        <div style={{ display: 'flex', width: 'max-content' }}>
          {ROUTES.map((item) => (
            <div key={item.route} style={{ paddingRight: 6 }}>
              <button
                className="bare-button"
                onClick={() => navigate(item.route)}
                style={{
                  padding: '4px 9px',
                  background: withAlpha(AppColors.velvet, 0.6),
                  borderRadius: 10,
                  border: `1px solid ${withAlpha(AppColors.moonlight, 0.15)}`,
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <Icon name={item.icon} size={13} color={withAlpha(AppColors.petalWhite, 0.85)} />
                <div style={{ width: 4 }} />
                <div style={{ fontSize: 11, color: withAlpha(AppColors.petalWhite, 0.9), ...letterSpacing(0.25) }}>{item.label}</div>
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
