// Port of lib/features/starlight_jar/presentation/screens/starlight_page.dart.
// The background sits in a Stack beside a SingleChildScrollView, so it is only
// as tall as the content (capped at the screen); below it shows the scaffold's
// twilight.
import { useBoxSize } from '../../core/system/useBoxSize';
import { useViewport } from '../../core/system/viewport';
import { AppColors } from '../../core/theme/colors';
import { EverglowBackground } from '../../shared/widgets/EverglowBackground';
import { StarlightJarWidget } from './StarlightJarWidget';

export function StarlightPage() {
  const viewport = useViewport();
  const [ref, content] = useBoxSize<HTMLDivElement>();
  const height = Math.min(content?.[1] ?? viewport.height, viewport.height);
  return (
    <div style={{ position: 'fixed', inset: 0, overflow: 'hidden', background: AppColors.twilight }}>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 0, height }}>
        <EverglowBackground
          baseColor={AppColors.inkDeep}
          size={[viewport.width, height]}
          glows={[
            { color: AppColors.auroraLilac, alignment: [-0.6, -0.9], size: 0.9, opacity: 0.14 },
            { color: AppColors.blushGold, alignment: [0.9, 0.8], size: 0.7, opacity: 0.1 },
          ]}
        />
      </div>
      <div className="no-scrollbar" style={{ position: 'relative', height: '100%', overflowY: 'auto', overflowX: 'hidden' }}>
        <div ref={ref} style={{ paddingTop: 'env(safe-area-inset-top)' }}>
          <StarlightJarWidget />
        </div>
      </div>
    </div>
  );
}
