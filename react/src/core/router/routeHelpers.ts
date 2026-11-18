// Port of lib/core/router/route_helpers.dart and AppErrorPage.cinemaOnlyRedirect.

export function cinemaOnlyRedirect(loc: string): string | null {
  const path = new URL(loc, 'http://x').pathname;
  if (path === '/') return null;
  for (const section of ['/cinema', '/anime', '/manga', '/books']) {
    if (path === section || path.startsWith(`${section}/`)) return null;
  }
  return '/cinema';
}

/** Where to go after unlocking, from the gateway's `?from=` link. */
export function deepLinkTarget(search: string, cinemaOnly: boolean): string | null {
  const from = new URLSearchParams(search).get('from');
  if (!from || from.includes('..')) return null;
  if (/^[a-z][a-z0-9+.-]*:/i.test(from) || from.startsWith('//')) return null;
  const path = from.split(/[?#]/)[0];
  if (!path.startsWith('/') || path.startsWith('//') || path === '/') return null;
  if (cinemaOnly && cinemaOnlyRedirect(path) != null) return null;
  return from;
}

/** Keeps `?screencheck=1` launches in demo mode across the jump. */
export function agentJumpLocation(search: string, target: string): string {
  const launch = new URLSearchParams(search);
  if (launch.get('screencheck') !== '1') return target;
  const url = new URL(target, 'http://x');
  launch.forEach((v, k) => url.searchParams.set(k, v));
  return url.pathname + url.search;
}
