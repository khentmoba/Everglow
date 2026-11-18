// Port of lib/features/jukebox/presentation/screens/jukebox_screen.dart.
import { EverglowAppBar } from '../../shared/widgets/EverglowAppBar';
import { EverglowScaffold } from '../../shared/widgets/EverglowScaffold';
import { JukeboxWidget } from './JukeboxCards';

export function JukeboxPage() {
  return (
    <EverglowScaffold header={<EverglowAppBar title="Jukebox" />}>
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
