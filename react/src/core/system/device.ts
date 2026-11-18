// Ports of lib/core/perf/device_capability_web.dart and the
// `AppMotion.reduceAmbientMotion` check.
import { motionReduced } from '../theme/motion';

export function isLowEndDevice(): boolean {
  const flag = new URLSearchParams(window.location.search).get('lowend');
  if (flag != null) {
    const lower = flag.trim().toLowerCase();
    if (lower === '1' || lower === 'true') return true;
    if (lower === '0' || lower === 'false') return false;
  }
  const cores = navigator.hardwareConcurrency > 0 ? navigator.hardwareConcurrency : 4;
  if (cores > 0 && cores <= 4) return true;
  const mem = (navigator as { deviceMemory?: number }).deviceMemory;
  if (mem != null && mem > 0 && mem <= 4) return true;
  return false;
}

/** Ambient motion (petals, breathing glow) is off on phones and slow devices. */
export function reduceAmbientMotion(viewport: { width: number; height: number }): boolean {
  return (
    motionReduced() ||
    Math.min(viewport.width, viewport.height) < 600 ||
    isLowEndDevice()
  );
}
