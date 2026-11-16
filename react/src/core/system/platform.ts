// Flutter's `defaultTargetPlatform` on the web. Flutter reads the browser's
// platform and user agent to pick button density, tap-target size and
// scrolling, so the React build has to make the same call to look the same.

export type TargetPlatform = 'android' | 'iOS' | 'macOS' | 'windows' | 'linux';

function detect(): TargetPlatform {
  const platform = navigator.platform ?? '';
  const ua = navigator.userAgent;
  const lower = platform.toLowerCase();
  if (platform.startsWith('Mac')) return (navigator.maxTouchPoints ?? 0) > 2 ? 'iOS' : 'macOS';
  if (lower.includes('iphone') || lower.includes('ipad') || lower.includes('ipod')) return 'iOS';
  if (ua.includes('Android')) return 'android';
  if (platform.startsWith('Linux')) return 'linux';
  if (platform.startsWith('Win')) return 'windows';
  return 'android';
}

export const targetPlatform: TargetPlatform = detect();

export const isMobilePlatform = targetPlatform === 'android' || targetPlatform === 'iOS';

/**
 * `VisualDensity.defaultDensityForPlatform`: phones are standard (0),
 * desktops are compact (-2). Material buttons shrink by 4px per step.
 */
export const visualDensity = isMobilePlatform ? 0 : -2;

/** `MaterialTapTargetSize.padded` on phones: tappables grow to 48px. */
export const paddedTapTargets = isMobilePlatform;
