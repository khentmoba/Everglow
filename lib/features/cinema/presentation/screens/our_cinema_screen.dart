import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:everglow/features/cinema/data/models/our_cinema_item.dart';
import 'package:everglow/features/cinema/data/models/media_item.dart';
import 'package:everglow/features/cinema/data/services/our_cinema_service.dart';
import 'package:everglow/features/cinema/data/services/tmdb_service.dart';
import 'package:everglow/features/cinema/presentation/widgets/episode_drawer.dart';
import 'package:everglow/features/cinema/presentation/widgets/tmdb_search_modal.dart';
import 'package:everglow/features/cinema/presentation/widgets/trailer_player.dart';
import 'package:everglow/services/auth_service.dart';

const _cBlack = Color(0xFF09060E);
const _cVelvet = Color(0xFF12091A);
const _cCard = Color(0x1F2A1B3D); // Translucent glassmorphic dark card
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
  final TMDBService _tmdbService = TMDBService();

  StreamSubscription<List<OurCinemaItem>>? _sub;
  List<OurCinemaItem> _items = [];
  bool _isLoading = true;
  int _tab = 0;

  // Hover states for playing trailers on Desktop
  String? _hoveredItemId;
  Timer? _hoverTimer;
  bool _showHoverTrailer = false;
  String? _hoverTrailerKey;
  final Map<String, String?> _trailerKeysCache = {};

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
    _hoverTimer?.cancel();
    super.dispose();
  }

  List<OurCinemaItem> get _watchedList =>
      _items.where((i) => i.isWatched).toList();
  List<OurCinemaItem> get _toWatchList =>
      _items.where((i) => !i.isWatched).toList();

  void _onHoverEnter(OurCinemaItem item) {
    setState(() {
      _hoveredItemId = item.id;
      _showHoverTrailer = false;
      _hoverTrailerKey = null;
    });

    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 600), () async {
      if (_hoveredItemId != item.id) return;
      
      String? key;
      if (_trailerKeysCache.containsKey(item.id)) {
        key = _trailerKeysCache[item.id];
      } else {
        key = await _tmdbService.fetchTrailerKey(item.tmdbId, item.mediaType);
        _trailerKeysCache[item.id] = key;
      }
      
      if (_hoveredItemId == item.id && mounted && key != null) {
        setState(() {
          _hoverTrailerKey = key;
          _showHoverTrailer = true;
        });
      }
    });
  }

  void _onHoverExit() {
    _hoverTimer?.cancel();
    setState(() {
      _hoveredItemId = null;
      _showHoverTrailer = false;
      _hoverTrailerKey = null;
    });
  }

  void _showMediaDetails(MediaItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EpisodeDrawer(item: item),
    );
  }

  Future<void> _openAddToOurCinema() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TMDBSearchModal(initialScope: 'ours'),
    );
  }

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
        child: Stack(
          children: [
            // Dynamic Radial Glow in background
            Positioned(
              top: -100,
              left: -100,
              width: 400,
              height: 400,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cDeepRose.withOpacity(0.08),
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
                  color: _cKhent.withOpacity(0.05),
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
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _cWhite,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: _cDeepRose.withOpacity(0.3),
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
                      color: _cDeepRose,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentUser == 'khentsgdz'
                        ? 'KHENT & CLAIR'
                        : 'CLAIR & KHENT',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      color: _cMuted,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: _cDeepRose,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Tooltip(
            message: 'Add to Our Cinema',
            child: _CinemaIconBtn(
              icon: Icons.add_rounded,
              onTap: _openAddToOurCinema,
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
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cRose.withOpacity(0.05)),
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
                ? _cDeepRose.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? _cDeepRose.withOpacity(0.3) : Colors.transparent,
              width: 1.0,
            ),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? _cDeepRose : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? _cDeepRose
                        : _cRose.withOpacity(0.1),
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
    final isHovered = _hoveredItemId == item.id;
    final showTrailer = isHovered && _showHoverTrailer && _hoverTrailerKey != null;

    return FadeInUp(
      duration: const Duration(milliseconds: 350),
      child: MouseRegion(
        onEnter: (_) => _onHoverEnter(item),
        onExit: (_) => _onHoverExit(),
        child: AnimatedScale(
          scale: isHovered ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isHovered ? const Color(0x2E2A1B3D) : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isHovered 
                    ? _cDeepRose.withOpacity(0.4) 
                    : _cRose.withOpacity(0.08),
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHovered 
                      ? _cDeepRose.withOpacity(0.25) 
                      : Colors.black.withOpacity(0.4),
                  blurRadius: isHovered ? 24 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Stack(
                children: [
                  // Backdrop image
                  if (item.backdropPath.isNotEmpty && !showTrailer)
                    Positioned.fill(
                      child: Opacity(
                        opacity: isHovered ? 0.12 : 0.04,
                        child: Image.network(
                          item.backdropPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // Looping Trailer
                  if (showTrailer)
                    Positioned.fill(
                      child: TrailerPlayer(
                        videoKey: _hoverTrailerKey!,
                        muted: true,
                        autoplay: true,
                        loop: true,
                      ),
                    ),

                  if (showTrailer)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.45),
                              Colors.black.withOpacity(0.85),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showMediaDetails(item.toMediaItem()),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Poster Image
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
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
                                  child: item.posterPath.isNotEmpty
                                      ? Image.network(
                                          item.posterPath,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => _posterPlaceholder(),
                                        )
                                      : _posterPlaceholder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Details column
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
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      if (item.year.isNotEmpty)
                                        Text(
                                          item.year,
                                          style: GoogleFonts.outfit(
                                            color: _cGold,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      if (item.year.isNotEmpty) const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _cDeepRose.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _cDeepRose.withOpacity(0.4),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          item.mediaType.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            color: _cRose,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (showTrailer)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.videocam_rounded, color: Colors.green, size: 10),
                                              const SizedBox(width: 4),
                                              Text(
                                                'TRAILER',
                                                style: GoogleFonts.outfit(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ],
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
                                        child: _WatchedButton(
                                          label: isMine ? 'I Watched' : 'Clair Watched',
                                          watched: isMine
                                              ? item.isWatchedByKhent
                                              : item.isWatchedByClair,
                                          color: isMine ? _cKhent : _cClair,
                                          onTap: () {
                                            _service.setWatchedFlag(
                                              tmdbId: item.tmdbId,
                                              userName: currentUser,
                                              watched: !(isMine
                                                  ? item.isWatchedByKhent
                                                  : item.isWatchedByClair),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoupleBadges(OurCinemaItem item) {
    final khentWatched = item.isWatchedByKhent;
    final clairWatched = item.isWatchedByClair;
    
    if (khentWatched && clairWatched) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cKhent, _cClair],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _cClair.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              'Watched Together 💞',
              style: GoogleFonts.outfit(
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
          watched: khentWatched,
          color: _cKhent,
        ),
        const SizedBox(width: 8),
        _buildAvatarBadge(
          initial: 'C',
          label: 'Clair',
          watched: clairWatched,
          color: _cClair,
        ),
      ],
    );
  }

  Widget _buildAvatarBadge({
    required String initial,
    required String label,
    required bool watched,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: watched ? color.withOpacity(0.15) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: watched ? color : _cMuted.withOpacity(0.3),
          width: watched ? 1.5 : 1.0,
        ),
        boxShadow: watched ? [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 6,
          ),
        ] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: watched ? color : _cMuted.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: watched ? Colors.white : _cMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
        backgroundColor: const Color(0xFF1C1228),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Remove from Our Cinema?',
          style: GoogleFonts.cormorantGaramond(
            color: _cRose,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Text(
          'This will remove "${item.title}" from the shared list for both of you.',
          style: GoogleFonts.outfit(color: _cWhite, fontSize: 13, height: 1.4),
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
              color: _cRose.withOpacity(0.2),
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
            if (isToWatchTab) ...[
              const SizedBox(height: 24),
              _EmptyStateCta(onTap: _openAddToOurCinema),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCta extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyStateCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _cDeepRose.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cDeepRose.withOpacity(0.5), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: _cDeepRose.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: _cRose, size: 18),
            const SizedBox(width: 8),
            Text(
              'Add a movie or series',
              style: GoogleFonts.outfit(
                color: _cWhite,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
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
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: watched
                ? color.withOpacity(0.8)
                : color.withOpacity(0.35),
            width: watched ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              watched
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_outline_rounded,
              color: watched ? Colors.white : color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                watched ? '$label ✓' : label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: watched ? Colors.white : Colors.white.withOpacity(0.85),
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
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cMuted.withOpacity(0.35)),
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
          color: Colors.white.withOpacity(0.02),
          shape: BoxShape.circle,
          border: Border.all(color: _cRose.withOpacity(0.1)),
        ),
        child: Icon(icon, color: _cRose, size: 18),
      ),
    );
  }
}
