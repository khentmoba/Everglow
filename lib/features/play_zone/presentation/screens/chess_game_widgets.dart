part of 'chess_game_screen.dart';

// ── header icon ────────────────────────────────────────────────
class _HeaderIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.tooltip, required this.onTap});
  @override
  State<_HeaderIcon> createState() => _HeaderIconState();
}
class _HeaderIconState extends State<_HeaderIcon> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); widget.onTap(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover ? AppColors.moonlight.withValues(alpha: 0.12) : AppColors.panelGlass,
              border: Border.all(color: AppColors.moonlight.withValues(alpha: _hover ? 0.18 : 0.10)),
            ),
            child: Icon(widget.icon, size: 18, color: AppColors.blushGold),
          ),
        ),
      ),
    );
  }
}

// ── status bar ─────────────────────────────────────────────────
class _StatusBar extends StatelessWidget {
  final String turn;
  final bool isCheck;
  final bool isMate;
  final bool isStale;
  final int moveCount;
  final AnimationController checkPulse;
  const _StatusBar({required this.turn, required this.isCheck, required this.isMate, required this.isStale, required this.moveCount, required this.checkPulse});
  @override
  Widget build(BuildContext context) {
    String text;
    Color dot;
    IconData icon;
    if (isMate) {
      final winner = turn == 'w' ? 'Black' : 'White';
      text = 'Checkmate \u2022 $winner wins';
      dot = AppColors.error;
      icon = Icons.emoji_events_rounded;
    } else if (isStale) {
      text = 'Stalemate \u2022 Draw';
      dot = AppColors.warning;
      icon = Icons.handshake_rounded;
    } else if (isCheck) {
      text = '${turn == 'w' ? 'White' : 'Black'} in check!';
      dot = AppColors.error;
      icon = Icons.warning_amber_rounded;
    } else {
      text = '${turn == 'w' ? 'White' : 'Black'} to move';
      dot = turn == 'w' ? AppColors.petalWhite : const Color(0xFF2B2B2B);
      icon = Icons.circle;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: checkPulse,
        builder: (_, _) {
          final pulse = isCheck ? 0.6 + 0.4 * checkPulse.value : 1.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMate || isStale
                  ? AppColors.deepRose.withValues(alpha: 0.14)
                  : isCheck
                      ? AppColors.error.withValues(alpha: 0.10 * pulse + 0.08)
                      : AppColors.moonlight.withValues(alpha: 0.07),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(
                color: isCheck || isMate
                    ? AppColors.error.withValues(alpha: 0.35)
                    : AppColors.blushGold.withValues(alpha: 0.14),
              ),
              boxShadow: isCheck ? [BoxShadow(color: AppColors.error.withValues(alpha: 0.18 * pulse), blurRadius: 12)] : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.petalWhite.withValues(alpha: turn == 'w' ? 0.9 : 0.0)),
                    boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.45), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 14, color: isCheck || isMate ? AppColors.error : AppColors.blushGold.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(text,
                    style: AppTypography.outfitBold.copyWith(fontSize: 12.5, letterSpacing: 0.2, color: AppColors.petalWhite),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.inkDeep.withValues(alpha: 0.45),
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.10)),
                  ),
                  child: Text(moveCount == 0 ? 'New game' : '$moveCount ply \u2022 ${(moveCount / 2).ceil()} moves',
                    style: AppTypography.outfitWhite.copyWith(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: AppColors.petalWhite.withValues(alpha: 0.62)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── player bar ─────────────────────────────────────────────────
class _PlayerBar extends StatelessWidget {
  final String label;
  final bool isWhite;
  final bool isTurn;
  final List<String> captured;
  final int materialDiff;
  final bool top;
  const _PlayerBar({required this.label, required this.isWhite, required this.isTurn, required this.captured, required this.materialDiff, required this.top});
  @override
  Widget build(BuildContext context) {
    const pieceOrder = ['p','n','b','r','q'];
    final Map<String,int> counts = {};
    for (final p in captured) {
      final low = p.toLowerCase();
      counts[low] = (counts[low] ?? 0) + 1;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTurn ? AppColors.deepRose.withValues(alpha: 0.13) : AppColors.panelGlass,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: isTurn ? AppColors.deepRose.withValues(alpha: 0.28) : AppColors.moonlight.withValues(alpha: 0.10)),
        boxShadow: isTurn ? [BoxShadow(color: AppColors.deepRose.withValues(alpha: 0.14), blurRadius: 10)] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: isWhite ? [AppColors.petalWhite, const Color(0xFFE8E0D6)] : [const Color(0xFF2B2B2B), const Color(0xFF111111)]),
              border: Border.all(color: isTurn ? AppColors.blushGold.withValues(alpha: 0.55) : AppColors.moonlight.withValues(alpha: 0.12), width: isTurn ? 1.6 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
            ),
            child: Icon(isWhite ? Icons.circle : Icons.circle_outlined, size: 18, color: isWhite ? const Color(0xFF2B2B2B) : AppColors.petalWhite.withValues(alpha: 0.85)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(label, style: AppTypography.outfitBold.copyWith(fontSize: 12.5, color: AppColors.petalWhite)),
                if (isTurn) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.deepRose, borderRadius: AppRadius.radiusFull),
                    child: Text('TURN', style: AppTypography.outfitWhite.copyWith(fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.petalWhite)),
                  ),
                ],
                if (materialDiff > 0) ...[
                  const SizedBox(width: 6),
                  Text('+$materialDiff', style: AppTypography.outfitBold.copyWith(fontSize: 11, color: AppColors.success)),
                ],
              ]),
              const SizedBox(height: 3),
              SizedBox(
                height: 16,
                child: captured.isEmpty
                    ? Text('No captures', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.petalWhite.withValues(alpha: 0.38)))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pieceOrder.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 2),
                        itemBuilder: (_, i) {
                          final k = pieceOrder[i];
                          final cnt = counts[k] ?? 0;
                          if (cnt == 0) return const SizedBox.shrink();
                          final glyph = {'p':'\u265F','n':'\u265E','b':'\u265D','r':'\u265C','q':'\u265B'}[k]!;
                          return Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(glyph, style: TextStyle(fontSize: 13, color: AppColors.petalWhite.withValues(alpha: 0.85))),
                            if (cnt > 1) Text('\u00D7$cnt', style: AppTypography.outfitWhite.copyWith(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.petalWhite.withValues(alpha: 0.62))),
                          ]);
                        },
                      ),
              ),
            ]),
          ),
          if (isTurn)
            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 6)])),
        ],
      ),
    );
  }
}

// ── board ──────────────────────────────────────────────────────
class _BoardSection extends StatelessWidget {
  final Map<String,String> board;
  final String? selected;
  final Set<String> legalTargets;
  final String? lastFrom;
  final String? lastTo;
  final String? kingInCheck;
  final bool flipped;
  final bool isCheck;
  final AnimationController checkPulse;
  final void Function(String) onTap;
  final String Function(String?) pieceEmoji;
  final bool Function(String) isWhitePiece;
  const _BoardSection({required this.board, required this.selected, required this.legalTargets, required this.lastFrom, required this.lastTo, required this.kingInCheck, required this.flipped, required this.isCheck, required this.checkPulse, required this.onTap, required this.pieceEmoji, required this.isWhitePiece});

  List<String> _orderedSquares() {
    final out = <String>[];
    for (int r = 0; r < 8; r++) {
      final rank = flipped ? 1 + r : 8 - r;
      for (int f = 0; f < 8; f++) {
        final file = flipped ? 7 - f : f;
        out.add(String.fromCharCode(97 + file) + rank.toString());
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final squares = _orderedSquares();
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.radiusX2,
        border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.22), width: 1.2),
        boxShadow: [...AppElevation.e3, BoxShadow(color: AppColors.inkDeep.withValues(alpha: 0.55), blurRadius: 18)],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.radiusX2,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3A2352), Color(0xFF1A1A2E)],
                  ),
                ),
              ),
            ),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
              itemCount: 64,
              itemBuilder: (ctx, idx) {
                final sq = squares[idx];
                final rank = int.parse(sq[1]);
                final file = sq.codeUnitAt(0) - 97;
                final isLight = (rank + file) % 2 == 0;
                final baseLight = const Color(0xFFF0D9B5);
                final baseDark = const Color(0xFFB58863);
                final piece = board[sq];
                final isSelected = selected == sq;
                final isLegal = legalTargets.contains(sq);
                final isLast = sq == lastFrom || sq == lastTo;
                final isKingCheck = sq == kingInCheck;
                final isCapture = isLegal && piece != null;

                Color bg = isLight ? baseLight : baseDark;
                return GestureDetector(
                  onTap: () => onTap(sq),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        color: isKingCheck
                            ? const Color(0xFFE53E3E).withValues(alpha: 0.82)
                            : isSelected
                                ? AppColors.deepRose.withValues(alpha: 0.38)
                                : isLast
                                    ? AppColors.blushGold.withValues(alpha: isLight ? 0.42 : 0.34)
                                    : bg,
                        border: isSelected ? Border.all(color: AppColors.blushGold, width: 1.6) : null,
                      ),
                      child: Stack(
                        children: [
                          if ((!flipped && file == 0) || (flipped && file == 7))
                            Positioned(
                              top: 2, left: 3,
                              child: Text(
                                (idx % 8 == 0) ? sq[1] : '',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isLight ? const Color(0xFFB58863) : const Color(0xFFF0D9B5), height: 1),
                              ),
                            ),
                          if ((!flipped && rank == 1) || (flipped && rank == 8))
                            Positioned(
                              bottom: 1, right: 3,
                              child: Text(
                                String.fromCharCode(97 + file),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isLight ? const Color(0xFFB58863) : const Color(0xFFF0D9B5), height: 1),
                              ),
                            ),
                          if (isLegal && !isCapture)
                            Center(
                              child: Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.inkDeep.withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.12)),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4)],
                                ),
                                child: Center(
                                  child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF2B2B2B), shape: BoxShape.circle)),
                                ),
                              ),
                            ),
                          if (isCapture)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.deepRose.withValues(alpha: 0.78), width: 3.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 2)],
                                  ),
                                ),
                              ),
                            ),
                          if (piece != null)
                            Center(
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 140),
                                scale: isSelected ? 1.06 : 1.0,
                                child: Text(
                                  pieceEmoji(piece),
                                  style: TextStyle(
                                    fontSize: 30,
                                    height: 1,
                                    color: isWhitePiece(piece) ? AppColors.petalWhite : const Color(0xFF111111),
                                    shadows: [
                                      Shadow(color: Colors.black.withValues(alpha: isWhitePiece(piece) ? 0.28 : 0.45), blurRadius: 4, offset: const Offset(0, 1.5)),
                                      if (isWhitePiece(piece))
                                        const Shadow(color: AppColors.petalWhite, blurRadius: 0.5),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (isKingCheck)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: checkPulse,
                                  builder: (_, _) => Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.55 * checkPulse.value), width: 1.2),
                                      boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.35 * checkPulse.value), blurRadius: 10)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.radiusX2,
                    border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.04)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── side panel ─────────────────────────────────────────────────
class _SidePanel extends StatelessWidget {
  final String turn;
  final List<String> sanHistory;
  final List<String> capturedByWhite;
  final List<String> capturedByBlack;
  final int materialWhite;
  final int materialBlack;
  final bool isCheck;
  final bool isMate;
  final bool isStale;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onFlip;
  final bool flipped;
  const _SidePanel({required this.turn, required this.sanHistory, required this.capturedByWhite, required this.capturedByBlack, required this.materialWhite, required this.materialBlack, required this.isCheck, required this.isMate, required this.isStale, required this.canUndo, required this.onUndo, required this.onReset, required this.onFlip, required this.flipped});
  @override
  Widget build(BuildContext context) {
    final diff = materialWhite - materialBlack;
    String materialText;
    if (diff == 0) {
      materialText = 'Even material';
    } else if (diff > 0) {
      materialText = 'White +$diff';
    } else {
      materialText = 'Black +${-diff}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panelGlass,
            borderRadius: AppRadius.radiusX2,
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.11)),
            boxShadow: AppElevation.e2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                _PillButton(icon: Icons.undo_rounded, label: 'Undo', enabled: canUndo, onTap: onUndo),
                const SizedBox(width: 8),
                _PillButton(icon: Icons.swap_vert_rounded, label: flipped ? 'White view' : 'Black view', onTap: onFlip),
                const SizedBox(width: 8),
                _PillButton(icon: Icons.restart_alt_rounded, label: 'New', variant: _PillVariant.rose, onTap: onReset),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.inkDeep.withValues(alpha: 0.42),
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.blushGold.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: const Icon(Icons.auto_graph_rounded, size: 14, color: AppColors.blushGold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(materialText, style: AppTypography.outfitWhite.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.petalWhite.withValues(alpha: 0.78)))),
                  Text('${sanHistory.length} ply', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.petalWhite.withValues(alpha: 0.44))),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.panelGlass,
            borderRadius: AppRadius.radiusX2,
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.11)),
            boxShadow: AppElevation.e2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.deepRose.withValues(alpha: 0.14), borderRadius: AppRadius.radiusFull, border: Border.all(color: AppColors.deepRose.withValues(alpha: 0.18))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.history_rounded, size: 12, color: AppColors.deepRose),
                      const SizedBox(width: 4),
                      Text('Moves', style: AppTypography.outfitWhite.copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.deepRose)),
                    ]),
                  ),
                  const Spacer(),
                  if (sanHistory.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        final pgn = _toPgn(sanHistory);
                        Clipboard.setData(ClipboardData(text: pgn));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('PGN copied', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppColors.petalWhite)),
                            backgroundColor: AppColors.deepRose,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: AppRadius.radiusFull),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.copy_rounded, size: 11, color: AppColors.blushGold),
                          const SizedBox(width: 4),
                          Text('Copy PGN', style: AppTypography.outfitWhite.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.blushGold)),
                        ]),
                      ),
                    ),
                ]),
              ),
              if (sanHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.inkDeep.withValues(alpha: 0.35),
                      borderRadius: AppRadius.radiusLg,
                      border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.06)),
                    ),
                    child: Column(children: [
                      Icon(Icons.sports_esports_outlined, size: 22, color: AppColors.petalWhite.withValues(alpha: 0.22)),
                      const SizedBox(height: 8),
                      Text('No moves yet', style: AppTypography.outfitWhite.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.petalWhite.withValues(alpha: 0.55))),
                      const SizedBox(height: 4),
                      Text('Tap a piece to see legal moves \u2022 Dots = quiet \u2022 Ring = capture', textAlign: TextAlign.center, style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.petalWhite.withValues(alpha: 0.38), height: 1.4)),
                    ]),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Column(
                      children: List.generate((sanHistory.length / 2).ceil(), (i) {
                        final w = sanHistory[i * 2];
                        final b = (i * 2 + 1 < sanHistory.length) ? sanHistory[i * 2 + 1] : null;
                        final isLastRow = i == (sanHistory.length / 2).ceil() - 1;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          decoration: BoxDecoration(
                            color: isLastRow ? AppColors.blushGold.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: AppRadius.radiusSm,
                            border: isLastRow ? Border.all(color: AppColors.blushGold.withValues(alpha: 0.14)) : null,
                          ),
                          child: Row(children: [
                            SizedBox(width: 28, child: Text('${i + 1}.', style: AppTypography.outfitWhite.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.petalWhite.withValues(alpha: 0.42)))),
                            Expanded(child: _MovePill(text: w, isWhite: true, isLast: isLastRow && b == null)),
                            const SizedBox(width: 6),
                            Expanded(child: b != null ? _MovePill(text: b, isWhite: false, isLast: isLastRow) : Text('\u2014', style: AppTypography.outfitWhite.copyWith(fontSize: 11, color: AppColors.petalWhite.withValues(alpha: 0.22)))),
                          ]),
                        );
                      }),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text('Tip: tap your piece again to deselect \u2022 King in check pulses red \u2022 Last move glows gold', style: AppTypography.outfitWhite.copyWith(fontSize: 9.5, color: AppColors.petalWhite.withValues(alpha: 0.34), height: 1.4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.moonlight.withValues(alpha: 0.06),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const _LegendDot(color: AppColors.deepRose, label: 'Selected'),
              const SizedBox(width: 10),
              const _LegendDot(color: AppColors.blushGold, label: 'Last move'),
              const SizedBox(width: 10),
              const _LegendDot(color: AppColors.error, label: 'Check'),
              const Spacer(),
              Icon(Icons.touch_app_rounded, size: 12, color: AppColors.petalWhite.withValues(alpha: 0.32)),
              const SizedBox(width: 4),
              Text('Tap to move', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.petalWhite.withValues(alpha: 0.42))),
            ],
          ),
        ),
      ],
    );
  }

  String _toPgn(List<String> sans) {
    final buf = StringBuffer();
    for (int i = 0; i < sans.length; i++) {
      if (i % 2 == 0) {
        buf.write('${i ~/ 2 + 1}. ${sans[i]} ');
      } else {
        buf.write('${sans[i]} ');
      }
    }
    return buf.toString().trim() + (sans.isEmpty ? '' : ' *');
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: AppColors.petalWhite.withValues(alpha: 0.15)))),
      const SizedBox(width: 5),
      Text(label, style: AppTypography.outfitWhite.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.petalWhite.withValues(alpha: 0.62))),
    ]);
  }
}

class _MovePill extends StatelessWidget {
  final String text;
  final bool isWhite;
  final bool isLast;
  const _MovePill({required this.text, required this.isWhite, required this.isLast});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isLast ? (isWhite ? AppColors.petalWhite.withValues(alpha: 0.92) : const Color(0xFF1A1A1E)) : (isWhite ? AppColors.petalWhite.withValues(alpha: 0.08) : AppColors.inkDeep.withValues(alpha: 0.35)),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: isLast ? AppColors.blushGold.withValues(alpha: 0.35) : AppColors.moonlight.withValues(alpha: 0.08)),
      ),
      child: Text(text, style: AppTypography.outfitWhite.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: isLast ? (isWhite ? const Color(0xFF1A1A1E) : AppColors.petalWhite) : AppColors.petalWhite)),
    );
  }
}

enum _PillVariant { neutral, rose }
class _PillButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final _PillVariant variant;
  const _PillButton({required this.icon, required this.label, this.onTap, this.enabled = true, this.variant = _PillVariant.neutral});
  @override
  State<_PillButton> createState() => _PillButtonState();
}
class _PillButtonState extends State<_PillButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? () { HapticFeedback.selectionClick(); widget.onTap!(); } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: widget.variant == _PillVariant.rose
                  ? ( _hover && enabled ? AppColors.deepRose : AppColors.deepRose.withValues(alpha: 0.92))
                  : ( _hover && enabled ? AppColors.moonlight.withValues(alpha: 0.10) : AppColors.moonlight.withValues(alpha: 0.07)),
              borderRadius: AppRadius.radiusFull,
              border: Border.all(color: widget.variant == _PillVariant.rose ? AppColors.deepRose : AppColors.moonlight.withValues(alpha: _hover && enabled ? 0.16 : 0.10)),
              boxShadow: widget.variant == _PillVariant.rose && _hover ? AppElevation.glowRose : null,
            ),
            child: Opacity(
              opacity: enabled ? 1 : 0.38,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(widget.icon, size: 14, color: widget.variant == _PillVariant.rose ? AppColors.petalWhite : AppColors.blushGold),
                const SizedBox(width: 5),
                Text(widget.label, style: AppTypography.outfitWhite.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: widget.variant == _PillVariant.rose ? AppColors.petalWhite : AppColors.petalWhite)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── promotion sheet ────────────────────────────────────────────
class _PromotionSheet extends StatelessWidget {
  final void Function(String) onPick;
  final bool isWhite;
  const _PromotionSheet({required this.onPick, required this.isWhite});
  @override
  Widget build(BuildContext context) {
    const choices = ['q','r','b','n'];
    const labels = ['Queen','Rook','Bishop','Knight'];
    const emojisW = {'q':'\u2655','r':'\u2656','b':'\u2657','n':'\u2658'};
    const emojisB = {'q':'\u265B','r':'\u265C','b':'\u265D','n':'\u265E'};
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.52),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.velvet,
              borderRadius: AppRadius.radiusX2,
              border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.18)),
              boxShadow: AppElevation.e4,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.blushGold.withValues(alpha: 0.14), borderRadius: AppRadius.radiusFull),
                child: Text('Pawn promotion', style: AppTypography.outfitWhite.copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: AppColors.blushGold)),
              ),
              const SizedBox(height: 10),
              Text('Choose your piece', style: AppTypography.cormorantBold.copyWith(fontSize: 20, color: AppColors.petalWhite)),
              const SizedBox(height: 4),
              Text('Your pawn reached the end \u2014 crown it.', style: AppTypography.outfitWhite.copyWith(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (i) {
                  final c = choices[i];
                  final emoji = isWhite ? emojisW[c]! : emojisB[c]!;
                  return Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                    child: GestureDetector(
                      onTap: () { HapticFeedback.mediumImpact(); onPick(c); },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 74, height: 86,
                          decoration: BoxDecoration(
                            color: c == 'q' ? AppColors.deepRose.withValues(alpha: 0.14) : AppColors.moonlight.withValues(alpha: 0.07),
                            borderRadius: AppRadius.radiusLg,
                            border: Border.all(color: c == 'q' ? AppColors.deepRose.withValues(alpha: 0.28) : AppColors.moonlight.withValues(alpha: 0.12), width: c == 'q' ? 1.4 : 1),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(emoji, style: TextStyle(fontSize: 32, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4)])),
                            const SizedBox(height: 4),
                            Text(labels[i], style: AppTypography.outfitWhite.copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.petalWhite.withValues(alpha: 0.78))),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text('Queen is usually strongest', style: AppTypography.outfitWhite.copyWith(fontSize: 10, color: AppColors.petalWhite.withValues(alpha: 0.32))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── game over ──────────────────────────────────────────────────
class _GameOverOverlay extends StatelessWidget {
  final bool isMate;
  final String turn;
  final VoidCallback onNewGame;
  const _GameOverOverlay({required this.isMate, required this.turn, required this.onNewGame});
  @override
  Widget build(BuildContext context) {
    final winner = turn == 'w' ? 'Black' : 'White';
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.48),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(22),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.twilight,
              borderRadius: AppRadius.radiusX2,
              border: Border.all(color: AppColors.blushGold.withValues(alpha: 0.18)),
              boxShadow: AppElevation.e4,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: isMate ? [AppColors.deepRose, AppColors.auroraRose] : [AppColors.auroraGold, AppColors.warmAmber]),
                  boxShadow: [BoxShadow(color: (isMate ? AppColors.deepRose : AppColors.auroraGold).withValues(alpha: 0.35), blurRadius: 14)],
                ),
                child: Icon(isMate ? Icons.emoji_events_rounded : Icons.handshake_rounded, color: AppColors.petalWhite, size: 26),
              ),
              const SizedBox(height: 12),
              Text(isMate ? 'Checkmate!' : 'Stalemate', style: AppTypography.cormorantBold.copyWith(fontSize: 24, color: AppColors.petalWhite)),
              const SizedBox(height: 4),
              Text(isMate ? '$winner wins \u2014 beautiful game.' : 'Draw by stalemate \u2014 no legal moves, but no check.', textAlign: TextAlign.center, style: AppTypography.outfitWhite.copyWith(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.moonlight.withValues(alpha: 0.08), borderRadius: AppRadius.radiusFull, border: Border.all(color: AppColors.moonlight.withValues(alpha: 0.14))),
                    child: Text('Back to Play Zone', style: AppTypography.outfitWhite.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.petalWhite)),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onNewGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.deepRose, AppColors.auroraRose]), borderRadius: AppRadius.radiusFull, boxShadow: [BoxShadow(color: AppColors.deepRose.withValues(alpha: 0.28), blurRadius: 10)]),
                    child: Text('New game', style: AppTypography.outfitBold.copyWith(fontSize: 12, color: AppColors.petalWhite)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── snapshot ───────────────────────────────────────────────────
class _Snapshot {
  final Map<String,String> board;
  final String turn;
  final String? lastFrom;
  final String? lastTo;
  final String? enPassant;
  final bool wKing, bKing, wRa, wRh, bRa, bRh;
  final List<String> sanHistory;
  final List<String> capturedW, capturedB;
  final bool isCheck;
  final String? kingSq;
  final bool mate, stale;
  _Snapshot({required this.board, required this.turn, required this.lastFrom, required this.lastTo, required this.enPassant, required this.wKing, required this.bKing, required this.wRa, required this.wRh, required this.bRa, required this.bRh, required this.sanHistory, required this.capturedW, required this.capturedB, required this.isCheck, required this.kingSq, required this.mate, required this.stale});
}
