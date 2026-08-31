import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/animex_stores.dart';

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

/// Full anime section shell: header, page stack.
/// The legacy collapsible CinemaSidebar was removed per product request:
///  - No sidebar is rendered for any user.
///  - A single Cinema switch is shown ONLY to cinema-only profiles
///    (breyan / octagram) inside AnimeXTopHeader; khent / clair see no
///    cinema affordance here and use the Dashboard back arrow instead.
class AnimeXShell extends StatefulWidget {
  const AnimeXShell({super.key});

  @override
  State<AnimeXShell> createState() => _AnimeXShellState();
}

class _AnimeXShellState extends State<AnimeXShell> {
  final AnimeXController _controller = AnimeXController();

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isHeaderDesktop = size.width >= 768;

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

          return Scaffold(
            backgroundColor: AnimeXTokens.bg,
            body: SafeArea(
              bottom: false,
              child: buildAnimeContent(),
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
