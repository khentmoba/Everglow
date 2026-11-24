// The Home rail plan, kept out of the page: it is a pure function of the fetched
// rows, and it used to be built during render, which made Home depend on how
// often React re-rendered.
import { useMemo } from 'react';
import { TOP_TEN_COUNTRY_LABEL, catalogKeyOf, type MediaItem } from './cinemaTypes';
import { DISCOVERY_SHELVES } from './cinemaShelves';

// Under this many posters a rail is not a recommendation, it is a stub.
const MIN_RAIL_SHOWN = 4;
// One rail is a row, not a dump: the pool behind it feeds the rails below.
const RAIL_MAX = 8;

export interface CinemaRail {
  title: string;
  reason: string;
  items: MediaItem[];
  ranked?: boolean;
}

export interface CinemaRailPlanInput {
  watchingList: MediaItem[];
  savedList: MediaItem[];
  trendingGlobal: MediaItem[];
  topTenToday: MediaItem[];
  popularTV: MediaItem[];
  newlyReleased: MediaItem[];
  discoveryRows: Record<string, MediaItem[]>;
}

export function useCinemaHeroTitles(
  trendingGlobal: MediaItem[],
  watchingList: MediaItem[],
  savedList: MediaItem[] = [],
): MediaItem[] {
  return useMemo(() => {
    const taken = new Set([...watchingList, ...savedList].map((m) => catalogKeyOf(m)));
    const fresh = trendingGlobal.filter((m) => !taken.has(catalogKeyOf(m)));
    return (fresh.length >= 3 ? fresh : trendingGlobal).slice(0, 5);
  }, [trendingGlobal, watchingList, savedList]);
}

export function useCinemaRailPlan(input: CinemaRailPlanInput, heroTitles: MediaItem[]): CinemaRail[] {
  const { watchingList, savedList, trendingGlobal, topTenToday, popularTV, newlyReleased, discoveryRows } = input;
  return useMemo(() => {
    // The billboard already showed these, so no rail below repeats them.
    const heroKeys = new Set(heroTitles.map((m) => catalogKeyOf(m)));
    const seen = new Set<string>([
      ...[...watchingList, ...savedList].map((m) => catalogKeyOf(m)),
      ...heroKeys,
    ]);
    const recent: string[][] = [];
    const signatures = new Set<string>();
    const unique = (items: MediaItem[]) => {
      const keys = new Set<string>();
      return items.filter((m) => {
        const key = catalogKeyOf(m);
        if (keys.has(key)) return false;
        keys.add(key);
        return true;
      });
    };
    const ratio = (keys: string[], rail: string[]) =>
      keys.length === 0 ? 0 : keys.filter((k) => rail.includes(k)).length / Math.min(keys.length, rail.length);
    const tooSimilar = (keys: string[]) =>
      recent.some((rail, i) => ratio(keys, rail) >= (i === 0 ? 0.5 : 0.75));

    const plan: { title: string; reason: string; items: MediaItem[]; ranked?: boolean }[] = [];
    const add = (
      title: string,
      reason: string,
      rawItems: MediaItem[],
      opts: { mediaType?: 'movie' | 'tv'; ranked?: boolean; allowHero?: boolean } = {},
    ) => {
      const items = unique(rawItems);
      if (opts.ranked) {
        // The ranked row keeps its own order, but a film the page has already
        // shown is dropped from the row rather than offered a third time; its
        // numeral still comes from the title's real place in the list.
        // The pool is the real top ten, so every numeral is the title's actual
        // place. A title the page has already shown is dropped from the row
        // rather than offered twice.
        const pool = items.slice(0, 10);
        const unseen = pool.filter((m) => !seen.has(catalogKeyOf(m)));
        // A ranked row may be short: it states places, and it never re-offers a
        // title the page already showed.
        const shown = unseen;
        if (shown.length === 0) return;
        for (const m of shown) seen.add(catalogKeyOf(m));
        recent.unshift(shown.map(catalogKeyOf));
        plan.push({ title, reason, items: shown, ranked: true });
        return;
      }
      const recentKeys = new Set(recent.flat());
      // A rail may be allowed to reuse the billboard's titles; the first personal
      // rail is, because it is a cause, not a catalogue listing.
      const fresh = (m: MediaItem) => {
        const key = catalogKeyOf(m);
        if (recentKeys.has(key)) return false;
        if (opts.allowHero && heroKeys.has(key)) return true;
        return !seen.has(key);
      };
      // A rail shows its own titles, nothing borrowed: padding a series row with
      // a film (or a stranger's sequel) is how "Popular Series" ended up holding
      // John Wick. A rail that cannot fill is dropped instead.
      // No refill at all: a row that borrows already-shown titles is a repeat,
      // and the rows above it already carry them.
      const shown = items.filter(fresh).slice(0, RAIL_MAX);
      const keys = shown.map((m) => catalogKeyOf(m));
      if (keys.length < MIN_RAIL_SHOWN || tooSimilar(keys)) return;
      const signature = [...keys].sort().join('|');
      if (signatures.has(signature)) return;
      signatures.add(signature);
      recent.unshift(keys);
      if (recent.length > 3) recent.pop();
      for (const m of shown) seen.add(catalogKeyOf(m));
      plan.push({ title, reason, items: shown });
    };

    const becauseOf = watchingList[0];
    const becauseGenre = becauseOf?.genres?.[0];
    // Franchise-aware: "Because you watched Dune: Part Two" must not end on Dune.
    const rootOf = (title: string) =>
      (title.toLowerCase().split(/[:–—(]/)[0].trim().split(/\s+/).slice(0, 2).join(' '));
    const becauseRoot = becauseOf ? rootOf(becauseOf.title) : '';
    const becauseItems =
      becauseOf && becauseGenre
        ? trendingGlobal
            .filter(
              (m) =>
                m.genres?.includes(becauseGenre) &&
                catalogKeyOf(m) !== catalogKeyOf(becauseOf) &&
                rootOf(m.title) !== becauseRoot,
            )
            .slice(0, 12)
        : [];
    if (becauseItems.length >= MIN_RAIL_SHOWN)
      add(`Because you watched ${becauseOf?.title ?? ''}`, 'Same mood, different story', becauseItems, { allowHero: true });
    add(`Top 10 in ${TOP_TEN_COUNTRY_LABEL}`, 'Ranked by popularity today', topTenToday, { ranked: true });
    add('Trending Now', 'What everyone is watching this week', trendingGlobal);
    add('Coming Soon', 'New on Everglow Cinema', newlyReleased);
    add('Popular Series', 'Most-watched series right now', popularTV, { mediaType: 'tv' });
    for (const [title, items] of Object.entries(discoveryRows)) {
      const shelf = DISCOVERY_SHELVES.find((d) => d.title === title);
      add(title, shelf?.reason ?? '', items, { mediaType: shelf?.type });
    }
    return plan;
  }, [watchingList, savedList, trendingGlobal, topTenToday, popularTV, newlyReleased, discoveryRows, heroTitles]);
}
