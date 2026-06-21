import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/auth_service.dart';
import '../../data/services/starlight_service.dart';
import '../../domain/models/star_note.dart';
import '../widgets/glass_jar.dart';
import '../widgets/star_widget.dart';
import '../widgets/drop_star_dialog.dart';
import '../widgets/note_display_dialog.dart';
import 'package:everglow/core/theme/app_theme.dart';

class StarlightJarWidget extends StatefulWidget {
  const StarlightJarWidget({super.key});

  @override
  State<StarlightJarWidget> createState() => _StarlightJarWidgetState();
}

class _StarlightJarWidgetState extends State<StarlightJarWidget> with TickerProviderStateMixin {
  final StarlightService _service = StarlightService();
  late final Stream<List<StarNote>> _starNotesStream;
  late AnimationController _shakeController;
  late AnimationController _idleController;
  final Random _random = Random();
  final Map<int, _StarMotion> _motionCache = {};
  
  // For the "drop" animation
  StarNote? _droppingStar;
  AnimationController? _dropController;
  Animation<Offset>? _dropAnimation;

  // For the "float out" animation
  StarNote? _floatingStar;
  AnimationController? _floatController;
  Animation<double>? _floatAnimation;

  @override
  void initState() {
    super.initState();
    _starNotesStream = _service.getStarNotes();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _idleController.dispose();
    _dropController?.dispose();
    _floatController?.dispose();
    super.dispose();
  }

  Future<void> _showDropDialog() async {
    final String? content = await showDialog<String>(
      context: context,
      builder: (context) => const DropStarDialog(),
    );

    if (content != null && content.isNotEmpty) {
      final auth = context.read<AuthService>();
      final author = auth.currentUser ?? 'unknown';
      
      _startDropAnimation(content, author);
      await _service.addStar(content, author);
    }
  }

  void _startDropAnimation(String content, String author) {
    _dropController?.dispose();
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final start = Offset(MediaQuery.of(context).size.width / 2, -50);
    final end = Offset(
      120 + _random.nextDouble() * 160,
      300 + _random.nextDouble() * 100,
    );

    _dropAnimation = Tween<Offset>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(
      parent: _dropController!,
      curve: Curves.bounceOut,
    ));

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

  Future<void> _onJarTap() async {
    if (_shakeController.isAnimating || _floatController?.isAnimating == true) return;

    await _shakeController.forward(from: 0);

    if (!mounted) return;
    final randomNote = await _service.getRandomStarNote();
    if (!mounted) return;

    if (randomNote != null) {
      _startFloatAnimation(randomNote);
    } else {
      if (!mounted) return;
      _showEmptyJarMessage();
    }
  }

  void _showEmptyJarMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("No stars in the jar yet — drop one first!"),
        backgroundColor: AppTheme.velvet,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startFloatAnimation(StarNote note) {
    _floatController?.dispose();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _floatAnimation = CurvedAnimation(
      parent: _floatController!,
      curve: Curves.easeOutBack,
    );

    setState(() {
      _floatingStar = note;
    });

    _floatController!.forward().then((_) {
      _showNoteDialog(note);
    });
  }

  Future<void> _showNoteDialog(StarNote note) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => NoteDisplayDialog(note: note),
    );

    if (!mounted) return;
    await _floatController!.reverse();
    if (!mounted) return;
    setState(() {
      _floatingStar = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 500,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Jar
          GestureDetector(
            onTap: _onJarTap,
            child: GlassJar(
              shakeAnimation: _shakeController.drive(
                TweenSequence<double>([
                  TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.05), weight: 1),
                  TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 2),
                  TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 1),
                ]),
              ),
            ),
          ),

          // Floating Stars (from Stream) with organic drift animation
          IgnorePointer(
            child: AnimatedBuilder(
            animation: _idleController,
            builder: (context, _) {
              return StreamBuilder<List<StarNote>>(
                stream: _starNotesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final notes = snapshot.data!;
                  final t = _idleController.value;
                  return Stack(
                    children: notes.map((note) {
                      final m = _getMotion(note.id.hashCode);
                      final tX = t * m.speedX;
                      final tY = t * m.speedY;

                      final dx = m.baseX
                        + sin(tX * 2 * pi + m.phaseX) * m.ampX
                        + sin(tX * 2 * pi * 0.37 + m.phaseX * 1.7) * m.ampX * 0.3;
                      final dy = m.baseY
                        + cos(tY * 2 * pi + m.phaseY) * m.ampY
                        + cos(tY * 2 * pi * 0.43 + m.phaseY * 1.3) * m.ampY * 0.25;
                      final rotation = m.baseRotation + sin(t * 2 * pi * m.rotSpeed) * 0.5;
                      final opacity = 0.55 + sin(t * 2 * pi * 2.3 + m.twinklePhase) * 0.35;
                      final scale = 0.85 + sin(t * 2 * pi * 1.2 + m.phaseX) * 0.15;

                      return StarWidget(
                        color: m.color,
                        position: Offset(dx, dy),
                        rotation: rotation,
                        size: 24 * scale,
                        opacity: opacity.clamp(0.0, 1.0),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
          ),

          // The Animating "Drop" Star
          if (_droppingStar != null && _dropAnimation != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _dropAnimation!,
                builder: (context, child) {
                  return StarWidget(
                    color: AppTheme.blushGold,
                    position: _dropAnimation!.value,
                    rotation: _dropController!.value * pi * 2,
                  );
                },
              ),
            ),

          // The Animating "Float Out" Star
          if (_floatingStar != null && _floatAnimation != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _floatAnimation!,
                builder: (context, child) {
                  final Offset end = const Offset(200, 80);
                  final Offset start = const Offset(200, 350);
                  final currentPos = Offset.lerp(start, end, _floatAnimation!.value)!;

                  return StarWidget(
                    color: AppTheme.deepRose,
                    position: currentPos,
                    size: 24 + (16 * _floatAnimation!.value),
                    rotation: _floatController!.value * pi,
                  );
                },
              ),
            ),

          // Drop Button
          Positioned(
            right: 20,
            bottom: 60,
            child: FloatingActionButton(
              onPressed: _showDropDialog,
              backgroundColor: AppTheme.deepRose,
              foregroundColor: AppTheme.petalWhite,
              child: const Icon(Icons.star, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  _StarMotion _getMotion(int seed) {
    return _motionCache.putIfAbsent(seed, () => _StarMotion.fromSeed(seed));
  }
}

class _StarMotion {
  static const _colors = [
    AppTheme.roseQuartz,
    AppTheme.blushGold,
    AppTheme.softLavender,
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
    baseX = 90 + r.nextDouble() * 190;
    baseY = 120 + r.nextDouble() * 200;
    ampX = 15 + r.nextDouble() * 20;
    ampY = 12 + r.nextDouble() * 18;
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
