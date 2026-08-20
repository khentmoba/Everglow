import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';

class ScribbleGameScreen extends StatefulWidget {
  const ScribbleGameScreen({super.key});

  @override
  State<ScribbleGameScreen> createState() => _ScribbleGameScreenState();
}

class _ScribbleGameScreenState extends State<ScribbleGameScreen> {
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _current = [];
  String _word = 'heart';
  final _words = ['love', 'sunset', 'cat', 'kiss', 'dance', 'everglow', 'star', 'moon', 'beach', 'guitar'];
  final _guessController = TextEditingController();
  String _status = 'Draw the word — partner guesses!';

  @override
  void initState() {
    super.initState();
    _word = (_words..shuffle()).first;
  }

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails d, BoxConstraints c) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _current = [box.globalToLocal(d.globalPosition)]);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _current.add(box.globalToLocal(d.globalPosition)));
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      _strokes.add(List.from(_current));
      _current = [];
    });
  }

  void _clear() => setState(() { _strokes.clear(); _current.clear(); });

  void _newWord() => setState(() { _word = (_words..shuffle()).first; _clear(); _status = 'New word — draw!'; });

  void _guess() {
    final g = _guessController.text.trim().toLowerCase();
    if (g.isEmpty) return;
    if (g == _word) {
      setState(() => _status = '🎉 Correct! It was "$_word"');
      _guessController.clear();
    } else {
      setState(() => _status = '❌ "$g" — try again!');
      _guessController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final isDrawer = true; // MVP: drawer is local user; in multiplayer would toggle via Firestore
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: EverglowBackground(baseColor: AppColors.inkDeep, glows: const [RadialGlow(color: AppColors.auroraTeal, alignment: Alignment(-0.7, -0.8), size: 0.85, opacity: 0.12)], showPetals: true)),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(title: 'Scribble', subtitle: 'draw & guess • Firestore sync ready', icon: Icons.brush_rounded, hue: AppColors.auroraTeal, onBack: () => Navigator.pop(context)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.15))),
                    child: Row(children: [Icon(Icons.lightbulb_rounded, size: 16, color: AppColors.warmAmber), const SizedBox(width: 8), Text(isDrawer ? 'Word: $_word' : 'Guess the drawing', style: AppTypography.outfitBold.copyWith(fontSize: 13, color: AppColors.warmAmber)), const Spacer(), Text('by ${auth.currentUser ?? ''}', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.5)))]),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppColors.inkDeep.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.info_outline_rounded, size: 14, color: AppColors.softLavender), const SizedBox(width: 6), Expanded(child: Text(_status, style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppTheme.petalWhite.withValues(alpha: 0.7))))]))),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.2))),
                    child: LayoutBuilder(builder: (context, constraints) {
                      return GestureDetector(
                        onPanStart: (d) => _onPanStart(d, constraints),
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: _ScribblePainter(strokes: [..._strokes, if (_current.isNotEmpty) _current]),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: TextField(controller: _guessController, onSubmitted: (_) => _guess(), style: AppTypography.outfitWhite.copyWith(color: AppColors.twilight, fontSize: 13), decoration: InputDecoration(hintText: 'Type guess...', hintStyle: AppTypography.outfitWhite.copyWith(color: AppTheme.petalWhite.withValues(alpha: 0.4)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)))),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _guess, style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepRose, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Guess')),
                  ]),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    OutlinedButton.icon(onPressed: _clear, icon: Icon(Icons.clear_rounded, size: 16, color: AppColors.warmAmber), label: Text('Clear', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppColors.warmAmber)), style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.warmAmber.withValues(alpha: 0.3)))),
                    const Spacer(),
                    ElevatedButton.icon(onPressed: _newWord, icon: const Icon(Icons.refresh_rounded, size: 16), label: Text('New word', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.auroraTeal)),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScribblePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  _ScribblePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black ..strokeWidth = 4 ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        final a = stroke[i];
        final b = stroke[i + 1];
        if (a != null && b != null) canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScribblePainter oldDelegate) => true;
}
