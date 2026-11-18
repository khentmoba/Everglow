// Port of lib/core/router/app_router.dart. Each feature adds its routes here
// as it moves over; everything else shows the placeholder.
import { useEffect } from 'react';
import { createBrowserRouter, Outlet, redirect, RouterProvider, useLocation, type LoaderFunctionArgs } from 'react-router';
import { AgentHudOverlay } from './core/agent/AgentHud';
import { AgentMode } from './core/agent/agentMode';
import { ErrorPage } from './core/router/ErrorPage';
import { agentJumpLocation, cinemaOnlyRedirect } from './core/router/routeHelpers';
import { RouteMemory } from './core/router/routeMemory';
import { AcademyHubPage } from './features/academy/AcademyHubPage';
import { GameBoardPage } from './features/academy/GameBoardPage';
import { PodiumPage } from './features/academy/PodiumPage';
import { SoloStudyPage } from './features/academy/SoloStudyPage';
import { MemoryTriviaPage } from './features/ai/MemoryTriviaPage';
import { MemoryBookPage } from './features/ai/MemoryBookPage';
import { MotchiMinisPage } from './features/ai/MotchiMinisPage';
import { MotchiPage } from './features/ai/MotchiPage';
import { MotchiPreferencesPage } from './features/ai/MotchiPreferencesPage';
import { MotchiTodayPage } from './features/ai/MotchiTodayPage';
import { StudyPage } from './features/ai/StudyPage';
import { authService } from './core/services/auth';
import { AnimePage } from './features/anime/AnimePage';
import { BookCategoriesPage, BookDetailPage, BookListPage, BookReaderPage } from './features/books/BookSubPages';
import { BooksPage } from './features/books/BooksPage';
import { OurBooksPage } from './features/books/OurBooksPage';
import { BucketListPage } from './features/bucket_list/BucketListPage';
import { MoneyPage } from './features/money/MoneyPage';
import { SubsPage } from './features/subs/SubsPage';
import { CanvasPage } from './features/canvas/CanvasPage';
import { TripDetailPage } from './features/trips/TripDetailPage';
import { TripListPage } from './features/trips/TripListPage';
import { JukeboxPage } from './features/jukebox/JukeboxPage';
import { SpotifyCallbackPage } from './features/jukebox/SpotifyCallbackPage';
import { PlayZoneHubPage } from './features/play_zone/PlayZoneHubPage';
import { ChessPage } from './features/play_zone/chess/ChessPage';
import { ScribblePage } from './features/play_zone/ScribblePage';
import { TableTennisPage } from './features/play_zone/table_tennis/TableTennisPage';
import { TTLobbyPage } from './features/play_zone/table_tennis/TTLobbyPage';
import { CalendarPage } from './features/calendar/CalendarPage';
import { CinemaPage } from './features/cinema/CinemaPage';
import { VideoPlayerPage } from './features/cinema/VideoPlayerPage';
import { GardenPage } from './features/daily_bloom/GardenPage';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { WelcomeGiftGate } from './features/entry/WelcomeGiftGate';
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
import { AppUpdatePrompt } from './shared/widgets/AppUpdatePrompt';
import { DialogHost } from './shared/widgets/Dialogs';
import { showSnackBar, SnackBarHost } from './shared/widgets/SnackBar';
import { notificationService } from './core/services/notifications';
import { useNavigate } from 'react-router';

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
  const navigate = useNavigate();
  useEffect(() => {
    RouteMemory.remember(location.pathname + location.search);
  }, [location.pathname, location.search]);
  useEffect(() => {
    notificationService.setForegroundHandler((n) => {
      const label = [n.title, n.body].filter(Boolean).join(' — ');
      showSnackBar(label, {
        duration: 4000,
        action: n.route ? { label: 'View', onPressed: () => navigate(n.route!) } : undefined,
      });
    });
    if (!AgentMode.demo) {
      void notificationService.initialize();
    }
    return () => notificationService.setForegroundHandler(null);
  }, [navigate]);
  return (
    <>
      <Outlet />
      <AppUpdatePrompt />
      <AgentHudOverlay />
      <DialogHost />
      <SnackBarHost />
      <WelcomeGiftGate />
    </>
  );
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
      { path: '/trips', loader: guard, element: <TripListPage /> },
      { path: '/trips/:id', loader: guard, element: <TripDetailPage /> },
      { path: '/jukebox', loader: guard, element: <JukeboxPage /> },
      { path: '/spotify/callback', loader: guard, element: <SpotifyCallbackPage /> },
      { path: '/academy', loader: guard, element: <AcademyHubPage /> },
      { path: '/academy/solo', loader: guard, element: <SoloStudyPage /> },
      { path: '/academy/match', loader: guard, element: <GameBoardPage /> },
      { path: '/academy/podium', loader: guard, element: <PodiumPage /> },
      { path: '/motchi', loader: guard, element: <MotchiPage /> },
      { path: '/motchi-preferences', loader: guard, element: <MotchiPreferencesPage /> },
      { path: '/motchi-minis', loader: guard, element: <MotchiMinisPage /> },
      { path: '/motchi-today', loader: guard, element: <MotchiTodayPage /> },
      { path: '/motchi-trivia', loader: guard, element: <MemoryTriviaPage /> },
      { path: '/motchi-memory', loader: guard, element: <MemoryBookPage /> },
      { path: '/study', loader: guard, element: <StudyPage /> },
      { path: '/play-zone', loader: guard, element: <PlayZoneHubPage /> },
      { path: '/play-zone/tt', loader: guard, element: <TableTennisPage /> },
      { path: '/play-zone/tt/lobby', loader: guard, element: <TTLobbyPage /> },
      { path: '/play-zone/scribble', loader: guard, element: <ScribblePage /> },
      { path: '/play-zone/chess', loader: guard, element: <ChessPage /> },
      { path: '*', loader: guard, element: <ErrorPage /> },
    ],
  },
]);

export function App() {
  return <RouterProvider router={router} />;
}
