// Port of lib/features/dashboard/presentation/screens/dashboard_screen.dart
// and dashboard_screen_sections.dart.
import { useEffect, useRef, useState } from 'react';
import { useRememberedScroll } from '../../core/router/scrollMemory';
import { useAuth } from '../../core/services/auth';
import { useOnline, useViewport } from '../../core/system/viewport';
import { AppColors, withAlpha } from '../../core/theme/colors';
import { AppBreakpoint, AppSpacing, responsive } from '../../core/theme/layout';
import { Align, letterSpacing, lineHeight, linear, shadowLayer, insetBorder } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { CircularProgress } from '../../shared/widgets/CircularProgress';
import { EverglowBackground, type RadialGlow } from '../../shared/widgets/EverglowBackground';
import { EverglowSectionHeader } from '../../shared/widgets/EverglowSectionHeader';
import { Icon } from '../../shared/widgets/Icon';
import { DailyBloom } from '../daily_bloom/DailyBloom';
import { RandomizerCard } from '../date_randomizer/RandomizerCard';
import { guardianController } from '../guardian/guardianController';
import { guardianService } from '../guardian/guardianService';
import { moodController } from '../heartbeat/moodService';
import { ArtistShowdownCard, JukeboxWidget, MusicStatsSection } from '../jukebox/JukeboxCards';
import { StarlightJarWidget } from '../starlight_jar/StarlightJarWidget';
import { WatchPartyCard } from '../watch_party/WatchPartyCard';
import { XpProgressSection } from '../xp/XpProgressSection';
import { AnniversaryMetrics } from './AnniversaryMetrics';
import { CalendarPreview } from './CalendarPreview';
import { DashboardJumpBar } from './DashboardJumpBar';
import { BreathingEmblem, DashboardAmbience, PulseHeart, ShimmerTitle } from './DashboardMotion';
import { DashboardOverlays, kTopActionsReserve } from './DashboardOverlays';
import { DashboardPair, DashboardZoneHeader } from './DashboardZoneHeader';
import { GalleryPreview } from './GalleryPreview';
import { KeepsakesCluster } from './KeepsakesCluster';
import { LetterboxView } from './LetterboxView';
import { AnimePreview, BooksPreview, CinemaPreview, CurrentlyWatchingPreview, MangaPreview } from './MediaShelves';
import { OnThisDayCard } from './OnThisDayCard';
import { AcademyPortalCard, PlayZonePortalCard } from './PortalCards';
import { QuickActionTile, type QuickAction } from './QuickActionTile';
import { TimelineView } from './TimelineView';
import { TonightCard } from './TonightCard';
import { UpcomingCountdowns } from './UpcomingCountdowns';

const DASHBOARD_GLOWS: RadialGlow[] = [
  { color: AppColors.deepRose, alignment: [-0.7, -0.85], size: 0.9, opacity: 0.14 },
  { color: AppColors.softLavender, alignment: [0.85, 0.95], size: 0.8, opacity: 0.1 },
  { color: AppColors.auroraGold, alignment: [0.1, 0.45], size: 0.6, opacity: 0.05 },
];

const QUICK_ACTIONS: QuickAction[] = [
  { label: 'Gallery', icon: 'photo_library', route: '/gallery', hue: AppColors.roseQuartz, caption: 'Memories' },
  { label: 'Sanctuary', icon: 'chat_bubble', route: '/sanctuary', hue: AppColors.auroraRose, caption: 'Chat' },
  { label: 'Canvas', icon: 'brush', route: '/canvas', hue: AppColors.softLavender, caption: 'Draw' },
  { label: 'Motchi', icon: 'auto_awesome', route: '/motchi', hue: AppColors.auroraGold, caption: 'AI companion' },
  { label: 'Calendar', icon: 'calendar_month', route: '/calendar', hue: AppColors.warmAmber, caption: 'Dates' },
  { label: 'Starlight', icon: 'auto_awesome_mosaic', route: '/starlight', hue: AppColors.auroraLilac, caption: 'Gratitude' },
  { label: 'Tonight', icon: 'nightlife', route: '/tonight', hue: AppColors.auroraRose, caption: 'What to do' },
  { label: 'Journal', icon: 'menu_book', route: '/journal', hue: AppColors.softLavender, caption: 'Diary' },
  { label: 'Bucket List', icon: 'card_travel', route: '/bucket-list', hue: AppColors.auroraTeal, caption: 'Dreams' },
  { label: 'Trip Kit', icon: 'luggage', route: '/trips', hue: AppColors.warmAmber, caption: 'Lakad' },
  { label: 'Letterbox', icon: 'mail_outline', route: '/letterbox', hue: AppColors.blushGold, caption: 'Letters' },
  { label: 'Money', icon: 'savings', route: '/money', hue: AppColors.auroraGold, caption: 'Wallet' },
  { label: 'Subs', icon: 'subscriptions', route: '/subs', hue: AppColors.warmAmber, caption: 'Tracker' },
  { label: 'Desktop App', icon: 'desktop_windows', route: '/desktop-app', hue: AppColors.blushGold, caption: 'Updates' },
];

export function DashboardPage() {
  const auth = useAuth();
  const { width } = useViewport();
  const scrollRef = useRef<HTMLDivElement>(null);
  const [scrollTop, setScrollTop] = useState(0);
  const zoneRefs = useRef<Record<string, HTMLDivElement | null>>({});
  useRememberedScroll('dashboard', scrollRef, auth.isReady);

  useEffect(() => {
    if (!auth.isReady) return;
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
    const el = zoneRefs.current[id];
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden' }}>
      <EverglowBackground baseColor={AppColors.inkDeep} glows={DASHBOARD_GLOWS} />
      <DashboardAmbience scrollTop={scrollTop} />

      <div
        ref={scrollRef}
        className="no-scrollbar"
        onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)}
        style={{ position: 'relative', height: '100%', overflowY: 'auto', overflowX: 'hidden' }}
      >
        <div style={{ margin: '0 auto', width: '100%', maxWidth: contentMaxWidth }}>
          <OfflineBanner />
          <div style={{ padding: `${kTopActionsReserve}px ${AppSpacing.pageH(width)}px 24px` }}>
            <DashboardHeader width={width} />
          </div>
          <div style={{ padding: '8px 24px' }}>
            <XpProgressSection uid={auth.uid} />
          </div>
          <div style={{ padding: '22px 24px 8px' }}>
            <QuickActionsSection width={width} />
          </div>
          <AnniversaryMetrics />
          <div style={{ padding: '10px 24px 8px' }}>
            <DashboardJumpBar onJump={jumpTo} />
          </div>
          <div style={{ height: 12 }} />

          <div ref={(el) => { zoneRefs.current['zone-today'] = el; }} />
          <DashboardZoneHeader
            label="Today"
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

          <div ref={(el) => { zoneRefs.current['zone-together'] = el; }} />
          <DashboardZoneHeader
            label="Together"
            title="Just us"
            subtitle="gratitude, words & the long story of us"
            icon="favorite"
            hue={AppColors.auroraRose}
          />
          {width < AppBreakpoint.mobile ? (
            <>
              <StarlightJarWidget />
              <div style={{ height: 16 }} />
              <TimelineView />
            </>
          ) : (
            <DashboardPair left={<StarlightJarWidget />} right={<TimelineView />} />
          )}

          <div ref={(el) => { zoneRefs.current['zone-world'] = el; }} />
          <DashboardZoneHeader
            label="Our World"
            title="Places & keepsakes"
            subtitle="photos, plans & little universes you built"
            icon="public"
            hue={AppColors.auroraTeal}
          />
          <DashboardPair left={<GalleryPreview />} right={<CalendarPreview />} />
          <div style={{ height: 12 }} />
          <KeepsakesCluster />

          <div ref={(el) => { zoneRefs.current['zone-play'] = el; }} />
          <DashboardZoneHeader
            label="Play"
            title="Sound & screen"
            subtitle="jukebox, watch party, shelves & games"
            icon="videogame_asset"
            hue={AppColors.softLavender}
          />
          <div style={{ padding: '0 16px' }}>
            <div style={{ maxWidth: 640, margin: '0 auto' }}>
              <JukeboxWidget />
            </div>
          </div>
          <div style={{ height: 16 }} />
          <div style={{ padding: '0 16px' }}>
            <MusicStatsSection />
          </div>
          <div style={{ height: 16 }} />
          <div style={{ padding: '0 16px' }}>
            <ArtistShowdownCard />
          </div>
          <div style={{ height: 16 }} />
          <RandomizerCard />
          <div style={{ height: 16 }} />
          <DashboardPair left={<CurrentlyWatchingPreview />} right={<WatchPartyCard />} />
          <div style={{ height: 12 }} />
          <CinemaPreview />
          <div style={{ height: 12 }} />
          <AnimePreview />
          <div style={{ height: 12 }} />
          <BooksPreview />
          <div style={{ height: 12 }} />
          <MangaPreview />
          <div style={{ height: 12 }} />
          <DashboardPair left={<AcademyPortalCard />} right={<PlayZonePortalCard />} />

          <div style={{ height: 110 }} />
        </div>
      </div>

      <DashboardOverlays />
    </div>
  );
}

function DashboardHeader({ width }: { width: number }) {
  const titleSize = width < 400 ? 38 : 48;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div
        style={{
          padding: '6px 12px',
          background: withAlpha(AppColors.moonlight, 0.06),
          borderRadius: 999,
          border: `1px solid ${withAlpha(AppColors.moonlight, 0.1)}`,
          display: 'inline-flex',
          alignItems: 'center',
        }}
      >
        <div
          style={{
            width: 5,
            height: 5,
            borderRadius: '50%',
            background: AppColors.auroraRose,
            boxShadow: `0 0 4px ${withAlpha(AppColors.auroraRose, 0.6)}`,
          }}
        />
        <div style={{ width: 8 }} />
        <span
          style={{
            ...AppTypography.outfitHeading,
            fontSize: 9.5,
            ...letterSpacing(2.0),
            color: withAlpha(AppColors.blushGold, 0.85),
            whiteSpace: 'pre',
          }}
        >
          EST.  FEBRUARY 14, 2026  —  KHENT  &amp;  CLAIR
        </span>
      </div>

      <div style={{ height: 18 }} />

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
        welcome home
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
  const columns = bp === 'mobile' ? 3 : bp === 'tablet' ? 5 : 6;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'stretch' }}>
      <EverglowSectionHeader label="Quick Access" icon="grid_view" hue={AppColors.blushGold} />
      <div style={{ height: 14 }} />
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))`,
          gap: 12,
        }}
      >
        {QUICK_ACTIONS.map((action) => (
          <QuickActionTile key={action.route} action={action} />
        ))}
      </div>
    </div>
  );
}

function OfflineBanner() {
  const auth = useAuth();
  const online = useOnline();
  if (!auth.isOfflineMode || online) return null;
  return (
    <div style={{ padding: '8px 24px 0' }}>
      <div
        style={{
          padding: '10px 14px',
          background: withAlpha(AppColors.auroraGold, 0.08),
          borderRadius: 14,
          border: `1px solid ${withAlpha(AppColors.auroraGold, 0.3)}`,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
        }}
      >
        <Icon name="cloud_off" size={18} color={AppColors.auroraGold} />
        <span style={{ ...AppTypography.bodySmall, color: withAlpha(AppColors.petalWhite, 0.92), fontSize: 12, lineHeight: 1.3 }}>
          You&rsquo;re offline &mdash; showing your saved copy. New things will sync when you&rsquo;re back online.
        </span>
      </div>
    </div>
  );
}
