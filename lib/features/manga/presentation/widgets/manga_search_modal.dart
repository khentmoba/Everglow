import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_cover_card.dart';
import 'package:everglow/services/auth_service.dart';

/// Search modal for finding manga / manhwa / manhua on MangaDex.
/// Mirrors `TMDBSearchModal` from the cinema feature — same UX, same
/// debounce pattern, but the result list updates per content-type
/// filter and the "Add to Library" dialog uses a wider status set
/// (reading, plan-to-read, completed, on-hold, dropped).
class MangaSearchModal extends StatefulWidget {
  /// Optional pre-selected content type filter. Empty means "All".
  final String initialLanguage;
  const MangaSearchModal({Key? key, this.initialLanguage = ''})
      : super(key: key);

  @override
  State<MangaSearchModal> createState() => _MangaSearchModalState();
}

class _MangaSearchModalState extends State<MangaSearchModal> {
  final MangaDexService _service = MangaDexService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<MangaItem> _results = [];
  bool _isLoading = false;
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage;
  }

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
        setState(() => _results = []);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final results = await _service.searchManga(
      query: query,
      originalLanguage: _selectedLanguage.isEmpty ? null : _selectedLanguage,
    );
    if (mounted) {
      setState(() {
        _results = results;
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

  void _showAddDialog(MangaItem item) {
    String status = 'plan-to-read';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppTheme.velvet,
          title: Text(
            'Add to Library?',
            style: GoogleFonts.cormorantGaramond(
              color: AppTheme.roseQuartz,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.coverUrl.isNotEmpty
                      ? Image.network(item.coverUrl,
                          height: 180, fit: BoxFit.cover)
                      : Container(height: 180, color: AppTheme.twilight),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite,
                      fontWeight: FontWeight.w600),
                ),
                if (item.author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'by ${item.author}',
                    style: GoogleFonts.outfit(
                      color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: const [
                    _StatusValue('reading', 'Reading'),
                    _StatusValue('plan-to-read', 'Plan'),
                    _StatusValue('completed', 'Completed'),
                    _StatusValue('on-hold', 'Hold'),
                    _StatusValue('dropped', 'Dropped'),
                  ].map((entry) {
                    return ChoiceChip(
                      label: Text(entry.label,
                          style: GoogleFonts.outfit(fontSize: 12)),
                      selected: status == entry.value,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => status = entry.value);
                        }
                      },
                      selectedColor: AppTheme.deepRose,
                      backgroundColor: AppTheme.twilight,
                      labelStyle: TextStyle(
                        color: status == entry.value
                            ? AppTheme.petalWhite
                            : AppTheme.roseQuartz.withValues(alpha: 0.6),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
                Navigator.pop(context);
                final u = context.read<AuthService>().currentUser ?? '';
                if (u.isEmpty) return;
                await _service.saveToLibrary(item, status, u);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🌸 ${item.title} added to your library!',
                        style: GoogleFonts.outfit(
                            color: AppTheme.petalWhite),
                      ),
                      backgroundColor: AppTheme.deepRose,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context);
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
      height: MediaQuery.of(context).size.height * 0.85,
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
              color: AppTheme.roseQuartz.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Find Your Next Read 📖',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
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
              hintText: 'Search manga, manhwa, manhua...',
              hintStyle: GoogleFonts.outfit(
                  color: AppTheme.petalWhite.withValues(alpha: 0.4)),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.roseQuartz),
              filled: true,
              fillColor: AppTheme.moonlight
                  .withValues(alpha: AppTheme.glassOpacity),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
            ),
          ),
          const SizedBox(height: 16),

          // Content-type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _LangChip(value: '', label: 'All', icon: Icons.all_inclusive),
                _LangChip(value: 'ja', label: 'Manga', icon: Icons.translate),
                _LangChip(value: 'ko', label: 'Manhwa', icon: Icons.translate),
                _LangChip(value: 'zh', label: 'Manhua', icon: Icons.translate),
              ]
                  .map((chip) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _LangChipWrapper(
                          value: chip.value,
                          label: chip.label,
                          icon: chip.icon,
                          selected: _selectedLanguage == chip.value,
                          onSelected: () =>
                              _onLanguageFilterChanged(chip.value),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Results
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
                          return MangaCoverCard(
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
          Icon(Icons.menu_book_outlined,
              size: 60, color: AppTheme.roseQuartz.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'Start typing to find your next read...'
                : 'No results found.',
            style: GoogleFonts.outfit(
                color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _StatusValue {
  final String value;
  final String label;
  const _StatusValue(this.value, this.label);
}

class _LangChip {
  final String value;
  final String label;
  final IconData icon;
  const _LangChip({required this.value, required this.label, required this.icon});
}

class _LangChipWrapper extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;
  const _LangChipWrapper({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.roseQuartz),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.outfit(fontSize: 12)),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.deepRose,
      backgroundColor: AppTheme.twilight,
      labelStyle: TextStyle(
        color: selected ? AppTheme.petalWhite : AppTheme.roseQuartz,
      ),
      checkmarkColor: AppTheme.petalWhite,
    );
  }
}
