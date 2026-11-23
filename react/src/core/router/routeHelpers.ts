// Port of lib/core/router/route_helpers.dart and AppErrorPage.cinemaOnlyRedirect.

export function cinemaOnlyRedirect(loc: string): string | null {
  const path = new URL(loc, 'http://x').pathname;
  if (path === '/') return null;
  for (const section of ['/cinema', '/anime', '/manga', '/books', '/watch-party', '/global-chat']) {
    if (path === section || path.startsWith(`${section}/`)) return null;
  }
  return '/cinema';
}

/** Validates an internal app path, rejecting schemes, protocol-relative URLs, backslashes, and `..`. */
export function sanitizeInternalPath(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed || trimmed.includes('..') || trimmed.includes('\\')) return null;
  if (/^[a-z][a-z0-9+.-]*:/i.test(trimmed) || trimmed.startsWith('//')) return null;
  const path = trimmed.split(/[?#]/)[0];
  if (!path.startsWith('/') || path.startsWith('//')) return null;
  return trimmed;
}

/** Where to go after unlocking, from the gateway's `?from=` link. */
export function deepLinkTarget(search: string, cinemaOnly: boolean): string | null {
  const from = sanitizeInternalPath(new URLSearchParams(search).get('from'));
  if (!from) return null;
  const path = from.split(/[?#]/)[0];
  if (path === '/') return null;
  if (cinemaOnly && cinemaOnlyRedirect(path) != null) return null;
  return from;
}

/** Preserves deep-link and launch query params (such as `hud`, `tab`, `q`, `screencheck`) across the agent jump. */
export function agentJumpLocation(search: string, target: string): string {
  const launch = new URLSearchParams(search);
  const keepAgent = launch.get('screencheck') === '1';
  const url = new URL(target, 'http://x');
  launch.forEach((v, k) => {
    if (!keepAgent && (k === 'agent' || k === 'jump')) return;
    if (!url.searchParams.has(k)) url.searchParams.set(k, v);
  });
  return url.pathname + url.search;
}
