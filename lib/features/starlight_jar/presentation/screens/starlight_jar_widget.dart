import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/services/auth_service.dart';
import '../../data/services/starlight_service.dart';
import '../../domain/models/star_note.dart';
import '../widgets/glass_jar.dart';
import '../widgets/star_widget.dart';
import '../widgets/drop_star_dialog.dart';
import '../widgets/note_display_dialog.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';

class StarlightJarWidget extends StatefulWidget {
  const StarlightJarWidget({super.key});

  @override
  State<StarlightJarWidget> createState() => _StarlightJarWidgetState();
}

class _StarlightJarWidgetState extends State<StarlightJarWidget>
    with TickerProviderStateMixin {
  final StarlightService _service = StarlightService();
  late final Stream<List<StarNote>> _starNotesStream;
  StreamSubscription<List<StarNote>>? _starNotesSub;
  List<StarNote> _notes = const [];
  late AnimationController _shakeController;
  late AnimationController _idleController;
  final Random _random = Random();
  final Map<int, _StarMotion> _motionCache = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  List<StarNote> _onThisDayNotes = [];
  bool _showOnThisDay = false;

  // For the "drop" animation
  StarNote? _droppingStar;
  AnimationController? _dropController;
  Animation<Offset>? _dropAnimation;

  // For the "float out" animation
  StarNote? _floatingStar;
  AnimationController? _floatController;
  Animation<double>? _floatAnimation;

  // Single-flight guard so taps during an ongoing open/reveal flow can't
  // start a second, racing fetch + animation.
  bool _jarBusy = false;

  // Tap scale feedback
  double _tapScale = 1.0;

  // Confetti for surprise reveal
  late final ConfettiController _surpriseConfetti;

  @override
  void initState() {
    super.initState();
    _starNotesStream = _service.getStarNotes();
    _starNotesSub = _starNotesStream.listen((notes) {
      if (!mounted) return;
      setState(() => _notes = notes);
    });
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _surpriseConfetti = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _loadOnThisDay();
  }

  Future<void> _loadOnThisDay() async {
    final notes = await _service.getStarsFromThisDay();
    if (mounted && notes.isNotEmpty) {
      setState(() {
        _onThisDayNotes = notes;
        _showOnThisDay = true;
      });
    }
  }

  @override
  void dispose() {
    _starNotesSub?.cancel();
    _shakeController.dispose();
    _idleController.dispose();
    _dropController?.dispose();
    _floatController?.dispose();
    _searchController.dispose();
    _surpriseConfetti.dispose();
    super.dispose();
  }

  // ── Drop Star ──

  Future<void> _showDropDialog() async {
    final result = await showDialog<StarDropResult>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => const DropStarDialog(),
    );

    if (result != null && result.content.trim().isNotEmpty && mounted) {
      final auth = context.read<AuthService>();
      final author = auth.currentUser ?? 'unknown';

      _startDropAnimation(result.content, author);
      await _service.addStar(
        result.content,
        author,
        category: result.category,
        tags: result.tags,
      );
    }
  }

  void _startDropAnimation(String content, String author) {
    _dropController?.dispose();
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    final start = Offset(MediaQuery.sizeOf(context).width / 2, -50);
    final end = Offset(
      120 + _random.nextDouble() * 160,
      300 + _random.nextDouble() * 60,
    );

    _dropAnimation = Tween<Offset>(begin: start, end: end).animate(
      CurvedAnimation(parent: _dropController!, curve: Curves.bounceOut),
    );

    _droppingStar = StarNote(
      id: 'temp',
      content: content,
      author: author,
      timestamp: DateTime.now(),
    );

    _dropController!.forward().then((_) {
      setState(() {
        _droppingStar = null;
      });
    });

    setState(() {});
  }

  // ── Jar Tap → Random Note ──

  Future<void> _onJarTap() async {
    if (_jarBusy || _shakeController.isAnimating) {
      return;
    }
    _jarBusy = true;
    try {
      setState(() => _tapScale = 0.95);
      await _shakeController.forward(from: 0);
      if (mounted) setState(() => _tapScale = 1.0);
      if (!mounted) return;

      final randomNote = await _service.getRandomStarNote();
      if (!mounted) return;

      if (randomNote != null) {
        await _playFloatAndReveal(randomNote);
      } else {
        _showEmptyJarMessage();
      }
    } finally {
      _jarBusy = false;
    }
  }

  void _showEmptyJarMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No stars in the jar yet — drop one first!"),
        backgroundColor: AppColors.velvet,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _playFloatAndReveal(StarNote note) async {
    _floatController?.dispose();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _floatAnimation = CurvedAnimation(
      parent: _floatController!,
      curve: Curves.easeOutExpo,
    );

    setState(() {
      _floatingStar = note;
    });

    await _floatController!.forward();
    if (!mounted) return;
    await _showNoteDialog(note);
  }

  Future<void> _showNoteDialog(StarNote note) async {
    await showDialog(
      context: context,
      barrierColor: AppColors.inkDeep.withValues(alpha: 0.72),
      barrierDismissible: false,
      builder: (context) => NoteDisplayDialog(note: note),
    );

    if (!mounted) return;
    if (_floatController != null) {
      await _floatController!.reverse();
    }
    if (!mounted) return;
    setState(() {
      _floatingStar = null;
    });
  }

  // ── Surprise Reveal ──

  Future<void> _surpriseReveal() async {
    if (_jarBusy || _shakeController.isAnimating) {
      return;
    }

    final randomNote = await _service.getRandomStarNote();
    if (!mounted) return;

    if (randomNote == null) {
      _showEmptyJarMessage();
      return;
    }

    _jarBusy = true;
    try {
      _surpriseConfetti.play();
      await _playFloatAndReveal(randomNote);
    } finally {
      _jarBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // Confetti for surprise reveal
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _surpriseConfetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.blushGold,
                AppColors.roseQuartz,
                AppColors.softLavender,
                AppColors.petalWhite,
                Color(0xFFFFF176),
                Color(0xFF80DEEA),
              ],
              emissionFrequency: 0.06,
              numberOfParticles: 20,
            ),
          ),

          Column(
            children: [
              // ── Header ──
              const EverglowFeatureHeader(
                title: 'Starlight Jar',
                subtitle: 'gratitude under the stars',
                icon: Icons.auto_awesome_rounded,
                hue: AppColors.blushGold,
              ),

              // ── On This Day Banner ──
              if (_showOnThisDay && _onThisDayNotes.isNotEmpty)
                Semantics(
                  label: 'On This Day memory from the past. Tap to view.',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      final note = _onThisDayNotes.first;
                      _showNoteDialog(note);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.blushGold.withValues(alpha: 0.15),
                            AppColors.deepRose.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.blushGold.withValues(alpha: 0.65),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('📅', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'On This Day',
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.blushGold,
                                  ),
                                ),
                                Text(
                                  _onThisDayNotes.first.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.outfitWhite.copyWith(
                                    fontSize: 11,
                                    color: AppColors.petalWhite.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.blushGold.withValues(alpha: 0.65),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Search & Filter Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Column(
                  children: [
                    // Search field
                    TextField(
                      controller: _searchController,
                      style: AppTypography.outfitWhite.copyWith(
                        color: AppColors.petalWhite,
                        fontSize: 13,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: "Search stars…",
                        hintStyle: AppTypography.outfitWhite.copyWith(
                          color: AppColors.petalWhite.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.blushGold,
                          size: 18,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: Icon(
                                  Icons.clear,
                                  color: AppColors.petalWhite.withValues(
                                    alpha: 0.4,
                                  ),
                                  size: 16,
                                ),
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.twilight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.blushGold.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.blushGold,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Category filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryChip(null, 'All'),
                          ...starCategories.map(
                            (cat) => _buildCategoryChip(
                              cat,
                              starCategoryInfo[cat]?.$2 ?? cat,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // ── Jar + Stars ──
              SizedBox(
                height: 480,
                child: Center(
                  child: SizedBox(
                    width: 400,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The Jar — with scale animation on tap
                        Positioned(
                          top: 20,
                          child: GestureDetector(
                            onTap: _onJarTap,
                            child: AnimatedScale(
                              scale: _tapScale,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutExpo,
                              child: GlassJar(
                                shakeAnimation: _shakeController.drive(
                                  TweenSequence<double>([
                                    TweenSequenceItem(
                                      tween: Tween(begin: 0.0, end: 0.12),
                                      weight: 1,
                                    ),
                                    TweenSequenceItem(
                                      tween: Tween(begin: 0.12, end: -0.12),
                                      weight: 2,
                                    ),
                                    TweenSequenceItem(
                                      tween: Tween(begin: -0.12, end: 0.08),
                                      weight: 2,
                                    ),
                                    TweenSequenceItem(
                                      tween: Tween(begin: 0.08, end: -0.05),
                                      weight: 2,
                                    ),
                                    TweenSequenceItem(
                                      tween: Tween(begin: -0.05, end: 0.0),
                                      weight: 1,
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Star Count Badge
                        Positioned(
                          top: 22,
                          // IgnorePointer so taps on the badge still reach the jar.
                          child: IgnorePointer(
                            child: _notes.isEmpty
                                ? const SizedBox.shrink()
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.deepRose.withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.deepRose.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${_notes.length} ${_notes.length == 1 ? 'star' : 'stars'}',
                                      style: AppTypography.outfitWhite.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.petalWhite,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                          ),
                        ),

                        // Stars clipped to jar body
                        ClipPath(
                          clipper: const JarClipperAtOffset(
                            offset: Offset(60, 56),
                            size: Size(280, 350),
                          ),
                          child: Stack(
                            children: [
                              // Idle floating stars
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _idleController,
                                    builder: (context, _) => CustomPaint(
                                      painter: _JarStarFieldPainter(
                                        notes: _filterNotes(_notes),
                                        t: _idleController.value,
                                        motionCache: _motionCache,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // The Animating "Drop" Star
                              if (_droppingStar != null &&
                                  _dropAnimation != null)
                                IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _dropAnimation!,
                                    builder: (context, child) {
                                      return Stack(
                                        children: [
                                          StarWidget(
                                            color: AppColors.blushGold,
                                            position: _dropAnimation!.value,
                                            rotation:
                                                _dropController!.value * pi * 2,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                              // The Animating "Float Out" Star
                              if (_floatingStar != null &&
                                  _floatAnimation != null)
                                IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _floatAnimation!,
                                    builder: (context, child) {
                                      const end = Offset(200, 100);
                                      const start = Offset(200, 370);
                                      final currentPos = Offset.lerp(
                                        start,
                                        end,
                                        _floatAnimation!.value,
                                      )!;

                                      return Stack(
                                        children: [
                                          StarWidget(
                                            color: AppColors.deepRose,
                                            position: currentPos,
                                            size:
                                                24 +
                                                (16 * _floatAnimation!.value),
                                            rotation:
                                                _floatController!.value * pi,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
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

          // ── FABs ──
          Positioned(
            right: 20,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Surprise Reveal FAB (smaller)
                FloatingActionButton(
                  onPressed: _surpriseReveal,
                  heroTag: 'surprise',
                  backgroundColor: AppColors.blushGold,
                  foregroundColor: AppColors.velvet,
                  mini: true,
                  child: const Icon(Icons.casino_rounded, size: 20),
                ),
                const SizedBox(height: 10),
                // Drop Star FAB (main)
                FloatingActionButton(
                  onPressed: _showDropDialog,
                  heroTag: 'drop',
                  backgroundColor: AppColors.deepRose,
                  foregroundColor: AppColors.petalWhite,
                  child: const Icon(Icons.star, color: AppColors.petalWhite),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  List<StarNote> _filterNotes(List<StarNote> notes) {
    var filtered = notes;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (n) =>
                n.content.toLowerCase().contains(q) ||
                n.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }
    if (_selectedCategory != null) {
      filtered = filtered
          .where((n) => n.category == _selectedCategory)
          .toList();
    }
    return filtered;
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = category == null
        ? _selectedCategory == null
        : _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.deepRose.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.blushGold
                  : AppColors.blushGold.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.outfitWhite.copyWith(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.petalWhite
                  : AppColors.petalWhite.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarMotion {
  static const _colors = [
    AppColors.roseQuartz,
    AppColors.blushGold,
    AppColors.softLavender,
    Color(0xFFFFF176),
    Color(0xFF80DEEA),
  ];

  late double baseX;
  late double baseY;
  late double ampX;
  late double ampY;
  late double speedX;
  late double speedY;
  late double phaseX;
  late double phaseY;
  late double rotSpeed;
  late double twinklePhase;
  late double baseRotation;
  late Color color;

  _StarMotion.fromSeed(int seed) {
    final r = Random(seed);
    baseX = 100 + r.nextDouble() * 160;
    baseY = 100 + r.nextDouble() * 200;
    ampX = 8 + r.nextDouble() * 12;
    ampY = 6 + r.nextDouble() * 10;
    speedX = 0.55 + r.nextDouble() * 0.45;
    speedY = 0.4 + r.nextDouble() * 0.4;
    phaseX = r.nextDouble() * 2 * pi;
    phaseY = r.nextDouble() * 2 * pi;
    rotSpeed = 0.25 + r.nextDouble() * 0.55;
    twinklePhase = r.nextDouble() * 2 * pi;
    baseRotation = r.nextDouble() * 2 * pi;

    final base = _colors[r.nextInt(_colors.length)];
    color = base.withValues(alpha: 0.7);
  }
}

/// Paints the floating star field in a single CustomPainter pass. Motion
/// parameters are cached per star, so each frame only evaluates a handful of
/// trig expressions instead of rebuilding 200 Positioned/Icon widgets.
class _JarStarFieldPainter extends CustomPainter {
  final List<StarNote> notes;
  final double t;
  final Map<int, _StarMotion> motionCache;

  const _JarStarFieldPainter({
    required this.notes,
    required this.t,
    required this.motionCache,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const jarLeft = 60.0;
    const jarTop = 56.0;
    const jarRight = 340.0;
    const jarBottom = 406.0;
    const maxSize = 24.0;

    for (final note in notes) {
      final m = motionCache.putIfAbsent(
        note.id.hashCode,
        () => _StarMotion.fromSeed(note.id.hashCode),
      );
      final tX = t * m.speedX;
      final tY = t * m.speedY;

      final rawDx =
          m.baseX +
          sin(tX * 2 * pi + m.phaseX) * m.ampX +
          sin(tX * 2 * pi * 0.37 + m.phaseX * 1.7) * m.ampX * 0.3;
      final rawDy =
          m.baseY +
          cos(tY * 2 * pi + m.phaseY) * m.ampY +
          cos(tY * 2 * pi * 0.43 + m.phaseY * 1.3) * m.ampY * 0.25;
      final dx = rawDx.clamp(jarLeft, jarRight - maxSize);
      final dy = rawDy.clamp(jarTop, jarBottom - maxSize);
      final rotation = m.baseRotation + sin(t * 2 * pi * m.rotSpeed) * 0.5;
      final opacity = (0.55 + sin(t * 2 * pi * 2.3 + m.twinklePhase) * 0.35)
          .clamp(0.0, 1.0);
      final scale = 0.85 + sin(t * 2 * pi * 1.2 + m.phaseX) * 0.15;

      final paint = Paint()
        ..color = m.color.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(rotation);
      canvas.drawPath(_starPath(24 * scale), paint);
      canvas.restore();
    }
  }

  Path _starPath(double size) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? size * 0.5 : size * 0.22;
      final angle = -pi / 2 + i * pi / points;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _JarStarFieldPainter oldDelegate) =>
      oldDelegate.t != t || !identical(oldDelegate.notes, notes);
}