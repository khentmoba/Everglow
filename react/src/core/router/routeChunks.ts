import { lazy, type ComponentType } from 'react';

type ModuleLoader<T> = () => Promise<T>;

const CHUNK_RELOAD_KEY = 'everglow:chunk-reload';

function isChunkLoadError(err: unknown): boolean {
  const msg = err instanceof Error ? err.message : String(err ?? '');
  return (
    /Failed to fetch dynamically imported module/i.test(msg) ||
    /Importing a module script failed/i.test(msg) ||
    /error loading dynamically imported module/i.test(msg) ||
    /Loading chunk [\w-]+ failed/i.test(msg)
  );
}

function lazyNamed<T extends Record<string, unknown>, K extends keyof T>(
  loader: ModuleLoader<T>,
  exportName: K,
) {
  return lazy(() =>
    loader()
      .then((m) => {
        if (typeof window !== 'undefined') {
          try {
            window.sessionStorage.removeItem(CHUNK_RELOAD_KEY);
          } catch {
            // sessionStorage unavailable
          }
        }
        return { default: m[exportName] as ComponentType<any> };
      })
      .catch((err: unknown) => {
        if (typeof window !== 'undefined' && isChunkLoadError(err)) {
          const target = `${window.location.pathname}${window.location.search}`;
          try {
            if (window.sessionStorage.getItem(CHUNK_RELOAD_KEY) !== target) {
              window.sessionStorage.setItem(CHUNK_RELOAD_KEY, target);
              window.location.reload();
              return new Promise<never>(() => {});
            }
          } catch {
            // sessionStorage unavailable
          }
        }
        throw err;
      }),
  );
}

export const routeLoaders = {
  gateway: () => import('../../features/entry/GatewayPage'),
  dashboard: () => import('../../features/dashboard/DashboardPage'),
  letterbox: () => import('../../features/dashboard/LetterboxArchivePage'),
  desktopApp: () => import('../../features/dashboard/DesktopAppPage'),
  cinema: () => import('../../features/cinema/CinemaPage'),
  videoPlayer: () => import('../../features/cinema/VideoPlayerPage'),
  watchParty: () => import('../../features/watch_party/WatchPartyPage'),
  globalChat: () => import('../../features/global_chat/GlobalChatPage'),
  anime: () => import('../../features/anime/AnimePage'),
  manga: () => import('../../features/manga/MangaPage'),
  mangaReader: () => import('../../features/manga/MangaReaderPage'),
  books: () => import('../../features/books/BooksPage'),
  bookReader: () => import('../../features/books/BookReaderPage'),
  bookSubPages: () => import('../../features/books/BookSubPages'),
  ourBooks: () => import('../../features/books/OurBooksPage'),
  sanctuary: () => import('../../features/chat/SanctuaryPage'),
  gallery: () => import('../../features/gallery/GalleryPage'),
  journal: () => import('../../features/journal/JournalPage'),
  tonight: () => import('../../features/tonight/TonightPage'),
  calendar: () => import('../../features/calendar/CalendarPage'),
  garden: () => import('../../features/daily_bloom/GardenPage'),
  starlight: () => import('../../features/starlight_jar/StarlightPage'),
  bucketList: () => import('../../features/bucket_list/BucketListPage'),
  money: () => import('../../features/money/MoneyPage'),
  subs: () => import('../../features/subs/SubsPage'),
  canvas: () => import('../../features/canvas/CanvasPage'),
  tripList: () => import('../../features/trips/TripListPage'),
  tripDetail: () => import('../../features/trips/TripDetailPage'),
  jukebox: () => import('../../features/jukebox/JukeboxPage'),
  spotifyCallback: () => import('../../features/jukebox/SpotifyCallbackPage'),
  academyHub: () => import('../../features/academy/AcademyHubPage'),
  soloStudy: () => import('../../features/academy/SoloStudyPage'),
  gameBoard: () => import('../../features/academy/GameBoardPage'),
  podium: () => import('../../features/academy/PodiumPage'),
  motchi: () => import('../../features/ai/MotchiPage'),
  motchiPreferences: () => import('../../features/ai/MotchiPreferencesPage'),
  motchiMinis: () => import('../../features/ai/MotchiMinisPage'),
  motchiToday: () => import('../../features/ai/MotchiTodayPage'),
  memoryTrivia: () => import('../../features/ai/MemoryTriviaPage'),
  memoryBook: () => import('../../features/ai/MemoryBookPage'),
  study: () => import('../../features/ai/StudyPage'),
  playZoneHub: () => import('../../features/play_zone/PlayZoneHubPage'),
  tableTennis: () => import('../../features/play_zone/table_tennis/TableTennisPage'),
  ttLobby: () => import('../../features/play_zone/table_tennis/TTLobbyPage'),
  scribble: () => import('../../features/play_zone/ScribblePage'),
  chess: () => import('../../features/play_zone/chess/ChessPage'),
  error: () => import('./ErrorPage'),
} as const;

export const LazyPages = {
  GatewayPage: lazyNamed(routeLoaders.gateway, 'GatewayPage'),
  DashboardPage: lazyNamed(routeLoaders.dashboard, 'DashboardPage'),
  LetterboxArchivePage: lazyNamed(routeLoaders.letterbox, 'LetterboxArchivePage'),
  DesktopAppPage: lazyNamed(routeLoaders.desktopApp, 'DesktopAppPage'),
  CinemaPage: lazyNamed(routeLoaders.cinema, 'CinemaPage'),
  VideoPlayerPage: lazyNamed(routeLoaders.videoPlayer, 'VideoPlayerPage'),
  WatchPartyPage: lazyNamed(routeLoaders.watchParty, 'WatchPartyPage'),
  GlobalChatPage: lazyNamed(routeLoaders.globalChat, 'GlobalChatPage'),
  AnimePage: lazyNamed(routeLoaders.anime, 'AnimePage'),
  MangaPage: lazyNamed(routeLoaders.manga, 'MangaPage'),
  MangaReaderPage: lazyNamed(routeLoaders.mangaReader, 'MangaReaderPage'),
  BooksPage: lazyNamed(routeLoaders.books, 'BooksPage'),
  BookReaderPage: lazyNamed(routeLoaders.bookReader, 'BookReaderPage'),
  BookDetailPage: lazyNamed(routeLoaders.bookSubPages, 'BookDetailPage'),
  BookListPage: lazyNamed(routeLoaders.bookSubPages, 'BookListPage'),
  BookCategoriesPage: lazyNamed(routeLoaders.bookSubPages, 'BookCategoriesPage'),
  OurBooksPage: lazyNamed(routeLoaders.ourBooks, 'OurBooksPage'),
  SanctuaryPage: lazyNamed(routeLoaders.sanctuary, 'SanctuaryPage'),
  GalleryPage: lazyNamed(routeLoaders.gallery, 'GalleryPage'),
  JournalPage: lazyNamed(routeLoaders.journal, 'JournalPage'),
  TonightPage: lazyNamed(routeLoaders.tonight, 'TonightPage'),
  CalendarPage: lazyNamed(routeLoaders.calendar, 'CalendarPage'),
  GardenPage: lazyNamed(routeLoaders.garden, 'GardenPage'),
  StarlightPage: lazyNamed(routeLoaders.starlight, 'StarlightPage'),
  BucketListPage: lazyNamed(routeLoaders.bucketList, 'BucketListPage'),
  MoneyPage: lazyNamed(routeLoaders.money, 'MoneyPage'),
  SubsPage: lazyNamed(routeLoaders.subs, 'SubsPage'),
  CanvasPage: lazyNamed(routeLoaders.canvas, 'CanvasPage'),
  TripListPage: lazyNamed(routeLoaders.tripList, 'TripListPage'),
  TripDetailPage: lazyNamed(routeLoaders.tripDetail, 'TripDetailPage'),
  JukeboxPage: lazyNamed(routeLoaders.jukebox, 'JukeboxPage'),
  SpotifyCallbackPage: lazyNamed(routeLoaders.spotifyCallback, 'SpotifyCallbackPage'),
  AcademyHubPage: lazyNamed(routeLoaders.academyHub, 'AcademyHubPage'),
  SoloStudyPage: lazyNamed(routeLoaders.soloStudy, 'SoloStudyPage'),
  GameBoardPage: lazyNamed(routeLoaders.gameBoard, 'GameBoardPage'),
  PodiumPage: lazyNamed(routeLoaders.podium, 'PodiumPage'),
  MotchiPage: lazyNamed(routeLoaders.motchi, 'MotchiPage'),
  MotchiPreferencesPage: lazyNamed(routeLoaders.motchiPreferences, 'MotchiPreferencesPage'),
  MotchiMinisPage: lazyNamed(routeLoaders.motchiMinis, 'MotchiMinisPage'),
  MotchiTodayPage: lazyNamed(routeLoaders.motchiToday, 'MotchiTodayPage'),
  MemoryTriviaPage: lazyNamed(routeLoaders.memoryTrivia, 'MemoryTriviaPage'),
  MemoryBookPage: lazyNamed(routeLoaders.memoryBook, 'MemoryBookPage'),
  StudyPage: lazyNamed(routeLoaders.study, 'StudyPage'),
  PlayZoneHubPage: lazyNamed(routeLoaders.playZoneHub, 'PlayZoneHubPage'),
  TableTennisPage: lazyNamed(routeLoaders.tableTennis, 'TableTennisPage'),
  TTLobbyPage: lazyNamed(routeLoaders.ttLobby, 'TTLobbyPage'),
  ScribblePage: lazyNamed(routeLoaders.scribble, 'ScribblePage'),
  ChessPage: lazyNamed(routeLoaders.chess, 'ChessPage'),
  ErrorPage: lazyNamed(routeLoaders.error, 'ErrorPage'),
};

const ROUTE_PREFETCH_MAP: Record<string, () => Promise<unknown>> = {
  '/': routeLoaders.gateway,
  '/dashboard': routeLoaders.dashboard,
  '/letterbox': routeLoaders.letterbox,
  '/desktop-app': routeLoaders.desktopApp,
  '/cinema': routeLoaders.cinema,
  '/watch-party': routeLoaders.watchParty,
  '/global-chat': routeLoaders.globalChat,
  '/anime': routeLoaders.anime,
  '/manga': routeLoaders.manga,
  '/books': routeLoaders.books,
  '/our-books': routeLoaders.ourBooks,
  '/sanctuary': routeLoaders.sanctuary,
  '/gallery': routeLoaders.gallery,
  '/journal': routeLoaders.journal,
  '/tonight': routeLoaders.tonight,
  '/calendar': routeLoaders.calendar,
  '/garden': routeLoaders.garden,
  '/starlight': routeLoaders.starlight,
  '/bucket-list': routeLoaders.bucketList,
  '/money': routeLoaders.money,
  '/subs': routeLoaders.subs,
  '/canvas': routeLoaders.canvas,
  '/trips': routeLoaders.tripList,
  '/jukebox': routeLoaders.jukebox,
  '/academy': routeLoaders.academyHub,
  '/motchi': routeLoaders.motchi,
  '/play-zone': routeLoaders.playZoneHub,
};

const prefetched = new Set<string>();

export function prefetchRoute(route: string): void {
  const path = route.split('?')[0];
  if (prefetched.has(path)) return;
  const loader = ROUTE_PREFETCH_MAP[path];
  if (!loader) return;
  prefetched.add(path);
  void loader().catch(() => {
    prefetched.delete(path);
  });
}

let idlePrefetchScheduled = false;

export function scheduleIdleMediaPrefetch(): void {
  if (idlePrefetchScheduled || typeof window === 'undefined') return;
  const conn = (navigator as { connection?: { saveData?: boolean } }).connection;
  if (conn?.saveData) return;
  idlePrefetchScheduled = true;
  const targets = ['/cinema', '/anime', '/manga', '/books'];
  let idx = 0;
  const step = () => {
    if (idx >= targets.length) return;
    prefetchRoute(targets[idx++]);
    if (idx < targets.length) {
      globalThis.setTimeout(runNext, 2000);
    }
  };
  const runNext = () => {
    const ric = (globalThis as { requestIdleCallback?: (cb: () => void, opts?: { timeout: number }) => void })
      .requestIdleCallback;
    if (typeof ric === 'function') {
      ric(step, { timeout: 6000 });
    } else {
      globalThis.setTimeout(step, 1500);
    }
  };
  globalThis.setTimeout(runNext, 4500);
}
