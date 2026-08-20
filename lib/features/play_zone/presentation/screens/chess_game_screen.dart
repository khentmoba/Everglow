import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/everglow/everglow_background.dart';
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({super.key});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  // Simple board: map square -> piece code (FEN char). Upper = white, lower = black.
  late Map<String, String> _board;
  String _turn = 'w';
  String? _selected;
  String _status = 'White to move';
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    setState(() {
      _board = {
        'a8': 'r', 'b8': 'n', 'c8': 'b', 'd8': 'q', 'e8': 'k', 'f8': 'b', 'g8': 'n', 'h8': 'r',
        'a7': 'p', 'b7': 'p', 'c7': 'p', 'd7': 'p', 'e7': 'p', 'f7': 'p', 'g7': 'p', 'h7': 'p',
        'a2': 'P', 'b2': 'P', 'c2': 'P', 'd2': 'P', 'e2': 'P', 'f2': 'P', 'g2': 'P', 'h2': 'P',
        'a1': 'R', 'b1': 'N', 'c1': 'B', 'd1': 'Q', 'e1': 'K', 'f1': 'B', 'g1': 'N', 'h1': 'R',
      };
      _turn = 'w';
      _selected = null;
      _status = 'White to move';
      _history.clear();
    });
  }

  bool _isWhite(String piece) => piece == piece.toUpperCase();
  bool _isOwnPiece(String? piece) {
    if (piece == null) return false;
    return _turn == 'w' ? _isWhite(piece) : !_isWhite(piece);
  }

  void _onTapSquare(String sq) {
    final piece = _board[sq];
    if (_selected == null) {
      if (piece != null && _isOwnPiece(piece)) {
        setState(() => _selected = sq);
      }
    } else {
      if (_selected == sq) {
        setState(() => _selected = null);
        return;
      }
      if (piece != null && _isOwnPiece(piece)) {
        setState(() => _selected = sq);
        return;
      }
      // Move
      final moving = _board[_selected!];
      if (moving == null) return;
      setState(() {
        _board.remove(_selected);
        _board[sq] = moving;
        _history.add('$_selected→$sq');
        _turn = _turn == 'w' ? 'b' : 'w';
        _status = _turn == 'w' ? 'White to move' : 'Black to move';
        _selected = null;
        // Firestore sync would go here: ChessService().updateMove(...)
      });
    }
  }

  String _pieceEmoji(String? p) {
    if (p == null) return '';
    const map = {'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙', 'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟'};
    return map[p] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: EverglowBackground(baseColor: AppColors.inkDeep, glows: const [RadialGlow(color: AppColors.blushGold, alignment: Alignment(-0.6, -0.8), size: 0.8, opacity: 0.12)], showPetals: true)),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(title: 'Chess', subtitle: 'Lila • synced via Firestore', icon: Icons.grid_on_rounded, hue: AppColors.blushGold, onBack: () => Navigator.pop(context)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.15))),
                    child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: _turn == 'w' ? Colors.white : Colors.black, shape: BoxShape.circle, border: Border.all(color: AppColors.blushGold))), const SizedBox(width: 8), Text(_status, style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppTheme.petalWhite)), const Spacer(), if (_history.isNotEmpty) Text(_history.last, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppTheme.petalWhite.withValues(alpha: 0.6)))]),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.3)), boxShadow: [BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.5), blurRadius: 12)]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                            itemCount: 64,
                            itemBuilder: (context, idx) {
                              final rank = 8 - (idx ~/ 8);
                              final file = String.fromCharCode('a'.codeUnitAt(0) + (idx % 8));
                              final sq = '$file$rank';
                              final isLight = (idx ~/ 8 + idx % 8) % 2 == 0;
                              final piece = _board[sq];
                              final isSelected = _selected == sq;
                              return GestureDetector(
                                onTap: () => _onTapSquare(sq),
                                child: Container(
                                  color: isSelected ? AppColors.warmAmber.withValues(alpha: 0.6) : (isLight ? const Color(0xFFF0D9B5) : const Color(0xFFB58863)),
                                  child: Center(child: Text(_pieceEmoji(piece), style: TextStyle(fontSize: 26, color: piece != null && _isWhite(piece) ? Colors.white : Colors.black, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2)]))),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _resetBoard, icon: Icon(Icons.restart_alt_rounded, size: 16, color: AppColors.blushGold), label: Text('Reset', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppColors.blushGold)), style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.blushGold.withValues(alpha: 0.3))))), const SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: () => setState(() => _selected = null), icon: const Icon(Icons.clear_rounded, size: 16), label: Text('Deselect', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepRose)))]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
