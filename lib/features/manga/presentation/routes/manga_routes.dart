import 'package:go_router/go_router.dart';
import '../../../../core/router/route_helpers.dart';

import '../../data/models/manga_item.dart';
import '../screens/katana_home_screen.dart';
import '../screens/manga_reader_screen.dart';

/// Routes owned by the manga feature.
final List<GoRoute> mangaRoutes = [
  GoRoute(
    path: '/manga',
    builder: (_, _) => const KatanaHomeScreen(),
    routes: [
      GoRoute(
        path: 'reader',
        builder: (_, state) {
          final args = extraOf<MangaReaderArgs>(state);
          if (args == null) return missingExtraPage(state);
          return MangaReaderScreen(
            manga: args.manga,
            chapter: args.chapter,
            allChapters: args.allChapters,
          );
        },
      ),
    ],
  ),
];

/// Args for [MangaReaderScreen] (complex object, can't be URL params).
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
