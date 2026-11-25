// Port of lib/features/dashboard/presentation/screens/dashboard_screen.dart
// and dashboard_screen_sections.dart.
import { lazy, startTransition, Suspense, useCallback, useEffect, useRef, useState } from 'react';
import { scheduleIdleMediaPrefetch } from '../../core/router/routeChunks';
import { useRememberedScroll } from '../../core/router/scrollMemory';
import { useAuth } from '../../core/services/auth';
import { useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint, AppSpacing, responsive } from '../../core/theme/layout';
import { Align, letterSpacing, lineHeight, linear, shadowLayer, insetBorder } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { useSource } from '../../core/utils/liveSource';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { EverglowBackground, type RadialGlow } from '../../shared/widgets/EverglowBackground';
import { EverglowSectionHeader } from '../../shared/widgets/EverglowSectionHeader';
import { Icon } from '../../shared/widgets/Icon';
import { DailyBloom } from '../daily_bloom/DailyBloom';
import { guardianController } from '../guardian/guardianController';
import { guardianService } from '../guardian/guardianService';
import { moodController } from '../heartbeat/moodService';
import { XpProgressSection } from '../xp/XpProgressSection';
import { AnniversaryMetrics } from './AnniversaryMetrics';
import { DashboardJumpBar } from './DashboardJumpBar';
import { DashboardLoadVeil, DashboardLoadVeilControl } from './DashboardLoadVeil';
import { BreathingEmblem, DashboardAmbience, PulseHeart, ShimmerTitle } from './DashboardMotion';
import { DashboardOverlays, kTopActionsReserveCss } from './DashboardOverlays';
import { DashboardPair, DashboardZoneHeader } from './DashboardZoneHeader';
import { LetterboxView } from './LetterboxView';
import { isNoteUnlocked, letterboxService } from './letterboxService';
import { OnThisDayCard } from './OnThisDayCard';
import { QuickActionTile, type QuickAction } from './QuickActionTile';
import { TonightCard } from './TonightCard';
import { UpcomingCountdowns } from './UpcomingCountdowns';

const loadLowerZones = () => import('./DashboardLowerZones');
const DashboardLowerZones = lazy(() =>
  loadLowerZones()
    .then((m) => ({ default: m.DashboardLowerZones }))
    .catch(() => ({ default: () => <></> })),
);

const DASHBOARD_GLOWS: RadialGlow[] = [
  { color: AppColors.deepRose, alignment: [-0.7, -0.85], size: 0.9, opacity: 0.14 },
  { color: AppColors.softLavender, alignment: [0.85, 0.95], size: 0.8, opacity: 0.1 },
  { color: AppColors.auroraGold, alignment: [0.1, 0.45], size: 0.6, opacity: 0.05 },
];

const PRIMARY_QUICK_ACTIONS: QuickAction[] = [
  { label: 'Cinema', icon: 'movie', route: '/cinema', hue: AppColors.cinemaRed, caption: 'Movies & TV' },
  { label: 'Sanctuary', icon: 'chat_bubble', route: '/sanctuary', hue: AppColors.auroraRose, caption: 'Chat' },
  { label: 'Gallery', icon: 'photo_library', route: '/gallery', hue: AppColors.roseQuartz, caption: 'Memories' },
  { label: 'Motchi', icon: 'auto_awesome', route: '/motchi', hue: AppColors.auroraGold, caption: 'AI companion' },
  { label: 'Letterbox', icon: 'mail_outline', route: '/letterbox', hue: AppColors.blushGold, caption: 'Letters' },
  { label: 'Calendar', icon: 'calendar_month', route: '/calendar', hue: AppColors.warmAmber, caption: 'Dates' },
  { label: 'Tonight', icon: 'nightlife', route: '/tonight', hue: AppColors.auroraRose, caption: 'What to do' },
  { label: 'Journal', icon: 'menu_book', route: '/journal', hue: AppColors.softLavender, caption: 'Diary' },
];

const MORE_QUICK_ACTIONS: QuickAction[] = [
  { label: 'Canvas', icon: 'brush', route: '/canvas', hue: AppColors.softLavender, caption: 'Draw' },
  { label: 'Starlight', icon: 'auto_awesome_mosaic', route: '/starlight', hue: AppColors.auroraLilac, caption: 'Gratitude' },
  { label: 'Bucket List', icon: 'card_travel', route: '/bucket-list', hue: AppColors.auroraTeal, caption: 'Dreams' },
  { label: 'Trip Kit', icon: 'luggage', route: '/trips', hue: AppColors.warmAmber, caption: 'Lakad' },
  { label: 'Money', icon: 'savings', route: '/money', hue: AppColors.auroraGold, caption: 'Wallet' },
  { label: 'Subs', icon: 'subscriptions', route: '/subs', hue: AppColors.warmAmber, caption: 'Tracker' },
  { label: 'Desktop App', icon: 'desktop_windows', route: '/desktop-app', hue: AppColors.blushGold, caption: 'Updates' },
];

export function DashboardPage() {
  const auth = useAuth();
  const { width } = useViewport();
  const scrollRef = useRef<HTMLDivElement>(null);
  const [showLoadVeil, setShowLoadVeil] = useState(() => DashboardLoadVeilControl.consumePasscodeLoaderRequest());
  const [showLowerZones, setShowLowerZones] = useState(false);
  const [requestedZone, setRequestedZone] = useState<string | null>(null);
  const zoneRefs = useRef<Record<string, HTMLDivElement | null>>({});
  const pendingJumpRef = useRef<string | null>(null);
  useRememberedScroll('dashboard', scrollRef, auth.isReady, { persist: false });

  const registerZone = useCallback((id: string, el: HTMLDivElement | null) => {
    zoneRefs.current[id] = el;
    if (el && pendingJumpRef.current === id) {
      pendingJumpRef.current = null;
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, []);

  useEffect(() => {
    if (!auth.isReady || showLowerZones) return;
    const raf = window.requestAnimationFrame(() => {
      void loadLowerZones();
      startTransition(() => setShowLowerZones(true));
    });
    return () => window.cancelAnimationFrame(raf);
  }, [auth.isReady, showLowerZones]);

  const dismissLoadVeil = useCallback(() => setShowLoadVeil(false), []);

  useEffect(() => {
    if (!showLoadVeil) return;
    const failSafe = window.setTimeout(() => setShowLoadVeil(false), 10_000);
    return () => window.clearTimeout(failSafe);
  }, [showLoadVeil]);

  useEffect(() => {
    if (!auth.isReady) return;
    scheduleIdleMediaPrefetch();
    const t = window.setTimeout(() => void guardianService.initialize(), 600);
    const user = auth.currentUser;
    if (user) {
      void moodController.checkTodayStatus(user).then(() => {
        if (!moodController.hasSubmittedToday.value) guardianController.triggerMoodPrompt();
      });
    }
    return () => clearTimeout(t);
  }, [auth.isReady, auth.currentUser]);

  if (!auth.isReady) {
    return (
      <div style={{ position: 'fixed', inset: 0 }}>
        <EverglowBackground baseColor={AppColors.inkDeep} />
        <div style={{ position: 'relative', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <CircularProgress size={24} strokeWidth={2} color={AppColors.deepRose} />
        </div>
      </div>
    );
  }

  const contentMaxWidth = responsive(width, { mobile: 600, tablet: 820, desktop: 980 });

  const jumpTo = (id: string) => {
    setRequestedZone(id);
    const el = zoneRefs.current[id];
    if (el) {
      pendingJumpRef.current = null;
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }
    pendingJumpRef.current = id;
    if (!showLowerZones) setShowLowerZones(true);
  };

  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden' }}>
      <EverglowBackground baseColor={AppColors.inkDeep} glows={DASHBOARD_GLOWS} />
      <DashboardAmbience scrollRef={scrollRef} />

      <div
        ref={scrollRef}
        className="no-scrollbar"
        style={{ position: 'relative', height: '100%', overflowY: 'auto', overflowX: 'hidden' }}
      >
        <div
          style={{
            margin: '0 auto',
            width: '100%',
            maxWidth: contentMaxWidth,
            paddingLeft: 'var(--safe-left, env(safe-area-inset-left, 0px))',
            paddingRight: 'var(--safe-right, env(safe-area-inset-right, 0px))',
          }}
        >
          <div style={{ padding: `${kTopActionsReserveCss} ${AppSpacing.pageH(width)}px 24px` }}>
            <DashboardHeader width={width} />
          </div>
          <div style={{ padding: '8px 24px' }}>
            <XpProgressSection uid={auth.uid} />
          </div>
          <div style={{ padding: '22px 24px 8px' }}>
            <QuickActionsSection width={width} />
          </div>
          <AnniversaryMetrics />
          <div style={{ padding: '24px 20px 0' }}>
            <DashboardJumpBar onJump={jumpTo} />
          </div>
          <div ref={(el) => registerZone('zone-today', el)} />
          <DashboardZoneHeader
            title="Alive today"
            subtitle="memories, dates & letters waiting for you"
            icon="wb_twilight"
            hue={AppColors.auroraGold}
          />
          <OnThisDayCard />
          <div style={{ height: 12 }} />
          <div style={{ padding: '0 16px' }}>
            <TonightCard />
          </div>
          <div style={{ height: 12 }} />
          <DashboardPair left={<UpcomingCountdowns />} right={<LetterboxView />} />
          <div style={{ height: 8 }} />
          <DailyBloom />

          {showLowerZones && (
            <Suspense fallback={<div style={{ height: 1200 }} />}>
              <DashboardLowerZones
                width={width}
                registerZone={registerZone}
                scrollRoot={scrollRef}
                requestedZone={requestedZone}
              />
            </Suspense>
          )}

          <div style={{ height: 'calc(110px + var(--safe-bottom, env(safe-area-inset-bottom, 0px)))' }} />
        </div>
      </div>

      <DashboardOverlays />
      <DashboardLoadVeil visible={showLoadVeil} onSkip={dismissLoadVeil} onComplete={dismissLoadVeil} />
    </div>
  );
}

function greetingFor(username: string | null, hour: number): string {
  const name = username === 'clairjassen' ? 'Clair' : username === 'khentsgdz' ? 'Khent' : null;
  if (name == null) return 'welcome home';
  if (hour >= 5 && hour < 12) return `good morning, ${name}`;
  if (hour >= 12 && hour < 18) return `good afternoon, ${name}`;
  if (hour >= 18 && hour < 22) return `good evening, ${name}`;
  return `still up, ${name}?`;
}

function DashboardHeader({ width }: { width: number }) {
  const auth = useAuth();
  const titleSize = width < 400 ? 38 : 48;
  const greeting = greetingFor(auth.currentUser, new Date().getHours());
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <BreathingEmblem>
        <div style={{ position: 'relative', width: 108, height: 108 }}>
          <div
            style={shadowLayer({ color: withAlpha(AppColors.deepRose, 0.2), blur: 36, spread: -6 }, { circle: true })}
            aria-hidden
          />
          <div
            style={shadowLayer({ color: withAlpha(AppColors.moonlight, 0.08), blur: 22, spread: -10 }, { circle: true })}
            aria-hidden
          />
          <div
            style={{
              position: 'relative',
              width: 108,
              height: 108,
              borderRadius: '50%',
              background: linear(
                [withAlpha(AppColors.moonlight, 0.18), withAlpha(AppColors.deepRose, 0.12), withAlpha(AppColors.inkDeep, 0.9)],
                { begin: Align.topLeft, end: Align.bottomRight, stops: [0, 0.55, 1], size: [108, 108] },
              ),
              ...insetBorder(withAlpha(AppColors.moonlight, 0.12), 1.2),
              padding: 14.2,
            }}
          >
            <img
              src="/images/logo.jpg"
              alt="Everglow"
              style={{ width: '100%', height: '100%', borderRadius: '50%', objectFit: 'cover', display: 'block' }}
            />
          </div>
        </div>
      </BreathingEmblem>

      <div style={{ height: 16 }} />
      <span
        style={{
          ...AppTypography.handwrittenBody,
          fontSize: 23,
          color: withAlpha(AppColors.blushGold, 0.92),
          lineHeight: 1,
          letterSpacing: 0.2,
        }}
      >
        {greeting}
      </span>
      <div style={{ height: 4 }} />
      <ShimmerTitle>
        <span
          style={{
            ...AppTypography.cormorantBlack,
            fontSize: titleSize,
            lineHeight: 1,
            letterSpacing: -0.6,
            textAlign: 'center',
            display: 'block',
            textShadow: `0 0 16.7px ${withAlpha(AppColors.deepRose, 0.2)}, 0 0 8.6px ${withAlpha(AppColors.moonlight, 0.1)}`,
          }}
        >
          Forever In Bloom
        </span>
      </ShimmerTitle>
      <div style={{ height: 8 }} />

      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ width: 4, height: 4, borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.7) }} />
        <div style={{ width: 8 }} />
        <span
          style={{
            ...AppTypography.outfitWhite,
            fontSize: 12.5,
            color: withAlpha(AppColors.petalWhite, 0.68),
            fontWeight: 500,
            lineHeight: lineHeight(12.5),
            ...letterSpacing(2.4),
            whiteSpace: 'pre',
          }}
        >
          since  February  14,  2026
        </span>
        <div style={{ width: 8 }} />
        <div style={{ width: 4, height: 4, borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.7) }} />
      </div>

      <div style={{ height: 18 }} />

      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ width: 42, height: 1, background: linear([AppColors.transparent, withAlpha(AppColors.blushGold, 0.65)]) }} />
        <div style={{ width: 3, height: 3, margin: '0 8px', borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.5) }} />
        <PulseHeart>
          <Icon name="favorite" size={14} color={AppColors.auroraRose} />
        </PulseHeart>
        <div style={{ width: 3, height: 3, margin: '0 8px', borderRadius: '50%', background: withAlpha(AppColors.blushGold, 0.5) }} />
        <div style={{ width: 42, height: 1, background: linear([withAlpha(AppColors.blushGold, 0.65), AppColors.transparent]) }} />
      </div>
    </div>
  );
}

function QuickActionsSection({ width }: { width: number }) {
  const bp = AppBreakpoint.of(width);
  const columns = bp === 'mobile' ? 4 : 8;
  const [showMore, setShowMore] = useState(false);
  const letters = useSource(() => letterboxService.notesPreview(10), [], letterboxService.cachedNotes);
  const unreadLetters = letters.filter((n) => isNoteUnlocked(n) && !n.isRead).length;
  const visibleActions = showMore ? [...PRIMARY_QUICK_ACTIONS, ...MORE_QUICK_ACTIONS] : PRIMARY_QUICK_ACTIONS;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
      <EverglowSectionHeader label="Quick Access" icon="grid_view" hue={AppColors.blushGold} />
      <div style={{ height: 16 }} />
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`,
          columnGap: 6,
          rowGap: 14,
        }}
      >
        {visibleActions.map((action) => (
          <QuickActionTile key={action.route} action={action} badge={action.route === '/letterbox' ? unreadLetters : 0} />
        ))}
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', marginTop: 14 }}>
        <button
          type="button"
          className="bare-button"
          aria-expanded={showMore}
          onClick={() => setShowMore((open) => !open)}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
            padding: '7px 14px',
            borderRadius: 999,
            background: withAlpha(AppColors.moonlight, 0.06),
            ...insetBorder(withAlpha(AppColors.blushGold, 0.24), 1),
            ...AppTypography.outfitMedium,
            fontSize: 12,
            color: withAlpha(AppColors.petalWhite, 0.86),
          }}
        >
          <span>{showMore ? 'Show less' : `More spaces (${MORE_QUICK_ACTIONS.length})`}</span>
          <Icon name={showMore ? 'expand_less' : 'expand_more'} size={16} color={AppColors.blushGold} />
        </button>
      </div>
    </div>
  );
}
