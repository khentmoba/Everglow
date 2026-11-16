// Port of lib/features/starlight_jar/presentation/screens/starlight_page.dart.
import { AppColors } from '../../core/theme/colors';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { StarlightJarWidget } from './StarlightJarWidget';

export function StarlightPage() {
  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden' }}>
      <EverglowBackground
        baseColor={AppColors.inkDeep}
        glows={[
          { color: AppColors.auroraLilac, alignment: [-0.6, -0.9], size: 0.9, opacity: 0.14 },
          { color: AppColors.blushGold, alignment: [0.9, 0.8], size: 0.7, opacity: 0.1 },
        ]}
      />
      <div
        className="no-scrollbar"
        style={{
          position: 'relative',
          zIndex: 1,
          height: '100%',
          overflowY: 'auto',
          overflowX: 'hidden',
          paddingBottom: 96,
        }}
      >
        <StarlightJarWidget standalone />
      </div>
    </div>
  );
}
