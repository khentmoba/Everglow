import 'package:flutter/material.dart';
import '../../data/models/katana_models.dart';
import '../screens/katana_bookmarks_screen.dart';
import '../screens/katana_detail_screen.dart';
import '../screens/katana_directory_screen.dart';
import '../screens/katana_genres_screen.dart';
import '../screens/katana_reader_screen.dart';
import '../screens/katana_search_results_screen.dart';

/// Pushes a new Manga Katana screen on top of the manga section.
void pushHome(BuildContext context) {
  Navigator.of(
    context,
  ).popUntil((route) => route.settings.name == '/manga' || route.isFirst);
}

void pushDirectory(
  BuildContext context, {
  String mode = 'directory',
  String key = '',
  String title = '',
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          KatanaDirectoryScreen(mode: mode, slug: key, title: title),
    ),
  );
}

void pushGenreDirectory(BuildContext context, String slug, String name) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          KatanaDirectoryScreen(mode: 'genre', slug: slug, title: name),
    ),
  );
}

void pushDetail(BuildContext context, String slug, {KatanaManga? preview}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => KatanaDetailScreen(slug: slug, preview: preview),
    ),
  );
}

void pushReader(
  BuildContext context, {
  required String slug,
  required String chapterId,
  required List<KatanaChapter> chapters,
  required String mangaTitle,
  required String coverUrl,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => KatanaReaderScreen(
        slug: slug,
        chapterId: chapterId,
        chapters: chapters,
        mangaTitle: mangaTitle,
        coverUrl: coverUrl,
      ),
    ),
  );
}

void pushBookmarks(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const KatanaBookmarksScreen()));
}

void pushGenres(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const KatanaGenresScreen()));
}

void pushSearchResults(
  BuildContext context,
  String query, {
  String searchBy = 'm_name',
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          KatanaSearchResultsScreen(query: query, searchBy: searchBy),
    ),
  );
}
