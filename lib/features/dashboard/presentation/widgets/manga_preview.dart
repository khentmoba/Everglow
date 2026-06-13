import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:everglow/features/manga/data/models/manga_item.dart';
import 'package:everglow/features/manga/data/services/mangadex_service.dart';
import 'package:everglow/features/manga/presentation/screens/manga_library_screen.dart';
import 'package:everglow/features/manga/presentation/widgets/manga_details_drawer.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/services/auth_service.dart';

/// "Reading" preview card on the dashboard.
///
/// For the couple (khentsgdz / clairjassen) it streams the combined
/// manga library from both partners so Khent and Clair always see
/// the same shared catalog. For other users (Breyan / Octagram) it
/// falls back to the current user's own library.
///
/// The covers are laid out in a marquee that scrolls at a constant
/// pixel-per-second speed and loops seamlessly — same pattern as
/// `CinemaPreview`.
class MangaPreview extends StatelessWidget {
  const MangaPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = MangaDexService();
    final auth = context.watch<AuthService>();
    final userName = auth.currentUser ?? '';
    final isCouple = auth.isCoupleUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reading',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.roseQuartz,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MangaLibraryScreen(),
                  ),
                ),
                child: Text(
                  'View All',
                  style: GoogleFonts.outfit(
                    color: AppTheme.blushGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: _MangaCarousel(
              stream: isCouple
                  ? service.getCoupleLibraryStream()
                  : service.getLibraryStream(userName),
            ),
          ),
        ],
      ),
    );
  }
}

class _MangaCarousel extends StatefulWidget {
  final Stream<List<MangaItem>> stream;
  const _MangaCarousel({required this.stream});

  @override
  State<_MangaCarousel> createState() => _MangaCarouselState();
}

class _MangaCarouselState extends State<_MangaCarousel>
    with SingleTickerProviderStateMixin {
  List<MangaItem> _items = [];
  bool _hasLoaded = false;
  late final ScrollController _scrollController;
  late final Ticker _ticker;
  StreamSubscription<List<MangaItem>>? _streamSub;
  Duration _lastTick = Duration.zero;

  static const double _itemWidth = 112.0;
  static const double _speed = 30.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick)..start();
    _streamSub = widget.stream.listen((items) {
      // Show anything that's been added to the library
      final filtered =
          items.where((i) => i.libraryStatus != 'none').toList();
      filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      if (!mounted) return;
      setState(() {
        _items = filtered;
        _hasLoaded = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    });
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients || _items.isEmpty) {
      _lastTick = elapsed;
      return;
    }
    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6;
    _lastTick = elapsed;

    final viewportWidth = _scrollController.position.viewportDimension;
    final singleSetWidth = _items.length * _itemWidth;
    final effectiveSingleSet = singleSetWidth < viewportWidth
        ? (viewportWidth * 2)
        : singleSetWidth;

    var newOffset = _scrollController.offset + _speed * dt;
    if (newOffset >= effectiveSingleSet) {
      newOffset -= effectiveSingleSet;
    }
    _scrollController.jumpTo(newOffset);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLoaded) {
      return _buildShimmer();
    }
    if (_items.isEmpty) {
      return const _MangaPreviewEmpty();
    }
    return _MarqueeRow(
      items: _items,
      controller: _scrollController,
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Container(
        width: 100,
        decoration: BoxDecoration(
          color: AppTheme.moonlight.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _MarqueeRow extends StatelessWidget {
  final List<MangaItem> items;
  final ScrollController controller;
  const _MarqueeRow({required this.items, required this.controller});

  @override
  Widget build(BuildContext context) {
    final covers = items.map((item) => _MangaCover(item: item)).toList();
    return ClipRect(
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            ...covers,
            ...covers,
          ],
        ),
      ),
    );
  }
}

class _MangaCover extends StatefulWidget {
  final MangaItem item;
  const _MangaCover({required this.item});

  @override
  State<_MangaCover> createState() => _MangaCoverState();
}

class _MangaCoverState extends State<_MangaCover> {
  bool _pressed = false;

  void _openDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MangaDetailsDrawer(item: widget.item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _openDetails();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        child: Container(
          width: 100,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepRose.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.item.coverUrl.isNotEmpty
                ? Image.network(widget.item.coverUrl, fit: BoxFit.cover)
                : Container(
                    color: AppTheme.velvet,
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: AppTheme.roseQuartz.withValues(alpha: 0.4),
                      size: 28,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MangaPreviewEmpty extends StatelessWidget {
  const _MangaPreviewEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.moonlight.withValues(alpha: AppTheme.glassOpacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.moonlight.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          'No manga in your library yet. Find your next read!',
          style: GoogleFonts.outfit(
            color: AppTheme.roseQuartz.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
