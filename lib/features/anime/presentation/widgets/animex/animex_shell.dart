import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/services/auth_service.dart';
import '../../../../../core/system/tv_mode.dart';
import '../../../../../shared/widgets/everglow/lazy_indexed_stack.dart';
import '../../../../../shared/widgets/shelf/tv_media_nav_header.dart';
import '../../../../ai/domain/models/ai_conversation.dart';
import '../../../../cinema/data/models/media_item.dart';
import '../../../data/services/animex_stores.dart';

import 'animex_browse_page.dart';
import 'animex_controller.dart';
import 'animex_dmca_page.dart';
import 'animex_downloads_page.dart';
import 'animex_history_page.dart';
import 'animex_home_page.dart';
import 'animex_motchi_sidebar.dart';
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
  final int? initialAnilistId;
  final int? initialMalId;
  final int? initialTmdbId;
  final String? initialSource;
  final String? initialType;
  final String? initialFormat;
  final String? initialTitle;
  final String? initialPoster;
  final int? initialEpisode;

  const AnimeXShell({
    super.key,
    this.initialAnilistId,
    this.initialMalId,
    this.initialTmdbId,
    this.initialSource,
    this.initialType,
    this.initialFormat,
    this.initialTitle,
    this.initialPoster,
    this.initialEpisode,
  });

  @override
  State<AnimeXShell> createState() => _AnimeXShellState();
}

class _AnimeXShellState extends State<AnimeXShell> {
  final AnimeXController _controller = AnimeXController();
  final List<AIMessage> _motchiMessages = [];
  String? _lastUser;
  MediaItem? _lastWatchItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthService>().currentUser;
      _lastUser = user;
      AnimexStores.instance.load(username: user);
      _controller.initLibrary(context);
      _maybeOpenInitialItem();
    });
  }

  void _maybeOpenInitialItem() {
    final anilistId = widget.initialAnilistId;
    final malId = widget.initialMalId;
    final tmdbId = widget.initialTmdbId;
    final source = widget.initialSource ??
        (tmdbId != null && tmdbId > 0 && (malId == null || malId <= 0)
            ? 'tmdb'
            : 'jikan');

    final isMovie = (widget.initialType?.toLowerCase() == 'movie') ||
        (widget.initialFormat?.toUpperCase() == 'MOVIE');
    final mediaType = isMovie ? 'movie' : (widget.initialType ?? 'tv');
    final resolvedTmdbId =
        source == 'tmdb' ? (tmdbId ?? 0) : (malId ?? tmdbId ?? 0);

    if (anilistId != null || resolvedTmdbId > 0) {
      final initialItem = MediaItem(
        id: '',
        tmdbId: resolvedTmdbId,
        title: widget.initialTitle ?? '',
        mediaType: mediaType,
        posterPath: widget.initialPoster ?? '',
        year: '',
        status: '',
        isAnime: true,
        addedAt: DateTime.now(),
        source: source,
        anilistId: anilistId,
        format: widget.initialFormat ?? (isMovie ? 'MOVIE' : 'TV'),
      );
      _controller.openWatch(initialItem, episode: widget.initialEpisode);
    }
  }

  @override
  void didUpdateWidget(covariant AnimeXShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.initialAnilistId != null ||
            widget.initialMalId != null ||
            widget.initialTmdbId != null) &&
        (widget.initialAnilistId != oldWidget.initialAnilistId ||
            widget.initialMalId != oldWidget.initialMalId ||
            widget.initialTmdbId != oldWidget.initialTmdbId ||
            widget.initialEpisode != oldWidget.initialEpisode)) {
      _maybeOpenInitialItem();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: TvMode.isTvMode,
      builder: (context, isTv, _) {
        final size = MediaQuery.sizeOf(context);
        final isHeaderDesktop =
            size.width >= AnimeXTokens.desktopNavBreakpoint || isTv;
    final isCoupleUser =
        context.select<AuthService, bool>((a) => a.isCoupleUser);
    // If the profile changed while the shell is mounted (logout/login on
    // the same PWA), reload both the per-user history store and the
    // per-user watchlist stream so no data bleeds across profiles.
    final authUser = context.select<AuthService, String?>((a) => a.currentUser);
    if (_lastUser != null && _lastUser != authUser) {
      _lastUser = authUser;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AnimexStores.instance.switchUser(authUser);
        _controller.initLibrary(context);
      });
    }

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
            AnimeXDownloadsPage(controller: _controller),
          ];
          final detailChild = _controller.watchItem != null
              ? AnimeXWatchPage(
                  key: ValueKey(
                    'watch-${_controller.watchItem!.anilistId ?? _controller.watchItem!.tmdbId}',
                  ),
                  controller: _controller,
                )
              : (_controller.playlistId != null
                    ? AnimeXPlaylistDetailPage(controller: _controller)
                    : (_controller.dmcaOpen
                          ? AnimeXDmcaPage(controller: _controller)
                          : null));

          final isWatchingAnime = _controller.watchItem != null;
          if (_lastWatchItem != _controller.watchItem) {
            _lastWatchItem = _controller.watchItem;
            _motchiMessages.clear();
          }

          Widget buildAnimeContent() {
            return Column(
              children: [
                const TvMediaNavHeader(currentRoute: '/anime'),
                AnimeXTopHeader(
                  controller: _controller,
                  onSearch: () => _controller.goTo(AnimexPage.search),
                  onMotchiToggle: isCoupleUser && isWatchingAnime
                      ? _controller.toggleMotchi
                      : null,
                  isMotchiOpen: _controller.motchiOpen,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      LazyIndexedStack(
                        index: _controller.page.index,
                        active: detailChild == null,
                        children: pages,
                      ),
                      if (detailChild != null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: AnimeXTokens.bg,
                            child: detailChild,
                          ),
                        ),
                      // Floating trigger: ONLY when actually watching an anime
                      if (isCoupleUser && isWatchingAnime && !_controller.motchiOpen)
                        Positioned(
                          bottom: 20,
                          right: 18,
                          child: AnimeXMotchiFloatingTrigger(
                            onTap: _controller.openMotchi,
                          ),
                        ),
                      // Motchi Sidebar: ONLY when actually watching an anime
                      if (isCoupleUser && isWatchingAnime)
                        AnimeXMotchiSidebar(
                          isOpen: _controller.motchiOpen,
                          onClose: _controller.closeMotchi,
                          controller: _controller,
                          messages: _motchiMessages,
                          onClear: () => _motchiMessages.clear(),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Scaffold(
            backgroundColor: AnimeXTokens.bg,
            body: SafeArea(bottom: false, child: buildAnimeContent()),
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
      },
    );
  }
}
