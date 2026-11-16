// Port of lib/core/router/app_router.dart. Each feature adds its routes here
// as it moves over; everything else shows the placeholder.
import { useEffect } from 'react';
import { createBrowserRouter, Outlet, redirect, RouterProvider, useLocation, type LoaderFunctionArgs } from 'react-router';
import { AgentHudOverlay } from './core/agent/AgentHud';
import { AgentMode } from './core/agent/agentMode';
import { ErrorPage } from './core/router/ErrorPage';
import { agentJumpLocation, cinemaOnlyRedirect } from './core/router/routeHelpers';
import { RouteMemory } from './core/router/routeMemory';
import { NotPortedPage } from './core/router/NotPortedPage';
import { authService } from './core/services/auth';
import { AnimePage } from './features/anime/AnimePage';
import {
  BookCategoriesPage,
  BookDetailPage,
  BookListPage,
  BookReaderPage,
} from './features/books/BookSubPages';
import { BooksPage } from './features/books/BooksPage';
import { OurBooksPage } from './features/books/OurBooksPage';
import { BucketListPage } from './features/bucket_list/BucketListPage';
import { MoneyPage } from './features/money/MoneyPage';
import { SubsPage } from './features/subs/SubsPage';
import { CanvasPage } from './features/canvas/CanvasPage';
import { CalendarPage } from './features/calendar/CalendarPage';
import { CinemaPage } from './features/cinema/CinemaPage';
import { VideoPlayerPage } from './features/cinema/VideoPlayerPage';
import { GardenPage } from './features/daily_bloom/GardenPage';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { DesktopAppPage } from './features/dashboard/DesktopAppPage';
import { LetterboxArchivePage } from './features/dashboard/LetterboxArchivePage';
import { GatewayPage } from './features/entry/GatewayPage';
import { GalleryPage } from './features/gallery/GalleryPage';
import { JournalPage } from './features/journal/JournalPage';
import { MangaPage } from './features/manga/MangaPage';
import { MangaReaderPage } from './features/manga/MangaReaderPage';
import { SanctuaryPage } from './features/chat/SanctuaryPage';
import { StarlightPage } from './features/starlight_jar/StarlightPage';
import { TonightPage } from './features/tonight/TonightPage';
import { WatchPartyPage } from './features/watch_party/WatchPartyPage';
import { DialogHost } from './shared/widgets/Dialogs';
import { SnackBarHost } from './shared/widgets/SnackBar';

/** The redirect rules from the Flutter router, run before each page. */
function guard({ request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const loc = url.pathname;
  const agentParam = url.searchParams.get('agent') ?? url.searchParams.get('demo');
  const jumpParam = url.searchParams.get('jump') ?? url.searchParams.get('to');
  let target: string | null = null;

  if (agentParam != null) {
    const lower = agentParam.toLowerCase().trim();
    if (lower in AgentMode.routeAliases) {
      target = AgentMode.routeAliases[lower];
      const profile = lower === 'cinema' ? 'breyan' : 'khentsgdz';
      if (AgentMode.enable(profile)) authService.enableAgentSession(profile);
      else target = null;
    } else {
      const profile = AgentMode.parseProfile(agentParam);
      if (AgentMode.enable(profile)) authService.enableAgentSession(profile);
    }
  } else if (AgentMode.isActive.value && authService.currentUser == null) {
    authService.enableAgentSession(AgentMode.activeProfile.value);
  }

  if (jumpParam) {
    const lower = jumpParam.toLowerCase().trim();
    target = AgentMode.routeAliases[lower] ?? jumpParam;
    if (!target.startsWith('/')) target = `/${target}`;
  }

  if (loc === '/' && target != null && target !== '/') {
    return redirect(agentJumpLocation(url.search, target));
  }

  const isPublic = loc === '/' || AgentMode.isActive.value;
  if (!authService.isSessionLoaded) return null;
  const authed = authService.isAuthenticated || authService.currentUser != null;
  if (!authed && !isPublic) {
    return redirect(`/?${new URLSearchParams({ from: loc + url.search })}`);
  }
  if (loc === '/' && authed && !AgentMode.isActive.value && target == null) {
    const remembered = RouteMemory.load();
    if (remembered && (!authService.isCinemaOnlyUser || cinemaOnlyRedirect(remembered) == null)) {
      return redirect(remembered);
    }
  }
  if (authed && authService.isCinemaOnlyUser && !AgentMode.isActive.value) {
    const bounce = cinemaOnlyRedirect(loc);
    if (bounce != null && bounce !== loc) return redirect(bounce);
  }
  return null;
}

function RootLayout() {
  const location = useLocation();
  useEffect(() => {
    RouteMemory.remember(location.pathname + location.search);
  }, [location.pathname, location.search]);
  return (
    <>
      <Outlet />
      <AgentHudOverlay />
      <DialogHost />
      <SnackBarHost />
    </>
  );
}

const KNOWN_UNPORTED = new Set([
  '/trips',
  '/jukebox',
  '/play-zone',
  '/academy',
  '/motchi',
  '/study',
]);

function FallbackRoute() {
  const location = useLocation();
  if (
    KNOWN_UNPORTED.has(location.pathname) ||
    location.pathname.startsWith('/trips/') ||
    location.pathname.startsWith('/play-zone/') ||
    location.pathname.startsWith('/academy/') ||
    location.pathname.startsWith('/motchi/')
  ) {
    return <NotPortedPage />;
  }
  return <ErrorPage />;
}

const router = createBrowserRouter([
  {
    element: <RootLayout />,
    children: [
      { path: '/', loader: guard, element: <GatewayPage /> },
      { path: '/dashboard', loader: guard, element: <DashboardPage /> },
      { path: '/letterbox', loader: guard, element: <LetterboxArchivePage /> },
      { path: '/desktop-app', loader: guard, element: <DesktopAppPage /> },
      { path: '/cinema', loader: guard, element: <CinemaPage /> },
      { path: '/cinema/video/:id', loader: guard, element: <VideoPlayerPage /> },
      { path: '/watch-party', loader: guard, element: <WatchPartyPage /> },
      { path: '/anime', loader: guard, element: <AnimePage /> },
      { path: '/manga', loader: guard, element: <MangaPage /> },
      { path: '/manga/reader', loader: guard, element: <MangaReaderPage /> },
      { path: '/books', loader: guard, element: <BooksPage /> },
      { path: '/books/reader', loader: guard, element: <BookReaderPage /> },
      { path: '/books/listen', loader: guard, element: <BookReaderPage startListening /> },
      { path: '/books/detail', loader: guard, element: <BookDetailPage /> },
      { path: '/books/list', loader: guard, element: <BookListPage /> },
      { path: '/books/category', loader: guard, element: <BookListPage /> },
      { path: '/books/categories', loader: guard, element: <BookCategoriesPage /> },
      { path: '/our-books', loader: guard, element: <OurBooksPage /> },
      { path: '/sanctuary', loader: guard, element: <SanctuaryPage /> },
      { path: '/gallery', loader: guard, element: <GalleryPage /> },
      { path: '/journal', loader: guard, element: <JournalPage /> },
      { path: '/tonight', loader: guard, element: <TonightPage /> },
      { path: '/calendar', loader: guard, element: <CalendarPage /> },
      { path: '/garden', loader: guard, element: <GardenPage /> },
      { path: '/starlight', loader: guard, element: <StarlightPage /> },
      { path: '/bucket-list', loader: guard, element: <BucketListPage /> },
      { path: '/money', loader: guard, element: <MoneyPage /> },
      { path: '/subs', loader: guard, element: <SubsPage /> },
      { path: '/canvas', loader: guard, element: <CanvasPage /> },
      { path: '*', loader: guard, element: <FallbackRoute /> },
    ],
  },
]);

export function App() {
  return <RouterProvider router={router} />;
}
