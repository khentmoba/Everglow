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
      duration: const Duration(seconds: 4),
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
    
    final randomNote = await _service.getRandomStarNote();
    if (randomNote != null) {
      _startFloatAnimation(randomNote);
    }
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

    // Return star to jar
    await _floatController!.reverse();
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

          // Piled Stars (from Stream) with idle bob animation
          AnimatedBuilder(
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
                      final rand = Random(note.id.hashCode);
                      final baseX = 120.0 + rand.nextDouble() * 160;
                      final baseY = 300.0 + rand.nextDouble() * 100;
                      final phase = rand.nextDouble() * 2 * pi;
                      final bobAmp = 2.0 + rand.nextDouble() * 3.0;

                      final dx = baseX + sin(t * 2 * pi + phase) * bobAmp;
                      final dy = baseY + cos(t * 2 * pi + phase * 1.3) * bobAmp * 0.6;
                      final rotation = rand.nextDouble() * pi + sin(t * 2 * pi + phase) * 0.1;
                      final color = _getPastelColor(rand);
                      final scale = 1.0 + sin(t * 2 * pi + phase * 0.7) * 0.08;

                      return StarWidget(
                        color: color,
                        position: Offset(dx, dy),
                        rotation: rotation,
                        size: 24 * scale,
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),

          // The Animating "Drop" Star
          if (_droppingStar != null && _dropAnimation != null)
            AnimatedBuilder(
              animation: _dropAnimation!,
              builder: (context, child) {
                return StarWidget(
                  color: AppTheme.blushGold,
                  position: _dropAnimation!.value,
                  rotation: _dropController!.value * pi * 2,
                );
              },
            ),

          // The Animating "Float Out" Star
          if (_floatingStar != null && _floatAnimation != null)
            AnimatedBuilder(
              animation: _floatAnimation!,
              builder: (context, child) {
                final Offset end = Offset(MediaQuery.of(context).size.width / 2 - 12, 100);
                // Simple lerp from a random bottom position to the center
                final Offset start = Offset(200, 350);
                final currentPos = Offset.lerp(start, end, _floatAnimation!.value)!;

                return StarWidget(
                  color: AppTheme.deepRose,
                  position: currentPos,
                  size: 24 + (16 * _floatAnimation!.value), // Scales up as it floats out
                  rotation: _floatController!.value * pi,
                );
              },
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

  Color _getPastelColor(Random rand) {
    final colors = [
      AppTheme.roseQuartz.withValues(alpha: 0.7),
      AppTheme.blushGold.withValues(alpha: 0.7),
      AppTheme.softLavender.withValues(alpha: 0.7),
      Colors.yellow[200]!.withValues(alpha: 0.7),
      Colors.cyan[100]!.withValues(alpha: 0.7),
    ];
    return colors[rand.nextInt(colors.length)];
  }
}
