import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';import 'package:everglow/core/theme/app_colors.dart';
import 'package:everglow/core/theme/app_radius.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/comick_service.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_cover_card.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_details_drawer.dart';
import 'package:everglow/core/theme/app_typography.dart';

// Search screen uses the anime palette from AppColors
const _cBlack = AppColors.animeBackground;
const _cCard = AppColors.animeCard;
const _cRose = AppColors.animeRose;
const _cDeepRose = AppColors.animeDeepRose;
const _cMuted = AppColors.animeMuted;
const _cWhite = AppColors.animeWhite;

/// Full-screen search page for finding manga / manhwa / manhua.
/// Tap a result to open the chapter details drawer.
class MangaSearchScreen extends StatefulWidget {
  final String initialLanguage;
  const MangaSearchScreen({super.key, this.initialLanguage = ''});

  @override
  State<MangaSearchScreen> createState() => _MangaSearchScreenState();
}

class _MangaSearchScreenState extends State<MangaSearchScreen> {
  final MangaDexService _mangaDex = MangaDexService();
  final ComickService _comick = ComickService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<MangaItem> _results = [];
  bool _isLoading = false;
  late String _selectedLanguage;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    final country = _selectedLanguage.isEmpty ? null : _selectedLanguage;

    final results = await Future.wait([
      _mangaDex.search(query: query, originalLanguage: country),
      _comick.search(query: query, country: country),
    ]).timeout(const Duration(seconds: 10), onTimeout: () => [
          <MangaItem>[],
          <MangaItem>[],
        ]);

    final mangaDexResults = results[0];
    final comickResults = results[1];

    // Merge: start with MangaDex results, enrich with Comick hid/slug
    final merged = <String, MangaItem>{};
    final comickByTitle = <String, MangaItem>{};
    for (final item in mangaDexResults) {
      merged[item.title.toLowerCase()] = item;
    }
    for (final comickItem in comickResults) {
      comickByTitle[comickItem.title.toLowerCase()] = comickItem;
    }
    for (final entry in comickByTitle.entries) {
      final key = entry.key;
      final comickItem = entry.value;
      MangaItem? existing = merged[key];
      if (existing == null) {
        for (final mdEntry in merged.entries) {
          final mdItem = mdEntry.value;
          if (mdItem.altTitles.any((alt) =>
              alt.toLowerCase() == key ||
              key.contains(alt.toLowerCase()) ||
              alt.toLowerCase().contains(key))) {
            existing = mdItem;
            break;
          }
        }
      }
      if (existing != null) {
        merged[existing.title.toLowerCase()] = existing.copyWith(
          comickId: comickItem.comickId,
          comickSlug: comickItem.comickSlug,
        );
      } else {
        merged[key] = comickItem;
      }
    }

    if (mounted) {
      setState(() {
        _results = merged.values.toList();
        _isLoading = false;
      });
    }
  }

  void _onLanguageFilterChanged(String lang) {
    setState(() {
      _selectedLanguage = lang;
    });
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _openDetails(MangaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MangaDetailsDrawer(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and search field
            _buildHeader(),
            // Content-type filter chips
            _buildFilterChips(),
            // Results
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _cRose, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _cCard,
                borderRadius: AppRadius.radiusFull,
                border: Border.all(
                  color: _cRose.withValues(alpha: 0.12),
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                style: AppTypography.outfitWhite.copyWith(color: _cWhite, fontSize: 14),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search manga, manhwa, manhua...',
                  hintStyle: AppTypography.outfitWhite.copyWith(color: _cMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: _cMuted, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _results = [];
                              _hasSearched = false;
                            });
                          },
                          icon: const Icon(Icons.close,
                              color: _cMuted, size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildLangChip('All', '', Icons.all_inclusive),
            const SizedBox(width: 8),
            _buildLangChip('Manga', 'jp', Icons.translate),
            const SizedBox(width: 8),
            _buildLangChip('Manhwa', 'ko', Icons.translate),
            const SizedBox(width: 8),
            _buildLangChip('Manhua', 'cn', Icons.translate),
          ],
        ),
      ),
    );
  }

  Widget _buildLangChip(String label, String value, IconData icon) {
    final selected = _selectedLanguage == value;
    return GestureDetector(
      onTap: () => _onLanguageFilterChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? _cDeepRose.withValues(alpha: 0.2)
              : _cCard,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(
            color: selected
                ? _cDeepRose
                : _cRose.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? _cWhite : _cMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.outfitHeading.copyWith(fontSize: 12, color: selected ? _cWhite : _cRose),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _cDeepRose),
      );
    }
    if (!_hasSearched) {
      return _buildEmptyState();
    }
    if (_results.isEmpty) {
      return _buildNoResults();
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _results.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridColumns(context),
          childAspectRatio: 0.65,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          return MangaCoverCard(
            item: _results[index],
            onTap: () => _openDetails(_results[index]),
          );
        },
      ),
    );
  }

  int _gridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 600) return 4;
    if (width > 400) return 3;
    return 2;
  }

  Widget _buildEmptyState() {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 64, color: _cRose.withValues(alpha: 0.15)),
            const SizedBox(height: 20),
            Text(
              'Find Your Next Read',
              style: AppTypography.cormorantBold.copyWith(fontSize: 24, color: _cRose),
            ),
            const SizedBox(height: 8),
            Text(
              'Search by title to discover manga,\nmanhwa, and manhua',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(color: _cMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56, color: _cRose.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: AppTypography.outfitBold.copyWith(color: _cRose, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search term or filter',
              style: AppTypography.outfitWhite.copyWith(color: _cMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
