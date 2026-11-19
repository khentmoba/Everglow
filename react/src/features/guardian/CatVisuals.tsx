// Port of lib/features/guardian/presentation/widgets/character/cat_visuals_web.dart.
import { createElement, useEffect, useState } from 'react';

const MODEL_VIEWER_SRC = 'https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js';
let modelViewerPromise: Promise<boolean> | null = null;

function ensureModelViewer(): Promise<boolean> {
  if (typeof window === 'undefined' || typeof customElements === 'undefined') {
    return Promise.resolve(false);
  }
  if (customElements.get('model-viewer')) return Promise.resolve(true);
  if (modelViewerPromise) return modelViewerPromise;

  modelViewerPromise = new Promise<boolean>((resolve) => {
    const existing = document.querySelector<HTMLScriptElement>('script[data-everglow-model-viewer]');
    const onReady = () => {
      void customElements
        .whenDefined('model-viewer')
        .then(() => resolve(true))
        .catch(() => resolve(false));
    };
    const onFail = (failedScript?: HTMLScriptElement) => {
      failedScript?.remove();
      modelViewerPromise = null;
      resolve(false);
    };

    if (existing) {
      if (customElements.get('model-viewer')) {
        resolve(true);
        return;
      }
      existing.addEventListener('load', onReady, { once: true });
      existing.addEventListener('error', () => onFail(existing), { once: true });
      return;
    }

    const script = document.createElement('script');
    script.type = 'module';
    script.src = MODEL_VIEWER_SRC;
    script.crossOrigin = 'anonymous';
    script.dataset.everglowModelViewer = '1';
    script.addEventListener('load', onReady, { once: true });
    script.addEventListener('error', () => onFail(script), { once: true });
    document.head.appendChild(script);
  });

  return modelViewerPromise;
}

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
  const [viewerReady, setViewerReady] = useState(
    () => typeof customElements !== 'undefined' && Boolean(customElements.get('model-viewer')),
  );

  useEffect(() => {
    if (initDelayMs === 0) return;
    const t = window.setTimeout(() => setReady(true), initDelayMs);
    return () => clearTimeout(t);
  }, [initDelayMs]);

  useEffect(() => {
    if (!ready || viewerReady) return;
    let alive = true;
    void ensureModelViewer().then((ok) => {
      if (alive && ok) setViewerReady(true);
    });
    return () => {
      alive = false;
    };
  }, [ready, viewerReady]);

  const show3d = ready && viewerReady;

  const inner = show3d
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
        borderRadius: !show3d && clip ? size * 0.2 : 0,
        overflow: !show3d && clip ? 'hidden' : 'visible',
      }}
    >
      {inner}
    </div>
  );
}
