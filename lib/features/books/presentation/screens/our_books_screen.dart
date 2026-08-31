import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/book_item.dart';
import '../../data/models/our_books_item.dart';
import '../../data/services/our_books_service.dart';
import '../widgets/ol_search_modal.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';

/// Shared couple list. Mirrors `OurCinemaScreen` from the cinema
/// feature.
class OurBooksScreen extends StatefulWidget {
  const OurBooksScreen({super.key});

  @override
  State<OurBooksScreen> createState() => _OurBooksScreenState();
}

class _OurBooksScreenState extends State<OurBooksScreen> {
  final OurBooksService _service = OurBooksService();

  StreamSubscription<List<OurBooksItem>>? _sub;
  List<OurBooksItem> _items = [];
  bool _isLoading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _service.getCachedOurBooks();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _items = cached;
        _isLoading = false;
      });
    }
    _sub = _service.getOurBooksStream().listen((items) {
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  List<OurBooksItem> get _readList => _items.where((i) => i.isRead).toList();
  List<OurBooksItem> get _toReadList => _items.where((i) => !i.isRead).toList();

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser ?? '';
    if (currentUser != 'khentsgdz' && currentUser != 'clairjassen') {
      return Scaffold(
        backgroundColor: const Color(0xFF09060E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF09060E),
          title: const Text('Our Books'),
        ),
        body: Center(
          child: Text(
            'This space is just for the two of you.',
            style: AppTypography.cormorantRegular.copyWith(fontSize: 18),
          ),
        ),
      );
    }

    final list = _tab == 0 ? _toReadList : _readList;

    return Scaffold(
      backgroundColor: const Color(0xFF09060E),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -100,
              width: 400,
              height: 400,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.deepRose.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              width: 350,
              height: 350,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cinemaBlue.withValues(alpha: 0.05),
                ),
              ),
            ),
            Column(
              children: [
                _buildHeader(currentUser),
                _buildTabBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.deepRose,
                          ),
                        )
                      : list.isEmpty
                      ? _buildEmpty(_tab == 0)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                          physics: const BouncingScrollPhysics(),
                          itemCount: list.length,
                          itemBuilder: (context, i) =>
                              _buildRow(list[i], currentUser),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String currentUser) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.roseQuartz,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'OUR BOOKS',
                style: AppTypography.cormorantBlackWhite.copyWith(
                  fontSize: 24,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: AppTheme.deepRose.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.deepRose,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentUser == 'khentsgdz'
                        ? 'KHENT & CLAIR'
                        : 'CLAIR & KHENT',
                    style: AppTypography.outfitHeading.copyWith(
                      fontSize: 9,
                      color: AppTheme.roseQuartz.withValues(alpha: 0.6),
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.deepRose,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openAddToOurBooks,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.1),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.roseQuartz,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.roseQuartz.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            _buildTabPill(
              label: 'To Read Together',
              count: _toReadList.length,
              active: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
            _buildTabPill(
              label: 'Read',
              count: _readList.length,
              active: _tab == 1,
              onTap: () => setState(() => _tab = 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.deepRose.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.deepRose.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.outfitHeading.copyWith(
                    color: active ? AppTheme.petalWhite : AppTheme.roseQuartz,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.deepRose
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? AppTheme.deepRose
                        : AppTheme.roseQuartz.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.outfitWhite.copyWith(
                    color: active ? AppTheme.petalWhite : AppTheme.roseQuartz,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(OurBooksItem item, String currentUser) {
    final isMine = currentUser == 'khentsgdz';
    return FadeInUp(
      duration: const Duration(milliseconds: 350),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.roseQuartz.withValues(alpha: 0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openReader(item),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 80,
                          height: 120,
                          child: item.coverUrl.isNotEmpty
                              ? Image.network(
                                  item.coverUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 240,
                                  errorBuilder: (_, _, _) =>
                                      _posterPlaceholder(),
                                )
                              : _posterPlaceholder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.outfitWhite.copyWith(
                              color: AppTheme.petalWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                          if (item.author.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'by ${item.author}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.outfitWhite.copyWith(
                                color: AppTheme.roseQuartz.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (item.year.isNotEmpty) ...[
                                Text(
                                  item.year,
                                  style: AppTypography.outfitHeading.copyWith(
                                    color: AppTheme.blushGold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepRose.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.deepRose.withValues(
                                      alpha: 0.4,
                                    ),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  item.readSourceLabel.isNotEmpty
                                      ? item.readSourceLabel.toUpperCase()
                                      : 'BOOK',
                                  style: AppTypography.outfitWhite.copyWith(
                                    color: AppTheme.roseQuartz,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildCoupleBadges(item),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ReadButton(
                                  label: isMine ? 'I Read' : 'Clair Read',
                                  read: isMine
                                      ? item.isReadByKhent
                                      : item.isReadByClair,
                                  color: isMine
                                      ? AppColors.cinemaBlue
                                      : AppColors.cinemaPink,
                                  onTap: () {
                                    _service.setReadFlag(
                                      workKey: item.workKey,
                                      userName: currentUser,
                                      read: !(isMine
                                          ? item.isReadByKhent
                                          : item.isReadByClair),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => _confirmRemove(item),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.roseQuartz.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppTheme.roseQuartz,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoupleBadges(OurBooksItem item) {
    final khentRead = item.isReadByKhent;
    final clairRead = item.isReadByClair;
    if (khentRead && clairRead) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.cinemaBlue, AppColors.cinemaPink],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.cinemaPink.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'Read Together 💞',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        _buildAvatarBadge(
          initial: 'K',
          label: 'Khent',
          read: khentRead,
          color: AppColors.cinemaBlue,
        ),
        const SizedBox(width: 8),
        _buildAvatarBadge(
          initial: 'C',
          label: 'Clair',
          read: clairRead,
          color: AppColors.cinemaPink,
        ),
      ],
    );
  }

  Widget _buildAvatarBadge({
    required String initial,
    required String label,
    required bool read,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: read
            ? color.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: read ? color : AppTheme.roseQuartz.withValues(alpha: 0.3),
          width: read ? 1.5 : 1.0,
        ),
        boxShadow: read
            ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 6)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: read ? color : AppTheme.roseQuartz.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: AppTypography.outfitWhite.copyWith(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.outfitHeading.copyWith(
              color: read
                  ? Colors.white
                  : AppTheme.roseQuartz.withValues(alpha: 0.7),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: AppColors.deepBlack,
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: AppTheme.roseQuartz,
          size: 28,
        ),
      ),
    );
  }

  void _openReader(OurBooksItem item) {
    final book = item.toBookItem();
    // Stale couple-list items may not have a readSourceUrl cached,
    // so always re-derive it from iaId / workKey at navigation
    // time. Reuses the same static helpers as the personal drawer.
    final resolved = book.readSourceUrl.isNotEmpty
        ? book
        : book.copyWith(
            readSourceUrl: BookItem.deriveReadSourceUrl(
              iaId: book.iaId,
              workKey: book.workKey,
            ),
            readSourceLabel: BookItem.deriveReadSourceLabel(iaId: book.iaId),
          );
    context.push('/books/reader', extra: resolved);
  }

  Future<void> _openAddToOurBooks() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OLSearchModal(initialScope: 'ours'),
    );
  }

  Future<void> _confirmRemove(OurBooksItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.shimmerBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Remove from Our Books?',
          style: AppTypography.cormorantBold.copyWith(fontSize: 22),
        ),
        content: Text(
          'This will remove "${item.title}" from the shared list for both of you.',
          style: AppTypography.outfitWhite.copyWith(
            color: AppTheme.petalWhite,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.roseQuartz,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.deepRose,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.removeFromOurBooks(item.workKey);
    }
  }

  Widget _buildEmpty(bool isToReadTab) {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isToReadTab
                  ? Icons.favorite_border_rounded
                  : Icons.menu_book_outlined,
              size: 64,
              color: AppTheme.roseQuartz.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              isToReadTab
                  ? 'No shared picks yet.\nSearch and add one to "Ours".'
                  : 'Nothing read together yet.\nYour first shared book awaits.',
              textAlign: TextAlign.center,
              style: AppTypography.outfitWhite.copyWith(
                color: AppTheme.roseQuartz,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (isToReadTab) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _openAddToOurBooks,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.deepRose.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.deepRose.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.deepRose.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: AppTheme.roseQuartz,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add a book to read together',
                        style: AppTypography.outfitHeading.copyWith(
                          color: AppTheme.petalWhite,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadButton extends StatelessWidget {
  final String label;
  final bool read;
  final Color color;
  final VoidCallback onTap;

  const _ReadButton({
    required this.label,
    required this.read,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: read
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: read
                ? color.withValues(alpha: 0.8)
                : color.withValues(alpha: 0.35),
            width: read ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              read ? Icons.check_circle_rounded : Icons.menu_book_outlined,
              color: read ? Colors.white : color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                read ? '$label ✓' : label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.outfitHeading.copyWith(
                  color: read
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
