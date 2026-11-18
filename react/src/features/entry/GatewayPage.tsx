// Port of lib/features/entry/presentation/pages/gateway_page.dart.
// Still to port with their features: the dashboard load veil and the
// cinema watch-list migration that start after a successful unlock.
import { useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useAnimatedValue } from '../../core/anim/controller';
import { AgentMode } from '../../core/agent/agentMode';
import { deepLinkTarget } from '../../core/router/routeHelpers';
import { authService, useAuth } from '../../core/services/auth';
import { Logger } from '../../core/system/logger';
import { useValue } from '../../core/system/store';
import { TvMode } from '../../core/system/tvMode';
import { useOnline, useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { Curves, orZero } from '../../core/theme/motion';
import { boxShadow, letterSpacing, linear, radial } from '../../core/theme/paint';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { Icon } from '../../shared/widgets/Icon';
import { showSnackBar } from '../../shared/widgets/SnackBar';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { AnimatedDoor, archPath, doorScale } from './AnimatedDoor';
import { GatewayNotifier, type GatewayState } from './gatewayState';
import { PasscodeInput } from './PasscodeInput';
import { PetalShower } from './PetalShower';

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

export function GatewayPage() {
  const [notifier] = useState(() => new GatewayNotifier());
  useSyncExternalStore(notifier.subscribe, notifier.getVersion);
  const navigate = useNavigate();
  const location = useLocation();
  const viewport = useViewport();
  const hasNavigated = useRef(false);
  const lastProcessed = useRef<GatewayState | null>(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  notifier.verifyCouplePasscode = (code) => authService.verifyCouplePasscode(code);
  notifier.tryOfflineUnlock = (code) => authService.tryOfflineRememberedLogin(code);
  notifier.hasOfflineRememberedCode = () => authService.hasOfflineRememberedCode;

  const postLoginTarget = (cinemaOnly: boolean, fallback: string) =>
    deepLinkTarget(location.search, cinemaOnly) ?? fallback;

  const state = notifier.currentState;

  useEffect(() => {
    if (state === lastProcessed.current) return;
    lastProcessed.current = state;

    if (state === 'unlocking') {
      const isCinemaOnly = authService.isCinemaOnlyUser;
      const authTask = authService.ensureAuthenticated();
      void authTask
        .catch((e) => {
          Logger.e('Error during passcode login', e);
          void authService.ensureAuthenticated().catch(() => {});
        })
        .finally(() => {
          if (authService.lastAuthError != null && mounted.current) {
            showSnackBar(authService.lastAuthError, { background: AppColors.orange700, duration: 4000 });
          }
        });

      void Promise.all([delay(900), authTask.catch(() => {})]).then(() => {
        if (!mounted.current || hasNavigated.current) return;
        const hasRealSession = authService.user != null && !authService.isAnonymousSession;
        if (!hasRealSession && !authService.isOfflineMode) {
          notifier.setFailureReason('connection');
          notifier.updateState('error');
          void delay(500).then(() => {
            if (!mounted.current || hasNavigated.current) return;
            notifier.clearInput();
            notifier.updateState('awaitingInput');
          });
          return;
        }
        if (isCinemaOnly) {
          hasNavigated.current = true;
          navigate(postLoginTarget(true, '/cinema'));
        } else {
          notifier.updateState('revealingSite');
        }
      });
    } else if (state === 'revealingSite') {
      void delay(1100).then(() => {
        if (mounted.current) notifier.updateState('complete');
      });
    } else if (state === 'complete' && !hasNavigated.current) {
      hasNavigated.current = true;
      navigate(postLoginTarget(false, '/dashboard'));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state]);

  const isRevealing = state === 'revealingSite' || state === 'complete';

  const agentLogin = (profile: string) => {
    AgentMode.enable(profile);
    authService.enableAgentSession(profile);
    const isCinema = profile === 'breyan';
    hasNavigated.current = true;
    navigate(postLoginTarget(isCinema, isCinema ? '/cinema' : '/dashboard'));
  };

  const agentJump = (route: string) => {
    AgentMode.enable('khentsgdz');
    authService.enableAgentSession('khentsgdz');
    hasNavigated.current = true;
    navigate(route);
  };

  const size: [number, number] = [viewport.width, viewport.height];

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        overflow: 'hidden',
        background: linear([AppColors.inkDeep, AppColors.twilight, AppColors.velvet], {
          begin: [0, -1],
          end: [0, 1],
          stops: [0, 0.55, 1],
        }),
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          pointerEvents: 'none',
          backgroundImage: radial([withAlpha(AppColors.deepRose, 0.22), AppColors.transparent], {
            center: [-0.7, -0.8],
            radius: 0.9,
            size,
          }),
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          pointerEvents: 'none',
          backgroundImage: radial([withAlpha(AppColors.softLavender, 0.16), AppColors.transparent], {
            center: [0.85, 0.9],
            radius: 0.9,
            size,
          }),
        }}
      />
      <MainContent isRevealing={isRevealing} />
      {state !== 'complete' && (
        <GatewayOverlay notifier={notifier} state={state} onAgentLogin={agentLogin} onAgentJump={agentJump} />
      )}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        <PetalShower isVisible={!isRevealing} />
      </div>
    </div>
  );
}

function GatewayOverlay({
  notifier,
  state,
  onAgentLogin,
  onAgentJump,
}: {
  notifier: GatewayNotifier;
  state: GatewayState;
  onAgentLogin: (profile: string) => void;
  onAgentJump: (route: string) => void;
}) {
  const viewport = useViewport();
  const isTv = useValue(TvMode.isTvMode);
  const isRevealing = state === 'revealingSite' || state === 'complete';
  const zoom = useAnimatedValue(isRevealing ? 1 : 0, orZero(1100), Curves.easeInQuint);
  const showKeypad = state === 'initialLoad' || state === 'awaitingInput' || state === 'evaluating' || state === 'error';
  const showDevBar = AgentMode.isLocalDev && (state === 'initialLoad' || state === 'awaitingInput' || state === 'error');

  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: state === 'revealingSite' ? 'none' : undefined }}>
      <DoorMask zoom={zoom} scale={doorScale(viewport)} />
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <AnimatedDoor
          isUnlocked={state === 'unlocking' || state === 'revealingSite' || state === 'complete'}
          isError={state === 'error'}
          isRevealing={isRevealing}
          onEntranceComplete={() => {
            if (notifier.currentState === 'initialLoad') notifier.updateState('awaitingInput');
          }}
          keypad={
            <div
              style={{
                opacity: showKeypad ? 1 : 0,
                transition: `opacity ${orZero(500)}ms linear`,
                pointerEvents: showKeypad ? undefined : 'none',
              }}
            >
              <div
                style={{
                  transform: `scale(${isTv ? 1.02 : 0.8})`,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                }}
              >
                <PasscodeInput
                  input={notifier.currentInput}
                  isError={state === 'error'}
                  isVerifying={state === 'evaluating'}
                  failureReason={notifier.lastFailureReason}
                  onDigitPressed={notifier.appendDigit}
                  onBackspace={notifier.backspace}
                  onClear={notifier.clearInput}
                />
                <OfflineRememberHint />
              </div>
            </div>
          }
        />
      </div>
      <div
        style={{
          position: 'absolute',
          top: 'calc(16px + env(safe-area-inset-top))',
          right: 'calc(16px + env(safe-area-inset-right))',
        }}
      >
        <TvModeToggle />
      </div>
      {showDevBar && (
        <div style={{ position: 'absolute', bottom: 24, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
          <DevLoginBar onAgentLogin={onAgentLogin} onAgentJump={onAgentJump} />
        </div>
      )}
    </div>
  );
}

/** The dark cover with a door-shaped hole that grows as the site opens. */
function DoorMask({ zoom, scale }: { zoom: number; scale: number }) {
  const { width, height } = useViewport();
  const zoomScale = 1 + 4 * zoom;
  const w = 330 * scale * zoomScale - 8 * zoomScale;
  const h = 560 * scale * zoomScale - 8 * zoomScale;
  const hole = archPath(w, h, width / 2 - w / 2, height / 2 - h / 2);
  return (
    <svg width={width} height={height} style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }} aria-hidden>
      <defs>
        <linearGradient id="gateway-mask" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={AppColors.inkDeep} />
          <stop offset="1" stopColor={AppColors.twilight} />
        </linearGradient>
      </defs>
      <path fillRule="evenodd" fill="url(#gateway-mask)" d={`M0 0 H${width} V${height} H0 Z ${hole}`} />
    </svg>
  );
}

function MainContent({ isRevealing }: { isRevealing: boolean }) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    if (!isRevealing) return;
    const frame = requestAnimationFrame(() => setShown(true));
    return () => cancelAnimationFrame(frame);
  }, [isRevealing]);
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        opacity: isRevealing && shown ? 1 : 0,
        transition: 'opacity 500ms linear',
      }}
    >
      {isRevealing && (
        <>
          <EverglowBackground
            baseColor={AppColors.inkDeep}
            glows={[
              { color: AppColors.deepRose, alignment: [-0.7, -0.85], size: 0.9, opacity: 0.14 },
              { color: AppColors.softLavender, alignment: [0.85, 0.95], size: 0.8, opacity: 0.1 },
              { color: AppColors.auroraGold, alignment: [0.1, 0.45], size: 0.6, opacity: 0.05 },
            ]}
          />
          <div
            style={{
              position: 'absolute',
              inset: 0,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Icon name="favorite" size={26} color={AppColors.auroraRose} />
            <div style={{ height: 10 }} />
            <span style={{ color: withAlpha(AppColors.petalWhite, 0.85), fontSize: 11, fontWeight: 600, ...letterSpacing(4) }}>
              EVERGLOW
            </span>
            <div style={{ height: 14 }} />
            <span style={{ color: withAlpha(AppColors.petalWhite, 0.45), fontSize: 10, ...letterSpacing(0.3) }}>
              opening your story…
            </span>
          </div>
        </>
      )}
    </div>
  );
}

function OfflineRememberHint() {
  const auth = useAuth();
  const online = useOnline();
  const remembered = auth.currentUser;
  const name = remembered === 'clairjassen' ? 'Clair' : remembered === 'khentsgdz' ? 'Khent' : null;
  if (name == null || online) return null;
  return (
    <div style={{ padding: '10px 24px 0' }}>
      <div
        className="clamp-3"
        style={{ textAlign: 'center', color: withAlpha(AppColors.blushGold, 0.92), fontSize: 12, lineHeight: 1.25 }}
      >
        {`No connection — welcome back, ${name}. Your code still opens your saved copy.`}
      </div>
    </div>
  );
}

function TvModeToggle() {
  const isTv = useValue(TvMode.isTvMode);
  const fg = isTv ? AppColors.auroraGold : AppColors.petalWhite;
  return (
    <Tooltip message={isTv ? 'TV Navigation Mode (Active)' : 'Enable TV Navigation Mode'}>
      <button
        type="button"
        className="bare-button"
        onClick={() => TvMode.toggle()}
        style={{
          display: 'flex',
          alignItems: 'center',
          padding: '7px 12px',
          borderRadius: 20,
          background: isTv ? withAlpha(AppColors.auroraGold, 0.22) : withAlpha(AppColors.velvet, 0.65),
          border: `${isTv ? 1.8 : 1}px solid ${isTv ? AppColors.auroraGold : withAlpha(AppColors.moonlight, 0.35)}`,
          boxShadow: isTv ? boxShadow([{ color: withAlpha(AppColors.auroraGold, 0.45), blur: 12, spread: 1 }]) : 'none',
        }}
      >
        <Icon name="tv" size={16} color={fg} />
        <div style={{ width: 6 }} />
        <span style={{ color: fg, fontSize: 12, fontWeight: 600 }}>{isTv ? 'TV Mode: ON' : 'TV Mode'}</span>
      </button>
    </Tooltip>
  );
}

const DESTINATIONS: Array<{ label: string; route: string; icon: string }> = [
  { label: 'Cinema', route: '/cinema', icon: 'movie' },
  { label: 'Anime', route: '/anime', icon: 'smart_display' },
  { label: 'Mangacelestia', route: '/manga', icon: 'auto_stories' },
  { label: 'Books', route: '/books', icon: 'menu_book' },
  { label: 'Dashboard', route: '/dashboard', icon: 'home' },
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
  { label: 'Jukebox', route: '/jukebox', icon: 'music_note' },
  { label: 'Canvas', route: '/canvas', icon: 'palette' },
  { label: 'Bucket List', route: '/bucket-list', icon: 'checklist' },
  { label: 'Money', route: '/money', icon: 'account_balance_wallet' },
];

function DevLoginBar({
  onAgentLogin,
  onAgentJump,
}: {
  onAgentLogin: (profile: string) => void;
  onAgentJump: (route: string) => void;
}) {
  const chip = (label: string, onTap: () => void, alpha: number, border: number) => (
    <button
      type="button"
      className="bare-button"
      onClick={onTap}
      style={{
        flexShrink: 0,
        padding: '4px 10px',
        borderRadius: 12,
        background: withAlpha(AppColors.inkDeep, alpha),
        border: `1px solid ${withAlpha(AppColors.blushGold, border)}`,
        color: AppColors.petalWhite,
        fontSize: 11,
        fontWeight: 500,
      }}
    >
      {label}
    </button>
  );
  return (
    <div
      style={{
        margin: '0 16px',
        maxWidth: 860,
        padding: '8px 14px',
        borderRadius: 20,
        background: withAlpha(AppColors.velvet, 0.95),
        border: `1px solid ${withAlpha(AppColors.auroraGold, 0.4)}`,
        boxShadow: boxShadow([{ color: withAlpha(AppColors.black, 0.45), blur: 16, offset: [0, 4] }]),
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        minWidth: 0,
      }}
    >
      {/* Flutter's Row never wraps: centered when it fits, starts at the left edge when it doesn't. */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'safe center', whiteSpace: 'nowrap', alignSelf: 'stretch' }}>
        <Icon name="bolt" size={16} color={AppColors.auroraGold} />
        <div style={{ width: 6 }} />
        <span style={{ color: withAlpha(AppColors.petalWhite, 0.9), fontSize: 12, fontWeight: 700 }}>Agent Fast-Jump:</span>
        <div style={{ width: 8 }} />
        {chip('👤 Khent', () => onAgentLogin('khentsgdz'), 0.8, 0.3)}
        <div style={{ width: 6 }} />
        {chip('🌸 Clair', () => onAgentLogin('clairjassen'), 0.8, 0.3)}
        <div style={{ width: 6 }} />
        {chip('🍿 Guest', () => onAgentLogin('breyan'), 0.8, 0.3)}
      </div>
      <div style={{ height: 6 }} />
      <div className="no-scrollbar" style={{ display: 'flex', overflowX: 'auto', maxWidth: '100%' }}>
        {DESTINATIONS.map((d) => (
          <div key={d.route} style={{ paddingRight: 6, flexShrink: 0 }}>
            <button
              type="button"
              className="bare-button"
              onClick={() => onAgentJump(d.route)}
              style={{
                display: 'flex',
                alignItems: 'center',
                padding: '4px 9px',
                borderRadius: 12,
                background: withAlpha(AppColors.inkDeep, 0.85),
                border: `1px solid ${withAlpha(AppColors.blushGold, 0.35)}`,
              }}
            >
              <Icon name={d.icon} size={13} color={AppColors.auroraGold} />
              <div style={{ width: 4 }} />
              <span style={{ color: AppColors.petalWhite, fontSize: 11, fontWeight: 500, whiteSpace: 'nowrap' }}>
                {d.label}
              </span>
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
