// Port of lib/core/router/app_router.dart. Each route loads on demand via React.lazy.
import { Component, lazy, Suspense, useEffect, type ReactNode } from 'react';
import { createBrowserRouter, Outlet, redirect, RouterProvider, useLocation, useNavigate, type LoaderFunctionArgs } from 'react-router';
import { AgentMode } from './core/agent/agentMode';
import { LazyPages } from './core/router/routeChunks';
import { agentJumpLocation, cinemaOnlyRedirect, sanitizeInternalPath, startupLandingRedirect } from './core/router/routeHelpers';
import { RouteMemory } from './core/router/routeMemory';
import { authService } from './core/services/auth';
import { notificationService } from './core/services/notifications';
import { presenceService } from './core/services/presence';
import { useValue } from './core/system/store';
import { AppColors } from './core/theme/colors';
import { WelcomeGiftGate } from './features/entry/WelcomeGiftGate';
import { IncomingWatchPartyBanner } from './features/watch_party/IncomingWatchPartyBanner';
import { AppUpdatePrompt } from './shared/widgets/AppUpdatePrompt';
import { ConnectivityBanner } from './shared/widgets/ConnectivityBanner';
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
async function guard({ request }: LoaderFunctionArgs) {
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

  if (jumpParam && (AgentMode.canActivate || AgentMode.isActive.value)) {
    const trimmed = jumpParam.trim();
    const lower = trimmed.toLowerCase();
    const candidate = AgentMode.routeAliases[lower] ?? (trimmed.startsWith('/') ? trimmed : `/${trimmed}`);
    target = sanitizeInternalPath(candidate);
  }

  if (loc === '/' && target != null && target !== '/') {
    return redirect(agentJumpLocation(url.search, target));
  }

  const isPublic = loc === '/' || AgentMode.isActive.value;
  if (!authService.isSessionLoaded) return null;
  if (!AgentMode.isActive.value) {
    await authService.waitForAuthReady();
  }
  const authed = authService.hasActiveSession;
  if (!authed && !isPublic) {
    return redirect(`/?${new URLSearchParams({ from: loc + url.search })}`);
  }
  if (loc === '/' && !AgentMode.isActive.value && target == null) {
    const landing = startupLandingRedirect(loc, authed, authService.currentUser != null, authService.isCinemaOnlyUser);
    if (landing != null) {
      RouteMemory.clear();
      return redirect(landing);
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
    RouteMemory.clear();
  }, []);
  useEffect(() => {
    const checkSession = () => {
      if (
        location.pathname === '/' ||
        AgentMode.isActive.value ||
        !authService.hasResolvedAuthState ||
        authService.hasActiveSession
      ) {
        return;
      }
      navigate(`/?${new URLSearchParams({ from: location.pathname + location.search })}`, { replace: true });
    };
    checkSession();
    const unsub = authService.subscribe(checkSession);
    return () => {
      unsub();
    };
  }, [location.pathname, location.search, navigate]);
  useEffect(() => {
    notificationService.setForegroundHandler((n) => {
      const label = [n.title, n.body].filter(Boolean).join(' — ');
      showSnackBar(label, {
        duration: 4000,
        action: n.route ? { label: 'View', onPressed: () => navigate(n.route!) } : undefined,
      });
    });
    let timer: number | undefined;
    const maybeInit = () => {
      if (AgentMode.demo || !authService.isReady || !authService.isCoupleUser || timer != null) return;
      timer = window.setTimeout(() => {
        void notificationService.initialize();
      }, 1500);
    };
    maybeInit();
    const unsubAuth = authService.subscribe(maybeInit);
    return () => {
      unsubAuth();
      if (timer != null) window.clearTimeout(timer);
      notificationService.setForegroundHandler(null);
    };
  }, [navigate]);
  useEffect(() => {
    let activeUid: string | null = null;
    let activeUsername: string | null = null;

    const sync = () => {
      if (AgentMode.demo || !authService.isReady || !authService.isCoupleUser || !authService.uid || !authService.currentUser) {
        if (activeUid) {
          activeUid = null;
          activeUsername = null;
          void presenceService.stopHeartbeat();
        }
        return;
      }
      const uid = authService.uid;
      const username = authService.currentUser;
      if (uid === activeUid && username === activeUsername) return;
      activeUid = uid;
      activeUsername = username;
      if (!document.hidden) presenceService.startHeartbeat(uid, username);
    };

    const onVis = () => {
      if (!activeUid || !activeUsername) return;
      if (document.hidden) void presenceService.setOffline(activeUid);
      else presenceService.startHeartbeat(activeUid, activeUsername);
    };
    const onLeave = () => {
      if (activeUid) void presenceService.stopHeartbeat();
    };

    sync();
    const unsubAuth = authService.subscribe(sync);
    document.addEventListener('visibilitychange', onVis);
    window.addEventListener('pagehide', onLeave);
    window.addEventListener('beforeunload', onLeave);
    return () => {
      unsubAuth();
      document.removeEventListener('visibilitychange', onVis);
      window.removeEventListener('pagehide', onLeave);
      window.removeEventListener('beforeunload', onLeave);
      if (activeUid) void presenceService.stopHeartbeat();
    };
  }, []);
  return (
    <>
      <RouteErrorBoundary
        resetKey={location.pathname}
        onGoHome={() => {
          const home = !authService.hasActiveSession ? '/' : authService.isCinemaOnlyUser ? '/cinema' : '/dashboard';
          if (location.pathname === home) window.location.reload();
          else navigate(home);
        }}
      >
        <Suspense fallback={<RouteFallback />}>
          <Outlet />
        </Suspense>
      </RouteErrorBoundary>
      <AppUpdatePrompt />
      <div
        style={{
          position: 'fixed',
          top: 'calc(var(--safe-top, env(safe-area-inset-top, 0px)) + 10px)',
          left: '50%',
          transform: 'translateX(-50%)',
          zIndex: 1350,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 8,
          width: 'min(92vw, 440px)',
          pointerEvents: 'none',
        }}
      >
        <ConnectivityBanner />
        <IncomingWatchPartyBanner />
      </div>
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
      { path: '/global-chat', loader: guard, element: <LazyPages.GlobalChatPage /> },
      { path: '/anime', loader: guard, element: <LazyPages.AnimePage /> },
      { path: '/manga', loader: guard, element: <LazyPages.MangaPage /> },
      { path: '/manga/reader', loader: guard, element: <LazyPages.MangaReaderPage /> },
      { path: '/manga/series/:slug', loader: guard, element: <LazyPages.MangaPage /> },
      { path: '/manga/series/:slug/:chapterId', loader: guard, element: <LazyPages.MangaPage /> },
      { path: '/manga/series/:slug/read/:chapterId', loader: guard, element: <LazyPages.MangaPage /> },
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
