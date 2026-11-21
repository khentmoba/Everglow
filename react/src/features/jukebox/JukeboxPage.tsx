// Port of lib/features/jukebox/presentation/screens/jukebox_screen.dart.
import { AppColors } from '../../core/theme/colors';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { JukeboxWidget } from './JukeboxCards';
import { LovedTracksCard, OnThisDayMusicCard } from './JukeboxInsightsCards';

export function JukeboxPage() {
  return (
    <EverglowScaffold header={<EverglowFeatureHeader title="Jukebox" subtitle="what we're listening to" icon="graphic_eq" hue={AppColors.auroraRose} />}>
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div className="no-scrollbar" style={{ maxHeight: '100%', overflowY: 'auto', overflowX: 'hidden' }}>
          <div style={{ padding: 16, willChange: 'transform', display: 'flex', flexDirection: 'column', gap: 16 }}>
            <JukeboxWidget showHeader={false} />
            <OnThisDayMusicCard />
            <LovedTracksCard />
          </div>
        </div>
      </div>
    </EverglowScaffold>
  );
}
