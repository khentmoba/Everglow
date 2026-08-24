import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../../../core/theme/app_breakpoints.dart';
import '../../../data/services/animex_stores.dart';
import '../cinema_sidebar.dart';

import 'animex_browse_page.dart';
import 'animex_controller.dart';
import 'animex_dmca_page.dart';
import 'animex_history_page.dart';
import 'animex_home_page.dart';
import 'animex_mylist_page.dart';
import 'animex_nav.dart';
import 'animex_playlist_detail_page.dart';
import 'animex_playlists_page.dart';
import 'animex_schedule_page.dart';
import 'animex_search_page.dart';
import 'animex_seasonal_page.dart';
import 'animex_tokens.dart';
import 'animex_watch_page.dart';

/// Full anime section shell: fixed header, page stack and (on mobile)
/// bottom navigation. Top-level pages keep their state via [IndexedStack];
/// watch and playlist-detail pages overlay them.
class AnimeXShell extends StatefulWidget {
  const AnimeXShell({super.key});

  @override
  State<AnimeXShell> createState() => _AnimeXShellState();
}

class _AnimeXShellState extends State<AnimeXShell> {
  final AnimeXController _controller = AnimeXController();
  bool _sidebarCollapsed = false;
  bool _mobileSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    AnimexStores.instance.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.initLibrary(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    final isDesktop = AppBreakpoint.isDesktop(context);
    HapticFeedback.selectionClick();
    if (isDesktop) {
      setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    } else {
      setState(() => _mobileSidebarOpen = !_mobileSidebarOpen);
    }
  }

  void _handleSidebarSelect(int tab, String? browseOptionId) {
    if (_mobileSidebarOpen) {
      setState(() => _mobileSidebarOpen = false);
    }
    final router = GoRouter.of(context);
    if (browseOptionId != null) {
      router.go('/cinema?tab=2&browse=$browseOptionId');
    } else {
      router.go('/cinema?tab=$tab');
    }
  }

  void _handleCinemaTap() {
    if (_mobileSidebarOpen) {
      setState(() => _mobileSidebarOpen = false);
    }
    GoRouter.of(context).go('/cinema');
  }

  void _handleAnimeTap() {
    if (_mobileSidebarOpen) {
      setState(() => _mobileSidebarOpen = false);
    }
    if (_controller.hasDetail) {
      _controller.closeDetail();
    } else {
      _controller.goTo(AnimexPage.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isHeaderDesktop = size.width >= 768;
    final isSidebarDesktop = AppBreakpoint.isDesktop(context);

    return ChangeNotifierProvider.value(
      value: AnimexStores.instance,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final pages = <Widget>[
            AnimeXHomePage(controller: _controller),
            AnimeXBrowsePage(controller: _controller),
            AnimeXSchedulePage(controller: _controller),
            AnimeXSearchPage(controller: _controller),
            AnimeXHistoryPage(controller: _controller),
            AnimeXMyListPage(controller: _controller),
            AnimeXPlaylistsPage(controller: _controller),
            AnimeXSeasonalPage(controller: _controller),
          ];
          final detailChild = _controller.watchItem != null
              ? AnimeXWatchPage(controller: _controller)
              : (_controller.playlistId != null
                    ? AnimeXPlaylistDetailPage(controller: _controller)
                    : (_controller.dmcaOpen
                          ? AnimeXDmcaPage(controller: _controller)
                          : null));

          final auth = context.watch<AuthService>();
          final userName = auth.currentUser ?? '';
          final isCinemaOnlyUser = auth.isCinemaOnlyUser;
          final isCoupleUser = auth.isCoupleUser;

          Widget buildSidebar({
            required bool collapsed,
            required VoidCallback onToggle,
          }) {
            final router = GoRouter.of(context);
            return CinemaSidebar(
              currentIndex: -1,
              activeBrowseOption: null,
              isCollapsed: collapsed,
              onToggle: onToggle,
              onSelect: _handleSidebarSelect,
              onAnimeTap: _handleAnimeTap,
              isAnimeActive: true,
              onCinemaTap: _handleCinemaTap,
              onDashboardTap: isCoupleUser
                  ? () => router.go('/dashboard')
                  : null,
              onLogout: () async {
                if (_mobileSidebarOpen) {
                  setState(() => _mobileSidebarOpen = false);
                }
                await auth.logout();
                if (!mounted) return;
                router.go('/');
              },
              userName: userName,
              isCinemaOnlyUser: isCinemaOnlyUser,
            );
          }

          Widget buildAnimeContent() {
            return Column(
              children: [
                AnimeXTopHeader(
                  controller: _controller,
                  onSearch: () => _controller.goTo(AnimexPage.search),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(
                        index: _controller.page.index,
                        children: pages,
                      ),
                      if (detailChild != null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: AnimeXTokens.bg,
                            child: detailChild,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Desktop: persistent collapsible rail alongside anime content.
          if (isSidebarDesktop) {
            return Scaffold(
              backgroundColor: AnimeXTokens.bg,
              body: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: _sidebarCollapsed ? 72 : 260,
                    child: buildSidebar(
                      collapsed: _sidebarCollapsed,
                      onToggle: _toggleSidebar,
                    ),
                  ),
                  Expanded(
                    child: SafeArea(bottom: false, child: buildAnimeContent()),
                  ),
                ],
              ),
              bottomNavigationBar: null,
            );
          }

          // Mobile / Tablet: overlay drawer + floating hamburger.
          return Scaffold(
            backgroundColor: AnimeXTokens.bg,
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  buildAnimeContent(),
                  if (!_mobileSidebarOpen)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, top: 10),
                          child: Material(
                            color: const Color(0xFF14101A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            elevation: 8,
                            child: InkWell(
                              onTap: _toggleSidebar,
                              borderRadius: BorderRadius.circular(10),
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.menu_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_mobileSidebarOpen) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _mobileSidebarOpen = false),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Material(
                        color: const Color(0xFF0F0A14),
                        elevation: 24,
                        child: SizedBox(
                          width: 280,
                          child: buildSidebar(
                            collapsed: false,
                            onToggle: () =>
                                setState(() => _mobileSidebarOpen = false),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: detailChild == null && !isHeaderDesktop
                ? AnimeXMobileBottomNav(
                    controller: _controller,
                    onSearch: () => _controller.goTo(AnimexPage.search),
                  )
                : null,
          );
        },
      ),
    );
  }
}
