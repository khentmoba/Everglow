import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/books/data/models/book_item.dart';
import 'package:everglow/features/books/data/services/open_library_service.dart';
import 'package:everglow/services/auth_service.dart';
import '../screens/reader_screen.dart';

/// Bottom sheet for a single book. Mirrors the cinema's
/// `episode_drawer.dart` — but stripped down to the essentials
/// (cover, metadata, description, status chips, read button).
/// The full chapter list is rendered inside the reader screen.
class BookDetailsDrawer extends StatefulWidget {
  final BookItem item;
  const BookDetailsDrawer({Key? key, required this.item}) : super(key: key);

  @override
  State<BookDetailsDrawer> createState() => _BookDetailsDrawerState();
}

class _BookDetailsDrawerState extends State<BookDetailsDrawer> {
  final OpenLibraryService _service = OpenLibraryService();
  bool _isLoadingDetails = true;
  String _description = '';
  List<String> _subjects = const [];
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.item.status;
    _subjects = widget.item.subjects;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final details = await _service.fetchWorkDetails(widget.item.workKey);
    if (!mounted || details == null) {
      setState(() => _isLoadingDetails = false);
      return;
    }
    final descRaw = details['description'];
    String desc = '';
    if (descRaw is String) {
      desc = descRaw;
    } else if (descRaw is Map && descRaw['value'] is String) {
      desc = descRaw['value'] as String;
    }
    final subjectsRaw = details['subjects'];
    final subjects = subjectsRaw is List
        ? subjectsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    setState(() {
      _description = desc;
      _subjects = subjects.isNotEmpty ? subjects : _subjects;
      _isLoadingDetails = false;
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    HapticFeedback.selectionClick();
    final userName = context.read<AuthService>().currentUser ?? '';
    if (userName.isEmpty) {
      _showSnack('Please sign in to manage your list');
      return;
    }
    if (_currentStatus == newStatus) {
      setState(() => _currentStatus = '');
      await _service.removeFromReadList(widget.item.workKey, userName);
      if (mounted) _showSnack('Removed from your list');
    } else {
      setState(() => _currentStatus = newStatus);
      await _service.saveToReadList(widget.item, newStatus, userName);
      if (mounted) _showSnack('List updated');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: AppTheme.petalWhite)),
        backgroundColor: AppTheme.deepRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openReader() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: widget.item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppTheme.velvet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero()),
            SliverToBoxAdapter(child: _buildMeta()),
            SliverToBoxAdapter(child: _buildStatusSection()),
            SliverToBoxAdapter(child: _buildDescriptionSection()),
            SliverToBoxAdapter(child: _buildSubjectsSection()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: _buildReadButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Stack(
      children: [
        // Cover backdrop
        SizedBox(
          height: 320,
          width: double.infinity,
          child: widget.item.coverUrl.isNotEmpty
              ? Image.network(
                  widget.item.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: AppTheme.twilight),
                )
              : Container(color: AppTheme.twilight),
        ),
        // Cinematic gradient
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.velvet.withValues(alpha: 0.6),
                    AppTheme.velvet,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Drag handle
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // Close button
        Positioned(
          top: 14,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        // Title / author / year overlay
        Positioned(
          left: 20,
          right: 60,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 16,
                    ),
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.item.author.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'by ${widget.item.author}',
                  style: GoogleFonts.outfit(
                    color: AppTheme.roseQuartz.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (widget.item.year.isNotEmpty) ...[
                    Text(
                      widget.item.year,
                      style: GoogleFonts.outfit(
                        color: AppTheme.blushGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _dot(),
                  ],
                  if (widget.item.readSourceLabel.isNotEmpty) ...[
                    const Icon(
                      Icons.menu_book_rounded,
                      color: AppTheme.roseQuartz,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.item.readSourceLabel,
                      style: GoogleFonts.outfit(
                        color: AppTheme.roseQuartz,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: Color(0xFF8A7A92),
            shape: BoxShape.circle,
          ),
        ),
      );

  Widget _buildMeta() {
    if (_isLoadingDetails) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: LinearProgressIndicator(
          color: AppTheme.deepRose,
          backgroundColor: AppTheme.twilight,
          minHeight: 1.5,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatusSection() {
    final isCinemaOnly = context.watch<AuthService>().isCinemaOnlyUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.deepRose,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'READING STATUS',
                style: GoogleFonts.outfit(
                  color: AppTheme.roseQuartz.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusChip('To Read', 'to-read',
                    icon: Icons.bookmark_rounded),
                const SizedBox(width: 8),
                if (isCinemaOnly) ...[
                  _buildStatusChip('Read', 'read-self',
                      icon: Icons.check_circle_rounded,
                      activeColor: const Color(0xFF2E7D32)),
                ] else ...[
                  _buildStatusChip('Khent Read', 'read-khent',
                      icon: Icons.person_rounded,
                      activeColor: const Color(0xFF1976D2)),
                  const SizedBox(width: 8),
                  _buildStatusChip('Clair Read', 'read-clair',
                      icon: Icons.favorite_rounded,
                      activeColor: const Color(0xFFE91E8C)),
                  const SizedBox(width: 8),
                  _buildStatusChip('Both Read', 'read-both',
                      icon: Icons.people_rounded,
                      activeColor: const Color(0xFF2E7D32)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    String status, {
    IconData? icon,
    Color? activeColor,
  }) {
    final active = _currentStatus == status;
    final color = activeColor ?? AppTheme.deepRose;
    return GestureDetector(
      onTap: () => _updateStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.8)
                : color.withValues(alpha: 0.25),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: active ? Colors.white : color, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                color: active
                    ? Colors.white
                    : AppTheme.roseQuartz.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    if (_description.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _description,
            style: GoogleFonts.outfit(
              color: AppTheme.petalWhite.withValues(alpha: 0.78),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsSection() {
    if (_subjects.isEmpty) return const SizedBox.shrink();
    final shown = _subjects.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: shown
            .map((s) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.moonlight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            AppTheme.moonlight.withValues(alpha: 0.25),
                        width: 0.5),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.outfit(
                      color: AppTheme.petalWhite.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildReadButton() {
    final hasSource = widget.item.readSourceUrl.isNotEmpty;
    return GestureDetector(
      onTap: hasSource ? _openReader : null,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: hasSource
              ? const LinearGradient(
                  colors: [AppTheme.deepRose, Color(0xFF8E1444)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: hasSource ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          boxShadow: hasSource
              ? [
                  BoxShadow(
                    color: AppTheme.deepRose.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSource
                    ? Icons.auto_stories_rounded
                    : Icons.lock_outline_rounded,
                color: hasSource
                    ? Colors.white
                    : AppTheme.roseQuartz.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              hasSource ? 'READ BOOK' : 'NO READABLE COPY FOUND',
              style: GoogleFonts.outfit(
                color: hasSource
                    ? Colors.white
                    : AppTheme.roseQuartz.withValues(alpha: 0.6),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
