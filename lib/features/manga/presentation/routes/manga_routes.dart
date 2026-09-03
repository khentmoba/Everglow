import "package:go_router/go_router.dart";
import "../../../../core/router/deferred_route.dart";
import "../../../../core/router/route_helpers.dart";

import "../../data/models/manga_item.dart";
import "../screens/katana_home_screen.dart";
// The reader (35KB+ of paging/zoom/chapter logic) splits out of the initial
// bundle via a deferred import (see docs/PERF_NOTES.md). Direct pushes from
// [MangaDetailsDrawer] use the same chunk via their own deferred import.
import "../screens/manga_reader_screen.dart" deferred as reader_lib;

/// Routes owned by the manga feature.
final List<GoRoute> mangaRoutes = [
  GoRoute(
    path: "/manga",
    builder: (_, _) => const KatanaHomeScreen(),
    routes: [
      GoRoute(
        path: "reader",
        builder: (_, state) {
          final args = extraOf<MangaReaderArgs>(state);
          if (args == null) return missingExtraPage(state);
          return DeferredRouteLoader(
            label: "Manga Reader",
            loadLibrary: reader_lib.loadLibrary,
            builder: () => reader_lib.MangaReaderScreen(
              manga: args.manga,
              chapter: args.chapter,
              allChapters: args.allChapters,
            ),
          );
        },
      ),
    ],
  ),
];

/// Args for [MangaReaderScreen] (complex object, can'"'"'t be URL params).
class MangaReaderArgs {
  final MangaItem manga;
  final MangaChapter chapter;
  final List<MangaChapter> allChapters;

  MangaReaderArgs({
    required this.manga,
    required this.chapter,
    required this.allChapters,
  });
}