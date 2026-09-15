import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_typography.dart';
import '../../data/models/katana_models.dart';
import '../../data/services/katana_service.dart';
import './katana_nav.dart';
import './katana_theme.dart';
import '../../../../core/services/auth_service.dart';

enum KatanaNav { home, latest, directory, newManga, genres, reading }

/// The Manga Katana style header: logo, top navigation, a search bar
/// with live suggestions and the signed-in user / bookmarks entry.
class KatanaHeader extends StatefulWidget {
  final KatanaNav active;

  const KatanaHeader({super.key, this.active = KatanaNav.home});

  @override
  State<KatanaHeader> createState() => _KatanaHeaderState();
}

class _KatanaHeaderState extends State<KatanaHeader> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final KatanaService _service = KatanaService();
  Timer? _debounce;
  List<KatanaManga> _suggestions = const [];
  bool _searching = false;
  bool _searched = false;
  String _searchBy = 'm_name';

  /// Which way the pink underline wipes: true grows it from the left
  /// when moving forward through the tabs (Home towards Reading),
  /// false from the right when moving back. Follows the same
  /// direction as the content glide below it.
  bool _wipeFromLeft = true;
  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastTabIndex = KatanaNav.values.indexOf(widget.active);
  }

  @override
  void didUpdateWidget(covariant KatanaHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      final next = KatanaNav.values.indexOf(widget.active);
      _wipeFromLeft = next >= _lastTabIndex;
      _lastTabIndex = next;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searched = false;
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await _service.fetchSuggestions(
        query,
        searchBy: _searchBy,
      );
      if (!mounted || _searchController.text.trim() != query.trim()) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _searched = true;
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _suggestions = const [];
      _searching = false;
      _searched = false;
    });
  }

  void _toggleSearchBy() {
    setState(() {
      _searchBy = _searchBy == 'm_name' ? 'author' : 'm_name';
    });
    // Re-run the current query under the new mode, like the site.
    if (_searchController.text.trim().length >= 3) {
      _onSearchChanged(_searchController.text);
    }
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.length < 3) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _searched = false;
    });
    pushSearchResults(context, query, searchBy: _searchBy);
  }

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser ?? '';
    final showBack = auth.isCoupleUser;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;

    return Container(
      decoration: const BoxDecoration(
        color: KatanaColors.surface,
        border: Border(bottom: BorderSide(color: KatanaColors.border)),
      ),
      // Top-only SafeArea: the surface color stays full-bleed behind the
      // iPhone status bar (Home Screen app and native notch alike) while
      // the back button, search, and chips sit below it and stay tappable.
      child: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            // Top area: on desktop keep back + logo + centered search +
            // bookmarks + user in one row. On phone/tablet the logo row
            // would squeeze the search field down to just the icons
            // (only the Name/Author toggle stayed tappable), so the
            // search gets its own full-width row below the logo.
            if (desktop)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (showBack) ...[
                      Tooltip(
                        message: 'Back to Everglow',
                        child: IconButton(
                          onPressed: _handleBack,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: KatanaColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    _buildLogo(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: _buildSearchField(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 210,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildBookmarksButton(),
                          const SizedBox(width: 8),
                          _buildUserChip(user),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (showBack) ...[
                          Tooltip(
                            message: 'Back to Everglow',
                            child: IconButton(
                              onPressed: _handleBack,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: KatanaColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(child: _buildLogo()),
                        const Spacer(),
                        _buildBookmarksButton(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSearchField(),
                  ],
                ),
              ),
            // Suggestions dropdown (stays visible for empty results so
            // "No matches found." actually shows, like the site).
            if (_searchController.text.trim().length >= 3 &&
                (_searching || _searched))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _buildSuggestions(),
              ),
            // Nav row
            Container(
              width: double.infinity,
              color: KatanaColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _navItem(KatanaNav.home, 'Home', () => pushHome(context)),
                    _navItem(
                      KatanaNav.latest,
                      'Latest update',
                      () => pushDirectory(context, mode: 'latest'),
                    ),
                    _navItem(
                      KatanaNav.directory,
                      'Manga Directory',
                      () => pushDirectory(context),
                    ),
                    _navItem(
                      KatanaNav.newManga,
                      'New Manga',
                      () => pushDirectory(context, mode: 'new'),
                    ),
                    _buildGenresNav(),
                    _navItem(
                      KatanaNav.reading,
                      'Currently Reading',
                      () => pushCurrentlyReading(context),
                    ),
                    if (!desktop) ...[
                      const SizedBox(width: 8),
                      _navItem(null, 'Bookmarks', () => pushBookmarks(context)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final narrow = MediaQuery.sizeOf(context).width < 500;
    final logoSize = narrow ? 30.0 : 34.0;
    final fontSize = narrow ? 19.0 : 22.0;
    return GestureDetector(
      onTap: () => pushHome(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [KatanaColors.accent, KatanaColors.accentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: narrow ? 17 : 19,
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Manga',
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.text,
                    fontSize: fontSize,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: 'Celestia',
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.accent,
                    fontSize: fontSize,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final hasText = _searchController.text.isNotEmpty;
    final canSubmit = _searchController.text.trim().length >= 3;
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 500;
    final desktop = width >= 900;
    return Container(
      height: desktop ? 40 : 44,
      constraints: const BoxConstraints(maxWidth: 620),
      decoration: BoxDecoration(
        color: KatanaColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KatanaColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, size: 19, color: KatanaColors.textLight),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) {
                // Rebuild so the clear/submit buttons enable correctly.
                setState(() {});
                _onSearchChanged(value);
              },
              onSubmitted: (_) => _submitSearch(),
              textInputAction: TextInputAction.search,
              style: AppTypography.outfitWhite.copyWith(
                color: KatanaColors.text,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                hintText: 'Search manga, manhwa, manhua...',
                hintStyle: KatanaType.small,
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                suffixIcon: hasText
                    ? IconButton(
                        onPressed: _clearSearch,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Clear',
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: KatanaColors.textLight,
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ),
          // Search-by dropdown stays visible while typing, like the
          // site's select next to the input.
          GestureDetector(
            onTap: _toggleSearchBy,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: KatanaColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: KatanaColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _searchBy == 'm_name'
                        ? (narrow ? 'Name' : 'Manga Name')
                        : 'Author',
                    style: KatanaType.small,
                  ),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: KatanaColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: canSubmit ? _submitSearch : null,
            visualDensity: VisualDensity.compact,
            tooltip: canSubmit ? 'Search' : 'Type at least 3 letters',
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: canSubmit ? KatanaColors.accent : KatanaColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return KatanaCard(
      radius: BorderRadius.circular(8),
      child: _searching
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KatanaColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Searching...', style: KatanaType.small),
                ],
              ),
            )
          : _suggestions.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No matches found.', style: KatanaType.small),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in _suggestions) _suggestionTile(item),
                const Divider(height: 1, color: KatanaColors.border),
                InkWell(
                  onTap: _submitSearch,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search,
                          size: 15,
                          color: KatanaColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text('View all results', style: KatanaType.accent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _suggestionTile(KatanaManga item) {
    return InkWell(
      onTap: () {
        setState(() {
          _suggestions = const [];
          _searched = false;
        });
        _searchController.clear();
        FocusScope.of(context).unfocus();
        pushDetail(context, item.slug);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 38,
                height: 50,
                child: item.coverUrl.isEmpty
                    ? Container(color: KatanaColors.border)
                    : KatanaNetworkImage(
                        item.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: KatanaColors.border),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.outfitBold.copyWith(
                      color: KatanaColors.text,
                      fontSize: 13,
                    ),
                  ),
                  if (item.latestChapter != null)
                    Text(
                      'Latest chapter: ${item.latestChapter!.displayTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KatanaType.small,
                    ),
                  if (item.authors.isNotEmpty)
                    Text(
                      'Author(s): ${item.authors.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KatanaType.small.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarksButton() {
    return GestureDetector(
      onTap: () => pushBookmarks(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bookmark_rounded,
            size: 18,
            color: KatanaColors.accent,
          ),
          const SizedBox(width: 4),
          Text('Bookmarks', style: KatanaType.accent),
        ],
      ),
    );
  }

  Widget _buildUserChip(String user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KatanaColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KatanaColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_rounded,
            size: 16,
            color: KatanaColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            user.isEmpty ? 'Guest' : user,
            style: AppTypography.outfitBold.copyWith(
              color: KatanaColors.text,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(KatanaNav? nav, String label, VoidCallback onTap) {
    final active = nav != null && nav == widget.active;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 6),
        // Stack (not Column): the label sizes the item and the
        // underline stretches to the label width. A Column would
        // hand the bar unbounded width and it would collapse.
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 7.5),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: AppTypography.outfitBold.copyWith(
                  color: active ? KatanaColors.accent : KatanaColors.text,
                  fontSize: 13.5,
                ),
                child: Text(label),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _GlideUnderline(
                active: active,
                fromLeft: _wipeFromLeft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenresNav() {
    return _GenresDropdown(child: _navItem(KatanaNav.genres, 'Genres', () {}));
  }
}

/// The pink bar under the active nav tab. It wipes in from the side
/// being travelled from and wipes back out, instead of snapping.
class _GlideUnderline extends StatelessWidget {
  final bool active;
  final bool fromLeft;

  const _GlideUnderline({required this.active, required this.fromLeft});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: active ? 1 : 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) {
        final v = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.scale(
            scaleX: v,
            alignment: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                color: KatanaColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GenresDropdown extends StatefulWidget {
  final Widget child;
  const _GenresDropdown({required this.child});

  @override
  State<_GenresDropdown> createState() => _GenresDropdownState();
}

class _GenresDropdownState extends State<_GenresDropdown> {
  bool _open = false;
  List<KatanaGenre> _genres = const [];
  bool _loading = false;

  Future<void> _ensureGenres() async {
    if (_genres.isNotEmpty || _loading) return;
    setState(() => _loading = true);
    final genres = await KatanaService().fetchGenres();
    if (mounted) {
      setState(() {
        _genres = genres;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) async {
        await _ensureGenres();
        if (mounted) setState(() => _open = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _open = false);
      },
      child: GestureDetector(
        onTap: () {
          if (_open) {
            setState(() => _open = false);
          } else {
            _ensureGenres();
            setState(() => _open = true);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.child,
            if (_open)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 320,
                constraints: const BoxConstraints(maxHeight: 420),
                decoration: BoxDecoration(
                  color: KatanaColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: KatanaColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: KatanaColors.accent,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: [
                          for (final genre in _genres)
                            InkWell(
                              onTap: () {
                                setState(() => _open = false);
                                pushGenreDirectory(
                                  context,
                                  genre.slug,
                                  genre.name,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        genre.name,
                                        style: AppTypography.outfitWhite
                                            .copyWith(
                                              color: KatanaColors.text,
                                              fontSize: 13,
                                            ),
                                      ),
                                    ),
                                    if (genre.count > 0)
                                      Text(
                                        '(${genre.count})',
                                        style: KatanaType.small,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
