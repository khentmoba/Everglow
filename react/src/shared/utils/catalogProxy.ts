// Port of lib/shared/utils/catalog_proxy_client.dart: keyless public catalogs
// (ani.zip, torrentio, Jikan, ...) go through our proxyCatalog helper, with the
// login token when signed in.
import { ConnectivityService } from '../../core/network/connectivity';
import { NetworkQualityService } from '../../core/network/networkQuality';
import { auth } from '../../core/services/firebase';

export const CATALOG_PROXY_BASE = 'https://us-central1-everglow-1c6db.cloudfunctions.net/proxyCatalog';

export async function catalogProxyGet(
  base: string,
  path: string,
  opts: { query?: Record<string, string>; timeoutMs?: number } = {},
): Promise<Response> {
  if (!ConnectivityService.isOnline) {
    throw new Error('Offline');
  }
  const q = opts.query && Object.keys(opts.query).length ? `?${new URLSearchParams(opts.query).toString()}` : '';
  const url = `${CATALOG_PROXY_BASE}?${new URLSearchParams({ base, path: `${path}${q}` }).toString()}`;
  let token: string | undefined;
  try {
    token = await auth.currentUser?.getIdToken();
  } catch {
    // Not signed in yet: continue anonymously.
  }
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const timeout = NetworkQualityService.timeoutMs(opts.timeoutMs ?? 12000);
  return fetch(url, { headers, signal: AbortSignal.timeout(timeout) });
}

/** AniZipService.fetchMappings / fetchMappingsByAnilist. */
export async function fetchAniZipMappings(opts: { malId?: number; anilistId?: number }): Promise<Record<string, unknown> | null> {
  const query: Record<string, string> | null =
    opts.anilistId && opts.anilistId > 0
      ? { anilist_id: `${opts.anilistId}` }
      : opts.malId && opts.malId > 0
        ? { mal_id: `${opts.malId}` }
        : null;
  if (!query) return null;
  try {
    const resp = await catalogProxyGet('anizip', 'mappings', { query, timeoutMs: 15000 });
    if (!resp.ok) return null;
    const json = (await resp.json()) as unknown;
    return json && typeof json === 'object' ? (json as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

/** AniZipService.fetchTmdbId. */
export async function fetchAniZipTmdbId(malId: number): Promise<number | null> {
  const data = await fetchAniZipMappings({ malId });
  const raw = (data?.mappings as Record<string, unknown> | undefined)?.themoviedb_id;
  if (typeof raw === 'string' && raw) return Number.parseInt(raw, 10) || null;
  if (typeof raw === 'number') return Math.trunc(raw);
  return null;
}
