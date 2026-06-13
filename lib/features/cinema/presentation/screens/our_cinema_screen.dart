import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/cinema/data/models/our_cinema_item.dart';
import 'package:everglow/features/cinema/data/services/our_cinema_service.dart';
import 'package:everglow/services/auth_service.dart';

const _cBlack = Color(0xFF080810);
const _cVelvet = Color(0xFF12091A);
const _cCard = Color(0xFF1C1228);
const _cRose = Color(0xFFF4C2C2);
const _cDeepRose = Color(0xFFC2185B);
const _cGold = Color(0xFFE8C97A);
const _cWhite = Color(0xFFFFF5F5);
const _cMuted = Color(0xFF8A7A92);
const _cKhent = Color(0xFF1976D2);
const _cClair = Color(0xFFE91E8C);

/// Shared watchlist for the couple. Visible to khentsgdz and clairjassen only.
class OurCinemaScreen extends StatefulWidget {
  const OurCinemaScreen({super.key});

  @override
  State<OurCinemaScreen> createState() => _OurCinemaScreenState();
}

class _OurCinemaScreenState extends State<OurCinemaScreen> {
  final OurCinemaService _service = OurCinemaService();

  StreamSubscription<List<OurCinemaItem>>? _sub;
  List<OurCinemaItem> _items = [];
  bool _isLoading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final cached = await _service.getCachedOurCinema();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _items = cached;
        _isLoading = false;
      });
    }
    _sub = _service.getOurCinemaStream().listen((items) {
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

  List<OurCinemaItem> get _watchedList =>
      _items.where((i) => i.isWatched).toList();
  List<OurCinemaItem> get _toWatchList =>
      _items.where((i) => !i.isWatched).toList();

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthService>().currentUser ?? '';
    if (currentUser != 'khentsgdz' && currentUser != 'clairjassen') {
      return Scaffold(
        backgroundColor: _cBlack,
        appBar: AppBar(
          backgroundColor: _cBlack,
          title: const Text('Our Cinema'),
        ),
        body: Center(
          child: Text(
            'This space is just for the two of you.',
            style: GoogleFonts.cormorantGaramond(
              color: _cRose,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    final list = _tab == 0 ? _toWatchList : _watchedList;

    return Scaffold(
      backgroundColor: _cBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(currentUser),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _cDeepRose),
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
      ),
    );
  }

  Widget _buildHeader(String currentUser) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          _CinemaIconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'OUR CINEMA',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _cWhite,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentUser == 'khentsgdz'
                    ? 'KHENT & CLAIR'
                    : 'CLAIR & KHENT',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: _cMuted,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 40, height: 40),
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
          color: _cCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cRose.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            _buildTabPill(
              label: 'To Watch Together',
              count: _toWatchList.length,
              active: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
            _buildTabPill(
              label: 'Watched',
              count: _watchedList.length,
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
                ? _cDeepRose.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: active ? _cWhite : _cMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? _cDeepRose : _cCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active
                        ? _cDeepRose
                        : _cRose.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    color: active ? _cWhite : _cMuted,
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

  Widget _buildRow(OurCinemaItem item, String currentUser) {
    final isMine = currentUser == 'khentsgdz';
    return FadeInUp(
      duration: const Duration(milliseconds: 350),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cRose.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 108,
                child: item.posterPath.isNotEmpty
                    ? Image.network(
                        item.posterPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _posterPlaceholder(),
                      )
                    : _posterPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: _cWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.year.isNotEmpty)
                        Text(
                          item.year,
                          style: GoogleFonts.outfit(
                            color: _cGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (item.year.isNotEmpty) const SizedBox(width: 8),
                      Text(
                        item.mediaType.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: _cRose.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatusBadges(item: item),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _WatchedButton(
                          label: isMine ? 'I Watched' : 'Clair Watched',
                          watched: isMine
                              ? item.isWatchedByKhent
                              : item.isWatchedByClair,
                          color: isMine ? _cKhent : _cClair,
                          onTap: () => _service.setWatchedFlag(
                            tmdbId: item.tmdbId,
                            userName: currentUser,
                            watched: !(isMine
                                ? item.isWatchedByKhent
                                : item.isWatchedByClair),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _IconAction(
                        icon: Icons.delete_outline_rounded,
                        onTap: () => _confirmRemove(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: _cVelvet,
      child: const Center(
        child: Icon(Icons.movie_creation_outlined,
            color: _cRose, size: 28),
      ),
    );
  }

  Future<void> _confirmRemove(OurCinemaItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove from Our Cinema?',
          style: GoogleFonts.cormorantGaramond(
            color: _cRose,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will remove "${item.title}" from the shared list for both of you.',
          style: GoogleFonts.outfit(color: _cWhite, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: _cMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: GoogleFonts.outfit(
                color: _cDeepRose,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.removeFromOurCinema(item.tmdbId);
    }
  }

  Widget _buildEmpty(bool isToWatchTab) {
    return FadeIn(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isToWatchTab
                  ? Icons.favorite_border_rounded
                  : Icons.movie_filter_outlined,
              size: 64,
              color: _cRose.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              isToWatchTab
                  ? 'No shared picks yet.\nSearch and add one to "Ours".'
                  : 'Nothing watched together yet.\nYour first shared movie awaits.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: _cMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadges extends StatelessWidget {
  final OurCinemaItem item;
  const _StatusBadges({required this.item});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Pill(
          label: 'Khent',
          watched: item.isWatchedByKhent,
          color: _cKhent,
        ),
        _Pill(
          label: 'Clair',
          watched: item.isWatchedByClair,
          color: _cClair,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool watched;
  final Color color;
  const _Pill({
    required this.label,
    required this.watched,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: watched
            ? color.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: watched
              ? color.withValues(alpha: 0.7)
              : _cMuted.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            watched
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: watched ? color : _cMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: watched ? _cWhite : _cMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchedButton extends StatelessWidget {
  final String label;
  final bool watched;
  final Color color;
  final VoidCallback onTap;

  const _WatchedButton({
    required this.label,
    required this.watched,
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
          color: watched
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: watched
                ? color.withValues(alpha: 0.7)
                : color.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              watched
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_outline_rounded,
              color: watched ? _cWhite : color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                watched ? '$label ✓' : label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: watched ? _cWhite : _cWhite.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
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

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cMuted.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, color: _cMuted, size: 18),
      ),
    );
  }
}

class _CinemaIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CinemaIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _cCard,
          shape: BoxShape.circle,
          border: Border.all(color: _cRose.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: _cRose, size: 18),
      ),
    );
  }
}
