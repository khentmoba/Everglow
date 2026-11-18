// Port of lib/features/jukebox/presentation/screens/jukebox_screen.dart.
import { AppColors } from '../../core/theme/colors';
import { EverglowFeatureHeader } from '../../shared/widgets/EverglowFeatureHeader';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { JukeboxWidget } from './JukeboxCards';

export function JukeboxPage() {
  return (
    <EverglowScaffold header={<EverglowFeatureHeader title="Jukebox" subtitle="what we're listening to" icon="graphic_eq" hue={AppColors.auroraRose} />}>
      {/* The scaffold centres its body, and a SingleChildScrollView shrinks to
          its content, so a short page sits in the middle of the screen. */}
      <div style={{ height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <div className="no-scrollbar" style={{ maxHeight: '100%', overflowY: 'auto', overflowX: 'hidden' }}>
          <div style={{ padding: 16, willChange: 'transform' }}>
            <JukeboxWidget />
          </div>
        </div>
      </div>
    </EverglowScaffold>
  );
}
