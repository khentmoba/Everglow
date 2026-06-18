import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/anilist_service.dart';
import 'package:everglow/features/cinema/data/services/jikan_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/services/auth_service.dart';
import 'media_poster_card.dart';

/// Anime-only search modal. Backed by [JikanService] (REST, MAL-sourced)
/// so the results include titles that TMDB doesn't catalogue well —
/// seasonal, isekai, slice-of-life, and older shows. The save flow
/// still goes through [TMDBService.saveToWatchList] so the rest of the
/// app (dashboard, couple merge, watchlist) keeps treating the row as
/// a single `MediaItem`.
class JikanSearchModal extends StatefulWidget {
  const JikanSearchModal({Key? key}) : super(key: key);

  @override
  State<JikanSearchModal> createState() => _JikanSearchModalState();
}

class _JikanSearchModalState extends State<JikanSearchModal> {
  final JikanService _jikanService = JikanService();
  final AniListService _aniListService = AniListService();
  final TMDBService _tmdbService = TMDBService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Slightly longer debounce than TMDB's modal because Jikan is more
    // rate-limited and a 500ms gap is friendlier to the public instance.
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    var results = await _jikanService.searchAnime(query);

    // Jikan often returns 504 (MAL gateway timeout). Fallback to AniList.
    if (results.isEmpty) {
      results = await _aniListService.searchAnime(query);
    }

    // If both Jikan and AniList fail, fall back to TMDB anime discover
    // with a text search filter.
    if (results.isEmpty) {
      results = await _tmdbService.searchMedia(query);
    }

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _showAddDialog(MediaItem item) {
    String status = 'to-watch';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppTheme.velvet,
          title: Text(
            'Add to Everglow?',
            style: GoogleFonts.cormorantGaramond(
              color: AppTheme.roseQuartz,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: item.posterPath.isNotEmpty
                    ? Image.network(item.posterPath, height: 150, fit: BoxFit.cover)
                    : Container(height: 150, color: AppTheme.twilight),
              ),
              const SizedBox(height: 12),
              if (item.studio.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.studio,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.deepRose,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    color: AppTheme.petalWhite, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text('To Watch', style: GoogleFonts.outfit()),
                    selected: status == 'to-watch',
                    onSelected: (selected) {
                      if (selected) setDialogState(() => status = 'to-watch');
                    },
                    selectedColor: AppTheme.deepRose,
                    backgroundColor: AppTheme.twilight,
                    labelStyle: TextStyle(
                      color: status == 'to-watch'
                          ? AppTheme.petalWhite
                          : AppTheme.roseQuartz.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Watched', style: GoogleFonts.outfit()),
                    selected: status == 'watched',
                    onSelected: (selected) {
                      if (selected) setDialogState(() => status = 'watched');
                    },
                    selectedColor: AppTheme.deepRose,
                    backgroundColor: AppTheme.twilight,
                    labelStyle: TextStyle(
                      color: status == 'watched'
                          ? AppTheme.petalWhite
                          : AppTheme.roseQuartz.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                final u = context.read<AuthService>().currentUser ?? '';
                if (u.isEmpty) return;
                await _tmdbService.saveToWatchList(item, status, u);
                final successMessage = '🌸 ${item.title} added to Everglow!';
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        successMessage,
                        style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                      ),
                      backgroundColor: AppTheme.deepRose,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context); // Close search modal
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepRose,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.outfit(
                    color: AppTheme.petalWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.roseQuartz.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Find Your Next Anime 🌸',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            decoration: InputDecoration(
              hintText: 'Search anime titles, studios, anything…',
              hintStyle:
                  GoogleFonts.outfit(color: AppTheme.petalWhite.withValues(alpha: 0.4)),
              prefixIcon: const Icon(Icons.search, color: AppTheme.roseQuartz),
              filled: true,
              fillColor: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.roseQuartz))
                : _results.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        itemCount: _results.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemBuilder: (context, index) {
                          return MediaPosterCard(
                            item: _results[index],
                            onTap: () => _showAddDialog(_results[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeIn(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.animation_rounded,
              size: 60, color: AppTheme.roseQuartz.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'Start typing to find magic…'
                : 'No anime found! 🌸',
            style: GoogleFonts.outfit(
                color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                fontSize: 16),
          ),
        ],
      ),
    );
  }
}
