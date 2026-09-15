import 'package:flutter/material.dart';
import '../../data/models/katana_models.dart';
import '../katana/katana_header.dart';
import '../katana/katana_tab_shell.dart';
import '../screens/katana_bookmarks_screen.dart';
import '../screens/katana_currently_reading_screen.dart';
import '../screens/katana_detail_screen.dart';
import '../screens/katana_directory_screen.dart';
import '../screens/katana_genres_screen.dart';
import '../screens/katana_reader_screen.dart';
import '../screens/katana_search_results_screen.dart';

/// Pushes a new Manga Katana screen on top of the manga section.
///
/// Tab destinations (home, catalogs, genres) switch in place when the
/// caller is inside [KatanaTabShell], so the header stays put and only
/// the content below it cross-fades. Detail, search, bookmarks, and
/// reader pages are still real pushes — those genuinely are new pages.
void pushHome(BuildContext context) {
  final shell = KatanaTabShell.maybeOf(context);
  if (shell != null) {
    shell.showHome();
    return;
  }
  if (KatanaTabShell.popToShell(context, tab: KatanaNav.home)) return;
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
  final shell = KatanaTabShell.maybeOf(context);
  if (shell != null) {
    shell.showCatalog(mode: mode, slug: key, title: title);
    return;
  }
  if (KatanaTabShell.popToShell(
    context,
    tab: KatanaTabShell.tabForMode(mode),
    mode: mode,
    slug: key,
    title: title,
  )) {
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          KatanaDirectoryScreen(mode: mode, slug: key, title: title),
    ),
  );
}

void pushGenreDirectory(BuildContext context, String slug, String name) {
  final shell = KatanaTabShell.maybeOf(context);
  if (shell != null) {
    shell.showCatalog(mode: 'genre', slug: slug, title: name);
    return;
  }
  if (KatanaTabShell.popToShell(
    context,
    tab: KatanaNav.genres,
    mode: 'genre',
    slug: slug,
    title: name,
  )) {
    return;
  }
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

void pushCurrentlyReading(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
        builder: (_) => const KatanaCurrentlyReadingScreen()),
  );
}

void pushGenres(BuildContext context) {
  final shell = KatanaTabShell.maybeOf(context);
  if (shell != null) {
    shell.showGenres();
    return;
  }
  if (KatanaTabShell.popToShell(context, tab: KatanaNav.genres, mode: '')) {
    return;
  }
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
