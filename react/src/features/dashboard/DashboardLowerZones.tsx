import { useEffect, useRef, useState, type ReactNode, type RefObject } from 'react';
import { AppColors } from '../../core/theme/colors';
import { AppBreakpoint } from '../../core/theme/layout';
import { RandomizerCard } from '../date_randomizer/RandomizerCard';
import { ArtistShowdownCard, JukeboxWidget, MusicStatsSection } from '../jukebox/JukeboxCards';
import { StarlightJarWidget } from '../starlight_jar/StarlightJarWidget';
import { WatchPartyCard } from '../watch_party/WatchPartyCard';
import { CalendarPreview } from './CalendarPreview';
import { DashboardPair, DashboardZoneHeader } from './DashboardZoneHeader';
import { GalleryPreview } from './GalleryPreview';
import { KeepsakesCluster } from './KeepsakesCluster';
import {
  AnimePreview,
  BooksPreview,
  CinemaPreview,
  CurrentlyWatchingPreview,
  MangaPreview,
  WatchListsProvider,
} from './MediaShelves';
import { AcademyPortalCard, PlayZonePortalCard } from './PortalCards';
import { TimelineView } from './TimelineView';

function LazyZone({
  id,
  registerZone,
  scrollRoot,
  forceMount,
  minHeight,
  children,
}: {
  id: string;
  registerZone: (id: string, el: HTMLDivElement | null) => void;
  scrollRoot?: RefObject<HTMLDivElement | null>;
  forceMount: boolean;
  minHeight: number;
  children: ReactNode;
}) {
  const [mounted, setMounted] = useState(
    () => forceMount || typeof IntersectionObserver === 'undefined',
  );
  const sentinelRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (forceMount && !mounted) setMounted(true);
  }, [forceMount, mounted]);

  useEffect(() => {
    if (mounted) return;
    const node = sentinelRef.current;
    if (!node || typeof IntersectionObserver === 'undefined') {
      setMounted(true);
      return;
    }
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setMounted(true);
          observer.disconnect();
        }
      },
      { root: scrollRoot?.current ?? null, rootMargin: '400px 0px' },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, [mounted, scrollRoot]);

  return (
    <div
      ref={(el) => {
        sentinelRef.current = el;
        registerZone(id, el);
      }}
      style={mounted ? undefined : { minHeight }}
    >
      {mounted ? children : null}
    </div>
  );
}

export function DashboardLowerZones({
  width,
  registerZone,
  scrollRoot,
  requestedZone,
}: {
  width: number;
  registerZone: (id: string, el: HTMLDivElement | null) => void;
  scrollRoot?: RefObject<HTMLDivElement | null>;
  requestedZone?: string | null;
}) {
  return (
    <>
      <LazyZone
        id="zone-together"
        registerZone={registerZone}
        scrollRoot={scrollRoot}
        forceMount={requestedZone === 'zone-together'}
        minHeight={420}
      >
        <DashboardZoneHeader
          title="Just us"
          subtitle="gratitude, words & the long story of us"
          icon="favorite"
          hue={AppColors.auroraRose}
        />
        {width < AppBreakpoint.mobile ? (
          <>
            <StarlightJarWidget embedded />
            <div style={{ height: 16 }} />
            <TimelineView />
          </>
        ) : (
          <DashboardPair left={<StarlightJarWidget embedded />} right={<TimelineView />} />
        )}
      </LazyZone>

      <LazyZone
        id="zone-world"
        registerZone={registerZone}
        scrollRoot={scrollRoot}
        forceMount={requestedZone === 'zone-world'}
        minHeight={520}
      >
        <DashboardZoneHeader
          title="Places & keepsakes"
          subtitle="photos, plans & little universes you built"
          icon="public"
          hue={AppColors.auroraTeal}
        />
        <DashboardPair left={<GalleryPreview />} right={<CalendarPreview />} />
        <div style={{ height: 12 }} />
        <KeepsakesCluster />
      </LazyZone>

      <LazyZone
        id="zone-play"
        registerZone={registerZone}
        scrollRoot={scrollRoot}
        forceMount={requestedZone === 'zone-play'}
        minHeight={900}
      >
        <DashboardZoneHeader
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
        <WatchListsProvider>
          <DashboardPair left={<CurrentlyWatchingPreview />} right={<WatchPartyCard />} />
          <div style={{ height: 12 }} />
          <CinemaPreview />
          <div style={{ height: 12 }} />
          <AnimePreview />
        </WatchListsProvider>
        <div style={{ height: 12 }} />
        <BooksPreview />
        <div style={{ height: 12 }} />
        <MangaPreview />
        <div style={{ height: 12 }} />
        <DashboardPair left={<AcademyPortalCard />} right={<PlayZonePortalCard />} />
      </LazyZone>
    </>
  );
}
