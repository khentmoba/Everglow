// Port of lib/features/guardian/presentation/widgets/character/cat_visuals_web.dart.
import { createElement, useEffect, useState } from 'react';

export function CatVisuals({
  size = 80,
  autoRotate = true,
  orientation,
  clip = true,
  initDelayMs = 1500,
}: {
  size?: number;
  autoRotate?: boolean;
  orientation?: string;
  clip?: boolean;
  initDelayMs?: number;
}) {
  const [ready, setReady] = useState(initDelayMs === 0);

  useEffect(() => {
    if (initDelayMs === 0) return;
    const t = window.setTimeout(() => setReady(true), initDelayMs);
    return () => clearTimeout(t);
  }, [initDelayMs]);

  const inner =
    ready && typeof customElements !== 'undefined' && customElements.get('model-viewer')
      ? createElement('model-viewer', {
          src: '/models/chibi_cat.glb',
          poster: '/images/motchi_avatar.webp',
          alt: 'Everglow Guardian Cat',
          'camera-controls': 'false',
          'disable-zoom': '',
          'shadow-intensity': '0.8',
          'shadow-softness': '1.0',
          'auto-play': '',
          'interaction-prompt': 'none',
          ...(autoRotate ? { 'auto-rotate': '', 'auto-rotate-delay': '2000', 'rotation-per-second': '18deg' } : {}),
          ...(orientation ? { orientation } : {}),
          style: { width: '100%', height: '100%', backgroundColor: 'transparent', display: 'block' },
        })
      : createElement('img', {
          src: '/images/motchi_avatar.webp',
          alt: 'Everglow Guardian Cat',
          style: { width: '100%', height: '100%', objectFit: 'cover', display: 'block' },
        });

  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: clip ? size * 0.2 : 0,
        overflow: clip ? 'hidden' : 'visible',
      }}
    >
      {inner}
    </div>
  );
}
