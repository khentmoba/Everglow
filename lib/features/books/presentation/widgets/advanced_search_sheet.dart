import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/services/book_catalog_service.dart';

const _cCard = AppColors.shimmerBase;
const _cRose = AppColors.roseQuartz;
const _cDeepRose = AppColors.deepRose;
const _cAmber = AppColors.warmAmber;
const _cWhite = AppColors.petalWhite;
const _cMuted = AppColors.mutedPurple;

/// Z-Library style advanced search: narrow the catalog by title,
/// author, publisher, ISBN, and year range, with an exact-match
/// toggle. Plain labels so Clair never has to guess what a field
/// does. Returns the chosen [BookSearchFilters] via Navigator.pop.
class AdvancedSearchSheet extends StatefulWidget {
  final BookSearchFilters initial;

  const AdvancedSearchSheet({super.key, required this.initial});

  /// Opens the sheet and returns the picked filters, or null when
  /// the user dismisses it without applying.
  static Future<BookSearchFilters?> open(
    BuildContext context,
    BookSearchFilters initial,
  ) {
    return showModalBottomSheet<BookSearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdvancedSearchSheet(initial: initial),
    );
  }

  @override
  State<AdvancedSearchSheet> createState() => _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends State<AdvancedSearchSheet> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _publisher;
  late final TextEditingController _isbn;
  late final TextEditingController _yearFrom;
  late final TextEditingController _yearTo;
  late bool _exact;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _title = TextEditingController(text: i.title ?? '');
    _author = TextEditingController(text: i.author ?? '');
    _publisher = TextEditingController(text: i.publisher ?? '');
    _isbn = TextEditingController(text: i.isbn ?? '');
    _yearFrom = TextEditingController(text: i.yearFrom?.toString() ?? '');
    _yearTo = TextEditingController(text: i.yearTo?.toString() ?? '');
    _exact = i.exact;
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _publisher.dispose();
    _isbn.dispose();
    _yearFrom.dispose();
    _yearTo.dispose();
    super.dispose();
  }

  int? _parseYear(String raw) {
    final v = int.tryParse(raw.trim());
    if (v == null || v < 1000 || v > 2100) return null;
    return v;
  }

  void _apply() {
    HapticFeedback.selectionClick();
    Navigator.pop(
      context,
      BookSearchFilters(
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        author: _author.text.trim().isEmpty ? null : _author.text.trim(),
        publisher: _publisher.text.trim().isEmpty
            ? null
            : _publisher.text.trim(),
        isbn: _isbn.text.trim().isEmpty ? null : _isbn.text.trim(),
        yearFrom: _parseYear(_yearFrom.text),
        yearTo: _parseYear(_yearTo.text),
        exact: _exact,
      ),
    );
  }

  void _clear() {
    HapticFeedback.selectionClick();
    Navigator.pop(context, BookSearchFilters.none);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottom),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _cRose.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Advanced Search',
                    style: AppTypography.cormorantBlack.copyWith(
                      fontSize: 24,
                      color: _cWhite,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _clear,
                  child: Text(
                    'Clear all',
                    style: AppTypography.outfitBold.copyWith(
                      color: _cMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fill in anything you know — the rest can stay empty.',
              style: AppTypography.outfitWhite.copyWith(
                color: _cMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _Field(controller: _title, label: 'Title', hint: 'e.g. Pride and Prejudice'),
            const SizedBox(height: 10),
            _Field(controller: _author, label: 'Author', hint: 'e.g. Jane Austen'),
            const SizedBox(height: 10),
            _Field(
              controller: _publisher,
              label: 'Publisher',
              hint: 'e.g. Penguin Classics',
            ),
            const SizedBox(height: 10),
            _Field(
              controller: _isbn,
              label: 'ISBN',
              hint: 'e.g. 9780141439518',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _yearFrom,
                    label: 'Year from',
                    hint: 'e.g. 1900',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    controller: _yearTo,
                    label: 'Year to',
                    hint: 'e.g. 1950',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _exact = !_exact);
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _exact
                          ? _cDeepRose
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: _exact
                            ? _cDeepRose
                            : _cRose.withValues(alpha: 0.3),
                      ),
                    ),
                    child: _exact
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 15,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exact match only',
                          style: AppTypography.outfitBold.copyWith(
                            color: _cWhite,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Title or author must match your search word for word.',
                          style: AppTypography.outfitWhite.copyWith(
                            color: _cMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cDeepRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Search with these filters',
                  style: AppTypography.outfitBold.copyWith(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.outfitHeading.copyWith(
            fontSize: 9,
            color: _cMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cRose.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTypography.outfitWhite.copyWith(
              color: _cWhite,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.outfitWhite.copyWith(
                color: _cMuted.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small pill shown under the search box while advanced filters are
/// active. Tapping it re-opens the sheet; the × clears the filters.
class ActiveFiltersPill extends StatelessWidget {
  final BookSearchFilters filters;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  const ActiveFiltersPill({
    super.key,
    required this.filters,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cAmber.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, color: _cAmber, size: 15),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                filters.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitBold.copyWith(
                  color: _cAmber,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                color: _cAmber,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
