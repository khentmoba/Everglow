import 'package:flutter/material.dart';

import '../screens/katana_currently_reading_screen.dart';
import '../screens/katana_directory_screen.dart';
import '../screens/katana_genres_screen.dart';
import '../screens/katana_home_screen.dart';
import './katana_header.dart';
import './katana_theme.dart';

/// Persistent tab shell for MangaCelestia.
///
/// The [KatanaHeader] (logo, search, nav tabs) stays mounted while only
/// the content below it cross-fades between tabs. Tapping Home, Latest
/// update, Manga Directory, New Manga, Genres, or Currently Reading
///
/// Detail, search, bookmarks, and reader pages are still pushed as real
/// routes on top — those genuinely are new pages.
class KatanaTabShell extends StatefulWidget {
  final KatanaNav initialTab;
  final String initialMode;
  final String initialSlug;
  final String initialTitle;

  const KatanaTabShell({
    super.key,
    this.initialTab = KatanaNav.home,
    this.initialMode = 'directory',
    this.initialSlug = '',
    this.initialTitle = '',
  });

  /// Nearest shell above [context], or null when the caller lives on a
  /// pushed page (detail, search, bookmarks) instead of inside a shell.
  static KatanaTabShellState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<KatanaTabShellState>();
  }

  /// Which tab a catalog mode belongs to.
  static KatanaNav tabForMode(String mode) {
    switch (mode) {
      case 'latest':
        return KatanaNav.latest;
      case 'new':
        return KatanaNav.newManga;
      case 'genre':
      case 'author':
        return KatanaNav.genres;
      default:
        return KatanaNav.directory;
    }
  }

  /// Live shells, oldest first. Lets tab taps on pages pushed above the
  /// shell (detail, search, bookmarks) pop back to the shell and switch
  /// tabs instead of stacking another page on top.
  static final List<KatanaTabShellState> _live = [];

  /// Pops back to the nearest shell and switches its tab on the next
  /// frame. Returns true when a shell was found.
  static bool popToShell(
    BuildContext context, {
    required KatanaNav tab,
    String mode = 'directory',
    String slug = '',
    String title = '',
  }) {
    final shell = _live.isNotEmpty ? _live.last : null;
    if (shell == null || !shell.mounted) return false;
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == '/manga' || route.isFirst);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shell.mounted) {
        shell.showTab(tab, mode: mode, slug: slug, title: title);
      }
    });
    return true;
  }

  @override
  State<KatanaTabShell> createState() => KatanaTabShellState();
}

class KatanaTabShellState extends State<KatanaTabShell> {
  late KatanaNav _tab;
  late String _mode;
  late String _slug;
  late String _title;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _mode = widget.initialMode;
    _slug = widget.initialSlug;
    _title = widget.initialTitle;
    KatanaTabShell._live.add(this);
  }

  @override
  void dispose() {
    KatanaTabShell._live.remove(this);
    super.dispose();
  }

  /// Unique per visible content so the switcher animates on every change.
  String get _tabKey => '${_tab.name}|$_mode|$_slug|$_title';

  void showHome() => _show(KatanaNav.home, '', '', '');

  void showCatalog({
    String mode = 'directory',
    String slug = '',
    String title = '',
  }) {
    _show(KatanaTabShell.tabForMode(mode), mode, slug, title);
  }

  void showGenres() => _show(KatanaNav.genres, '', '', '');

  void showReading() => _show(KatanaNav.reading, '', '', '');

  void showTab(
    KatanaNav tab, {
    String mode = 'directory',
    String slug = '',
    String title = '',
  }) {
    switch (tab) {
      case KatanaNav.home:
        return showHome();
      case KatanaNav.latest:
        return showCatalog(mode: 'latest');
      case KatanaNav.directory:
        return showCatalog();
      case KatanaNav.newManga:
        return showCatalog(mode: 'new');
      case KatanaNav.genres:
        if (mode.isEmpty) return showGenres();
        return showCatalog(mode: mode, slug: slug, title: title);
      case KatanaNav.reading:
        return showReading();
    }
  }

  void _show(KatanaNav tab, String mode, String slug, String title) {
    if (_tab == tab && _mode == mode && _slug == slug && _title == title) {
      return;
    }
    setState(() {
      _tab = tab;
      _mode = mode;
      _slug = slug;
      _title = title;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KatanaColors.background,
      body: Column(
        children: [
          KatanaHeader(active: _tab),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: _fadeSlide,
              child: KeyedSubtree(
                key: ValueKey<String>(_tabKey),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same-window feel: content fades with a barely-there rise while the
  /// header above it does not move at all.
  Widget _fadeSlide(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case KatanaNav.home:
        return const KatanaHomeScreen(embed: true);
      case KatanaNav.latest:
        return const KatanaDirectoryScreen(embed: true, mode: 'latest');
      case KatanaNav.directory:
        return const KatanaDirectoryScreen(embed: true);
      case KatanaNav.newManga:
        return const KatanaDirectoryScreen(embed: true, mode: 'new');
      case KatanaNav.genres:
        if (_mode == 'genre' || _mode == 'author') {
          // Keyed by catalog so switching genres resets the list state.
          return KatanaDirectoryScreen(
            key: ValueKey('catalog|$_mode|$_slug|$_title'),
            embed: true,
            mode: _mode,
            slug: _slug,
            title: _title,
          );
        }
        return const KatanaGenresScreen(embed: true);
      case KatanaNav.reading:
        return const KatanaCurrentlyReadingScreen(embed: true);
    }
  }
}
