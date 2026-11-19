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
import { AnimePreview, BooksPreview, CinemaPreview, CurrentlyWatchingPreview, MangaPreview } from './MediaShelves';
import { AcademyPortalCard, PlayZonePortalCard } from './PortalCards';
import { TimelineView } from './TimelineView';

export function DashboardLowerZones({
  width,
  registerZone,
}: {
  width: number;
  registerZone: (id: string, el: HTMLDivElement | null) => void;
}) {
  return (
    <>
      <div ref={(el) => registerZone('zone-together', el)} />
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

      <div ref={(el) => registerZone('zone-world', el)} />
      <DashboardZoneHeader
        title="Places & keepsakes"
        subtitle="photos, plans & little universes you built"
        icon="public"
        hue={AppColors.auroraTeal}
      />
      <DashboardPair left={<GalleryPreview />} right={<CalendarPreview />} />
      <div style={{ height: 12 }} />
      <KeepsakesCluster />

      <div ref={(el) => registerZone('zone-play', el)} />
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
    </>
  );
}
