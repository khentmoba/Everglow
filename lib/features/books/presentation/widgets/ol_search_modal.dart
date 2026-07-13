import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/open_library_service.dart';
import 'package:everglow/features/books/data/services/our_books_service.dart';
import 'package:everglow/features/books/presentation/widgets/book_cover_card.dart';
import 'package:everglow/services/auth_service.dart';

/// Bottom sheet for searching the Open Library catalog and adding a
/// book to either the personal "Mine" list or the shared "Our Books"
/// couple list. Mirrors `TMDBSearchModal` from the cinema feature.
class OLSearchModal extends StatefulWidget {
  /// Pre-selects the "Mine" / "Ours" scope toggle. Defaults to 'mine'.
  final String initialScope;
  const OLSearchModal({Key? key, this.initialScope = 'mine'})
      : super(key: key);

  @override
  State<OLSearchModal> createState() => _OLSearchModalState();
}

class _OLSearchModalState extends State<OLSearchModal> {
  final OpenLibraryService _service = OpenLibraryService();
  final OurBooksService _ourBooksService = OurBooksService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<BookItem> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _runSearch(query);
      } else {
        setState(() => _results = []);
      }
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _isLoading = true);
    final results = await _service.searchBooks(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  void _showAddDialog(BookItem item) {
    String status = 'to-read';
    String scope = widget.initialScope;
    final userName = context.read<AuthService>().currentUser ?? '';
    final isCouple = OurBooksService.coupleUsernames.contains(userName);
    if (scope == 'ours' && !isCouple) scope = 'mine';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppTheme.velvet,
          title: Text(
            'Add to Everglow?',
            style: GoogleFonts.cormorantGaramond(
              color: AppTheme.roseQuartz,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.coverUrl.isNotEmpty
                      ? Image.network(item.coverUrl,
                          height: 150, fit: BoxFit.cover)
                      : Container(height: 150, color: AppTheme.twilight),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite, fontWeight: FontWeight.w600),
                ),
                if (item.author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.author,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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
                          ctx: ctx,
                          setDialogState: setDialogState,
                          label: 'Mine',
                          icon: Icons.bookmark_rounded,
                          value: 'mine',
                          current: scope,
                          onTap: () => setDialogState(() => scope = 'mine'),
                        ),
                        _scopeChip(
                          ctx: ctx,
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
                if (scope == 'mine')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label:
                            Text('To Read', style: GoogleFonts.outfit()),
                        selected: status == 'to-read',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => status = 'to-read');
                          }
                        },
                        selectedColor: AppTheme.deepRose,
                        backgroundColor: AppTheme.twilight,
                        labelStyle: TextStyle(
                          color: status == 'to-read'
                              ? AppTheme.petalWhite
                              : AppTheme.roseQuartz.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Read', style: GoogleFonts.outfit()),
                        selected: status == 'read',
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => status = 'read');
                          }
                        },
                        selectedColor: AppTheme.deepRose,
                        backgroundColor: AppTheme.twilight,
                        labelStyle: TextStyle(
                          color: status == 'read'
                              ? AppTheme.petalWhite
                              : AppTheme.roseQuartz.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final u = context.read<AuthService>().currentUser ?? '';
                if (u.isEmpty) return;
                String? successMessage;
                if (scope == 'ours') {
                  final added = await _ourBooksService.addToOurBooks(item, u);
                  if (added != null) {
                    successMessage = '💞 ${item.title} added to Our Books!';
                  }
                } else {
                  await _service.saveToReadList(item, status, u);
                  successMessage = '📖 ${item.title} added to Everglow!';
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
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

  Widget _scopeChip({
    required BuildContext ctx,
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
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
      height: MediaQuery.of(context).size.height * 0.85,
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
            'Find Your Next Read 📖',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.roseQuartz,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            style: GoogleFonts.outfit(color: AppTheme.petalWhite),
            decoration: InputDecoration(
              hintText: 'Search title, author, or subject...',
              hintStyle: GoogleFonts.outfit(
                  color: AppTheme.petalWhite.withValues(alpha: 0.65)),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.roseQuartz),
              filled: true,
              fillColor: AppTheme.moonlight.withValues(alpha: 0.12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.roseQuartz))
                : _results.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        itemCount: _results.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemBuilder: (context, index) {
                          return BookCoverCard(
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
            _controller.text.isEmpty
                ? 'Start typing to find a book...'
                : 'No books found! 🌸',
            style: GoogleFonts.outfit(
                color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                fontSize: 16),
          ),
        ],
      ),
    );
  }
}
