import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_typography.dart';
import 'package:everglow/features/manga/data/models/katana_models.dart';
import 'package:everglow/features/manga/data/services/katana_service.dart';
import 'package:everglow/features/manga/presentation/katana/katana_nav.dart';
import 'package:everglow/features/manga/presentation/katana/katana_theme.dart';
import 'package:everglow/services/auth_service.dart';

enum KatanaNav { home, latest, directory, newManga, genres }

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
  String _searchBy = 'm_name';

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
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final results = await _service.fetchSuggestions(query, searchBy: _searchBy);
      if (!mounted || _searchController.text.trim() != query.trim()) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.length < 3) return;
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = const []);
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
      color: KatanaColors.surface,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KatanaColors.border)),
      ),
      child: Column(
        children: [
          // Top row: back (couple users) + logo + centered search +
          // bookmarks + user. Left and right clusters mirror each
          // other so the search stays visually centered.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (showBack) ...[
                  Tooltip(
                    message: 'Back to Everglow',
                    child: IconButton(
                      onPressed: _handleBack,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: KatanaColors.textMuted),
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
                if (desktop) ...[
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
                ] else if (showBack) ...[
                  // Mirror the back button's width on mobile so the
                  // search field stays centered.
                  const SizedBox(width: 54),
                ] else ...[
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          // Suggestions dropdown
          if (_suggestions.isNotEmpty || _searching)
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
                  _navItem(KatanaNav.latest, 'Latest update',
                      () => pushDirectory(context, mode: 'latest')),
                  _navItem(KatanaNav.directory, 'Manga Directory',
                      () => pushDirectory(context)),
                  _navItem(KatanaNav.newManga, 'New Manga',
                      () => pushDirectory(context, mode: 'new')),
                  _buildGenresNav(),
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
    );
  }

  Widget _buildLogo() {
    return GestureDetector(
      onTap: () => pushHome(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [KatanaColors.accent, KatanaColors.accentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Manga',
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.text,
                    fontSize: 22,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: 'Celestia',
                  style: AppTypography.outfitBold.copyWith(
                    color: KatanaColors.accent,
                    fontSize: 22,
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
    return Container(
      height: 40,
      constraints: const BoxConstraints(maxWidth: 560),
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
              onChanged: _onSearchChanged,
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
              ),
            ),
          ),
          _searchController.text.isEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchBy =
                        _searchBy == 'm_name' ? 'author' : 'm_name';
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: KatanaColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KatanaColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _searchBy == 'm_name' ? 'Manga Name' : 'Author',
                          style: KatanaType.small,
                        ),
                        const Icon(Icons.arrow_drop_down_rounded,
                            size: 16, color: KatanaColors.textMuted),
                      ],
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _submitSearch,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_forward_rounded,
                      size: 17, color: KatanaColors.accent),
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
                        strokeWidth: 2, color: KatanaColors.accent),
                  ),
                  SizedBox(width: 12),
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
                            const Icon(Icons.search,
                                size: 15, color: KatanaColors.accent),
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
        _suggestions = const [];
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
          const Icon(Icons.bookmark_rounded,
              size: 18, color: KatanaColors.accent),
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
          const Icon(Icons.person_rounded, size: 16, color: KatanaColors.textMuted),
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? KatanaColors.accent : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.outfitBold.copyWith(
            color: active ? KatanaColors.accent : KatanaColors.text,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGenresNav() {
    return _GenresDropdown(
      child: _navItem(KatanaNav.genres, 'Genres', () {}),
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
                                strokeWidth: 2, color: KatanaColors.accent),
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
                                pushGenreDirectory(context, genre.slug,
                                    genre.name);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        genre.name,
                                        style: AppTypography.outfitWhite.copyWith(
                                          color: KatanaColors.text,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (genre.count > 0)
                                      Text('(${genre.count})',
                                          style: KatanaType.small),
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
