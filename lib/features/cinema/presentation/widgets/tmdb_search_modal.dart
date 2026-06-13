import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/our_cinema_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/services/auth_service.dart';
import 'media_poster_card.dart';

class TMDBSearchModal extends StatefulWidget {
  /// Pre-selects the "Mine" / "Ours" scope in the add dialog. Pass
  /// `'ours'` when opening from the shared "Our Cinema" list so the user
  /// only has to confirm. Defaults to `'mine'`.
  final String initialScope;
  const TMDBSearchModal({Key? key, this.initialScope = 'mine'}) : super(key: key);

  @override
  State<TMDBSearchModal> createState() => _TMDBSearchModalState();
}

class _TMDBSearchModalState extends State<TMDBSearchModal> {
  final TMDBService _tmdbService = TMDBService();
  final OurCinemaService _ourCinemaService = OurCinemaService();
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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

    final results = await _tmdbService.searchMedia(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _showAddDialog(MediaItem item) {
    String status = 'to-watch';
    // 'mine' = personal watchlist, 'ours' = shared Our Cinema list.
    // The 'ours' option is only shown to the couple (khentsgdz, clairjassen).
    String scope = widget.initialScope;
    final userName = context.read<AuthService>().currentUser ?? '';
    final isCouple = OurCinemaService.coupleUsernames.contains(userName);
    // The "Ours" chip can only be pre-selected for couple users; fall back
    // to "Mine" for cinema-only profiles (breyan, octagram).
    if (scope == 'ours' && !isCouple) scope = 'mine';

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
              const SizedBox(height: 16),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: AppTheme.petalWhite, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              // Scope selector: "Mine" vs "Ours" (Ours only for the couple).
              if (isCouple)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.twilight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _scopeChip(
                        context: context,
                        setDialogState: setDialogState,
                        label: 'Mine',
                        icon: Icons.bookmark_rounded,
                        value: 'mine',
                        current: scope,
                        onTap: () => setDialogState(() => scope = 'mine'),
                      ),
                      _scopeChip(
                        context: context,
                        setDialogState: setDialogState,
                        label: 'Ours',
                        icon: Icons.favorite_rounded,
                        value: 'ours',
                        current: scope,
                        onTap: () => setDialogState(() => scope = 'ours'),
                      ),
                    ],
                  ),
                ),
              if (isCouple) const SizedBox(height: 14),
              // Status chips. Only shown for the personal ("Mine") scope —
              // shared items always start as "to watch together".
              if (scope == 'mine')
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
                        color: status == 'to-watch' ? AppTheme.petalWhite : AppTheme.roseQuartz.withOpacity(0.6),
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
                        color: status == 'watched' ? AppTheme.petalWhite : AppTheme.roseQuartz.withOpacity(0.6),
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
                style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withOpacity(0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                final u = context.read<AuthService>().currentUser ?? '';
                if (u.isEmpty) return;
                String? successMessage;
                if (scope == 'ours') {
                  final added = await _ourCinemaService.addToOurCinema(item, u);
                  if (added != null) {
                    successMessage =
                        '💞 ${item.title} added to Our Cinema!';
                  }
                } else {
                  await _tmdbService.saveToWatchList(item, status, u);
                  successMessage = '🌸 ${item.title} added to Everglow!';
                }
                if (mounted && successMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        successMessage,
                        style: GoogleFonts.outfit(color: AppTheme.petalWhite),
                      ),
                      backgroundColor: AppTheme.deepRose,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context); // Close search modal
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.deepRose,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.outfit(color: AppTheme.petalWhite, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeChip({
    required BuildContext context,
    required StateSetter setDialogState,
    required String label,
    required IconData icon,
    required String value,
    required String current,
    required VoidCallback onTap,
  }) {
    final active = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.deepRose.withValues(alpha: 0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? AppTheme.petalWhite
                    : AppTheme.roseQuartz.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: active
                      ? AppTheme.petalWhite
                      : AppTheme.roseQuartz.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
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
          // Handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.roseQuartz.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Find Your Next Cinema Moment 🍿',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
          const SizedBox(height: 20),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            decoration: InputDecoration(
              hintText: 'Search for a movie or show...',
              hintStyle: GoogleFonts.outfit(color: AppTheme.petalWhite.withOpacity(0.4)),
              prefixIcon: const Icon(Icons.search, color: AppTheme.roseQuartz),
              filled: true,
              fillColor: AppTheme.moonlight.withOpacity(AppTheme.glassOpacity),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
          const SizedBox(height: 20),

          // Results Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.roseQuartz))
                : _results.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        itemCount: _results.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
          Icon(Icons.movie_outlined, size: 60, color: AppTheme.roseQuartz.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'Start typing to find magic...' : 'No movies found! 🌸',
            style: GoogleFonts.outfit(color: AppTheme.roseQuartz.withOpacity(0.6), fontSize: 16),
          ),
        ],
      ),
    );
  }
}
