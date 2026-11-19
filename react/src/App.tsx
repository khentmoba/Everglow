// Port of lib/core/router/app_router.dart. Each route loads on demand via React.lazy.
import { Component, lazy, Suspense, useEffect, type ReactNode } from 'react';
import { createBrowserRouter, Outlet, redirect, RouterProvider, useLocation, useNavigate, type LoaderFunctionArgs } from 'react-router';
import { AgentMode } from './core/agent/agentMode';
import { LazyPages } from './core/router/routeChunks';
import { agentJumpLocation, cinemaOnlyRedirect } from './core/router/routeHelpers';
import { RouteMemory } from './core/router/routeMemory';
import { authService } from './core/services/auth';
import { notificationService } from './core/services/notifications';
import { useValue } from './core/system/store';
import { AppColors } from './core/theme/colors';
import { WelcomeGiftGate } from './features/entry/WelcomeGiftGate';
import { AppUpdatePrompt } from './shared/widgets/AppUpdatePrompt';
import { DialogHost } from './shared/widgets/Dialogs';
import { showSnackBar, SnackBarHost } from './shared/widgets/SnackBar';

class RouteErrorBoundary extends Component<
  { resetKey: string; onGoHome: () => void; children: ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidUpdate(prevProps: { resetKey: string }) {
    if (this.state.hasError && prevProps.resetKey !== this.props.resetKey) {
      this.setState({ hasError: false });
    }
  }

  render() {
    if (!this.state.hasError) return this.props.children;
    return (
      <div
        role="alert"
        style={{
          position: 'fixed',
          inset: 0,
          background: AppColors.inkDeep,
          color: AppColors.petalWhite,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 14,
          padding: 24,
          textAlign: 'center',
        }}
      >
        <div style={{ fontSize: 18, fontWeight: 700 }}>Could not open this page</div>
        <div style={{ fontSize: 13.5, opacity: 0.78, maxWidth: 320 }}>
          Check your connection and try again, or head back to your home screen.
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button
            type="button"
            className="bare-button"
            onClick={() => window.location.reload()}
            style={{
              padding: '10px 18px',
              borderRadius: 12,
              background: AppColors.deepRose,
              color: AppColors.petalWhite,
              fontWeight: 600,
            }}
          >
            Try again
          </button>
          <button
            type="button"
            className="bare-button"
            onClick={() => {
              this.setState({ hasError: false });
              this.props.onGoHome();
            }}
            style={{
              padding: '10px 18px',
              borderRadius: 12,
              border: `1px solid ${AppColors.roseQuartz}`,
              color: AppColors.petalWhite,
              fontWeight: 600,
            }}
          >
            Home
          </button>
        </div>
      </div>
    );
  }
}

const LazyAgentHudOverlay = lazy(() =>
  import('./core/agent/AgentHud')
    .then((m) => ({ default: m.AgentHudOverlay }))
    .catch(() => ({ default: () => null })),
);

function AgentHudSlot() {
  const active = useValue(AgentMode.isActive);
  const show = useValue(AgentMode.showHud);
  if (!active || !show) return null;
  return (
    <Suspense fallback={null}>
      <LazyAgentHudOverlay />
    </Suspense>
  );
}

function RouteFallback() {
  return <div style={{ position: 'fixed', inset: 0, background: AppColors.inkDeep }} aria-busy="true" />;
}

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
    let timer: number | undefined;
    if (!AgentMode.demo) {
      timer = window.setTimeout(() => {
        void notificationService.initialize();
      }, 1500);
    }
    return () => {
      if (timer != null) window.clearTimeout(timer);
      notificationService.setForegroundHandler(null);
    };
  }, [navigate]);
  return (
    <>
      <RouteErrorBoundary
        resetKey={location.pathname}
        onGoHome={() => {
          if (location.pathname === '/dashboard') window.location.reload();
          else navigate('/dashboard');
        }}
      >
        <Suspense fallback={<RouteFallback />}>
          <Outlet />
        </Suspense>
      </RouteErrorBoundary>
      <AppUpdatePrompt />
      <AgentHudSlot />
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
      { path: '/', loader: guard, element: <LazyPages.GatewayPage /> },
      { path: '/dashboard', loader: guard, element: <LazyPages.DashboardPage /> },
      { path: '/letterbox', loader: guard, element: <LazyPages.LetterboxArchivePage /> },
      { path: '/desktop-app', loader: guard, element: <LazyPages.DesktopAppPage /> },
      { path: '/cinema', loader: guard, element: <LazyPages.CinemaPage /> },
      { path: '/cinema/video/:id', loader: guard, element: <LazyPages.VideoPlayerPage /> },
      { path: '/watch-party', loader: guard, element: <LazyPages.WatchPartyPage /> },
      { path: '/anime', loader: guard, element: <LazyPages.AnimePage /> },
      { path: '/manga', loader: guard, element: <LazyPages.MangaPage /> },
      { path: '/manga/reader', loader: guard, element: <LazyPages.MangaReaderPage /> },
      { path: '/books', loader: guard, element: <LazyPages.BooksPage /> },
      { path: '/books/reader', loader: guard, element: <LazyPages.BookReaderPage /> },
      { path: '/books/listen', loader: guard, element: <LazyPages.BookReaderPage startListening /> },
      { path: '/books/detail', loader: guard, element: <LazyPages.BookDetailPage /> },
      { path: '/books/list', loader: guard, element: <LazyPages.BookListPage /> },
      { path: '/books/category', loader: guard, element: <LazyPages.BookListPage /> },
      { path: '/books/categories', loader: guard, element: <LazyPages.BookCategoriesPage /> },
      { path: '/our-books', loader: guard, element: <LazyPages.OurBooksPage /> },
      { path: '/sanctuary', loader: guard, element: <LazyPages.SanctuaryPage /> },
      { path: '/gallery', loader: guard, element: <LazyPages.GalleryPage /> },
      { path: '/journal', loader: guard, element: <LazyPages.JournalPage /> },
      { path: '/tonight', loader: guard, element: <LazyPages.TonightPage /> },
      { path: '/calendar', loader: guard, element: <LazyPages.CalendarPage /> },
      { path: '/garden', loader: guard, element: <LazyPages.GardenPage /> },
      { path: '/starlight', loader: guard, element: <LazyPages.StarlightPage /> },
      { path: '/bucket-list', loader: guard, element: <LazyPages.BucketListPage /> },
      { path: '/money', loader: guard, element: <LazyPages.MoneyPage /> },
      { path: '/subs', loader: guard, element: <LazyPages.SubsPage /> },
      { path: '/canvas', loader: guard, element: <LazyPages.CanvasPage /> },
      { path: '/trips', loader: guard, element: <LazyPages.TripListPage /> },
      { path: '/trips/:id', loader: guard, element: <LazyPages.TripDetailPage /> },
      { path: '/jukebox', loader: guard, element: <LazyPages.JukeboxPage /> },
      { path: '/spotify/callback', loader: guard, element: <LazyPages.SpotifyCallbackPage /> },
      { path: '/academy', loader: guard, element: <LazyPages.AcademyHubPage /> },
      { path: '/academy/solo', loader: guard, element: <LazyPages.SoloStudyPage /> },
      { path: '/academy/match', loader: guard, element: <LazyPages.GameBoardPage /> },
      { path: '/academy/podium', loader: guard, element: <LazyPages.PodiumPage /> },
      { path: '/motchi', loader: guard, element: <LazyPages.MotchiPage /> },
      { path: '/motchi-preferences', loader: guard, element: <LazyPages.MotchiPreferencesPage /> },
      { path: '/motchi-minis', loader: guard, element: <LazyPages.MotchiMinisPage /> },
      { path: '/motchi-today', loader: guard, element: <LazyPages.MotchiTodayPage /> },
      { path: '/motchi-trivia', loader: guard, element: <LazyPages.MemoryTriviaPage /> },
      { path: '/motchi-memory', loader: guard, element: <LazyPages.MemoryBookPage /> },
      { path: '/study', loader: guard, element: <LazyPages.StudyPage /> },
      { path: '/play-zone', loader: guard, element: <LazyPages.PlayZoneHubPage /> },
      { path: '/play-zone/tt', loader: guard, element: <LazyPages.TableTennisPage /> },
      { path: '/play-zone/tt/lobby', loader: guard, element: <LazyPages.TTLobbyPage /> },
      { path: '/play-zone/scribble', loader: guard, element: <LazyPages.ScribblePage /> },
      { path: '/play-zone/chess', loader: guard, element: <LazyPages.ChessPage /> },
      { path: '*', loader: guard, element: <LazyPages.ErrorPage /> },
    ],
  },
]);

export function App() {
  return <RouterProvider router={router} />;
}
