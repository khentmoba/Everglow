
import 'package:flutter/material.dart';  
import 'package:flutter/services.dart';  
import '../../../../core/theme/app_colors.dart';  
import '../../../../core/theme/app_radius.dart';  
import '../../../../core/theme/app_typography.dart';  
import '../../../../core/theme/app_elevation.dart';  
import '../../../../shared/widgets/everglow/everglow_background.dart';  
import '../../../../shared/widgets/everglow/everglow_feature_header.dart';  
part 'chess_game_widgets.dart';
  
// ──────────────────────────────────────────────────────────────  
//  Couple Chess — Dusk Petal premium redesign  
//  Local 2-player, full legal-move engine, polished UX.  
// ──────────────────────────────────────────────────────────────  
  
class ChessGameScreen extends StatefulWidget {  
  const ChessGameScreen({super.key});  
  @override  
  State<ChessGameScreen> createState() => _ChessGameScreenState();  
} 
  
class _ChessGameScreenState extends State<ChessGameScreen>  
    with SingleTickerProviderStateMixin {  
  // ── board state ────────────────────────────────────────────  
  late Map<String, String> _board;  
  String _turn = 'w';  
  String? _selected;  
  Set<String> _legalTargets = {};  
  String? _lastFrom;  
  String? _lastTo;  
  String? _enPassantTarget;  
  bool _whiteKingMoved = false;  
  bool _blackKingMoved = false;  
  bool _whiteRookAMoved = false;  
  bool _whiteRookHMoved = false;  
  bool _blackRookAMoved = false;  
  bool _blackRookHMoved = false;  
  final List<String> _capturedByWhite = []; // black pieces taken by white  
  final List<String> _capturedByBlack = []; // white pieces taken by black 
  final List<_Snapshot> _undoStack = [];  
  final List<String> _sanHistory = [];  
  bool _flipped = false;  
  bool _isCheck = false;  
  String? _kingInCheckSq;  
  bool _isCheckmate = false;  
  bool _isStalemate = false;  
  String? _promotionFrom;  
  String? _promotionTo;  
  late AnimationController _checkPulse;  
  
  // ── piece values for material ──────────────────────────────  
  static const _values = {  
    'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9, 'k': 0,  
    'P': 1, 'N': 3, 'B': 3, 'R': 5, 'Q': 9, 'K': 0,  
  };  
  
  @override
  void initState() {
    super.initState();
    _checkPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _resetBoard();
  }

  @override
  void dispose() {
    _checkPulse.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────
  int _fileOf(String sq) => sq.codeUnitAt(0) - 97;
  int _rankOf(String sq) => int.parse(sq[1]) - 1;
  String _sq(int f, int r) => String.fromCharCode(97 + f) + (r + 1).toString();
  bool _onBoard(int f, int r) => f >= 0 && f < 8 && r >= 0 && r < 8;
  bool _isWhite(String p) => p == p.toUpperCase();

  bool _isOwnPiece(String? p) {
    if (p == null) return false;
    return _turn == 'w' ? _isWhite(p) : !_isWhite(p);
  }

  String _pieceEmoji(String? p) {
    if (p == null) return '';
    const m = {
      'K': '\u2654', 'Q': '\u2655', 'R': '\u2656', 'B': '\u2657', 'N': '\u2658', 'P': '\u2659',
      'k': '\u265A', 'q': '\u265B', 'r': '\u265C', 'b': '\u265D', 'n': '\u265E', 'p': '\u265F',
    };
    return m[p] ?? '';
  }

  // ── board setup ────────────────────────────────────────────
  void _resetBoard() {
    _board = {
      'a8': 'r', 'b8': 'n', 'c8': 'b', 'd8': 'q', 'e8': 'k', 'f8': 'b', 'g8': 'n', 'h8': 'r',
      'a7': 'p', 'b7': 'p', 'c7': 'p', 'd7': 'p', 'e7': 'p', 'f7': 'p', 'g7': 'p', 'h7': 'p',
      'a2': 'P', 'b2': 'P', 'c2': 'P', 'd2': 'P', 'e2': 'P', 'f2': 'P', 'g2': 'P', 'h2': 'P',
      'a1': 'R', 'b1': 'N', 'c1': 'B', 'd1': 'Q', 'e1': 'K', 'f1': 'B', 'g1': 'N', 'h1': 'R',
    };
    _turn = 'w';
    _selected = null;
    _legalTargets = {};
    _lastFrom = null;
    _lastTo = null;
    _enPassantTarget = null;
    _whiteKingMoved = false;
    _blackKingMoved = false;
    _whiteRookAMoved = false;
    _whiteRookHMoved = false;
    _blackRookAMoved = false;
    _blackRookHMoved = false;
    _capturedByWhite.clear();
    _capturedByBlack.clear();
    _undoStack.clear();
    _sanHistory.clear();
    _isCheck = false;
    _kingInCheckSq = null;
    _isCheckmate = false;
    _isStalemate = false;
    _promotionFrom = null;
    _promotionTo = null;
    _checkPulse.stop();
    _checkPulse.value = 0;
    setState(() {});
  }

  // ── attack & move generation ───────────────────────────────
  String? _findKing(Map<String, String> board, bool white) {
    final k = white ? 'K' : 'k';
    for (final e in board.entries) {
      if (e.value == k) return e.key;
    }
    return null;
  }

  bool _isSquareAttacked(Map<String, String> board, String sq, bool byWhite) {
    final tf = _fileOf(sq);
    final tr = _rankOf(sq);
    for (final df in [-1, 1]) {
      final pf = tf + df;
      final pr = tr + (byWhite ? -1 : 1);
      if (_onBoard(pf, pr)) {
        final psq = _sq(pf, pr);
        final p = board[psq];
        if (p != null && p == (byWhite ? 'P' : 'p')) return true;
      }
    }
    const knightD = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)];
    for (final d in knightD) {
      final nf = tf + d.$1;
      final nr = tr + d.$2;
      if (!_onBoard(nf, nr)) continue;
      final p = board[_sq(nf, nr)];
      if (p != null && p.toLowerCase() == 'n' && _isWhite(p) == byWhite) return true;
    }
    for (int df = -1; df <= 1; df++) {
      for (int dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final nf = tf + df;
        final nr = tr + dr;
        if (!_onBoard(nf, nr)) continue;
        final p = board[_sq(nf, nr)];
        if (p != null && p.toLowerCase() == 'k' && _isWhite(p) == byWhite) return true;
      }
    }
    const diag = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
    for (final d in diag) {
      int nf = tf + d.$1;
      int nr = tr + d.$2;
      while (_onBoard(nf, nr)) {
        final p = board[_sq(nf, nr)];
        if (p != null) {
          if (_isWhite(p) == byWhite) {
            final low = p.toLowerCase();
            if (low == 'b' || low == 'q') return true;
          }
          break;
        }
        nf += d.$1;
        nr += d.$2;
      }
    }
    const orth = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    for (final d in orth) {
      int nf = tf + d.$1;
      int nr = tr + d.$2;
      while (_onBoard(nf, nr)) {
        final p = board[_sq(nf, nr)];
        if (p != null) {
          if (_isWhite(p) == byWhite) {
            final low = p.toLowerCase();
            if (low == 'r' || low == 'q') return true;
          }
          break;
        }
        nf += d.$1;
        nr += d.$2;
      }
    }
    return false;
  }

  List<String> _pseudoMovesFor(String from, Map<String, String> board, String? enPassant) {
    final piece = board[from];
    if (piece == null) return [];
    final isW = _isWhite(piece);
    final f = _fileOf(from);
    final r = _rankOf(from);
    final low = piece.toLowerCase();
    final List<String> out = [];
    void addIf(int nf, int nr, {bool captureOnly = false, bool quietOnly = false}) {
      if (!_onBoard(nf, nr)) return;
      final sq = _sq(nf, nr);
      final target = board[sq];
      if (target == null) {
        if (!captureOnly) out.add(sq);
      } else {
        if (_isWhite(target) != isW && !quietOnly) out.add(sq);
      }
    }

    if (low == 'p') {
      final dir = isW ? 1 : -1;
      final startRank = isW ? 1 : 6;
      final oneR = r + dir;
      if (_onBoard(f, oneR) && board[_sq(f, oneR)] == null) {
        out.add(_sq(f, oneR));
        final twoR = r + 2 * dir;
        if (r == startRank && _onBoard(f, twoR) && board[_sq(f, twoR)] == null) {
          out.add(_sq(f, twoR));
        }
      }
      for (final df in [-1, 1]) {
        final nf = f + df;
        final nr = r + dir;
        if (!_onBoard(nf, nr)) continue;
        final sq = _sq(nf, nr);
        final target = board[sq];
        if (target != null && _isWhite(target) != isW) {
          out.add(sq);
        } else if (enPassant != null && sq == enPassant) {
          out.add(sq);
        }
      }
    } else if (low == 'n') {
      const d = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)];
      for (final e in d) {
        addIf(f + e.$1, r + e.$2);
      }
    } else if (low == 'b' || low == 'r' || low == 'q') {
      final dirs = <(int, int)>[];
      if (low == 'b' || low == 'q') dirs.addAll([(1, 1), (1, -1), (-1, 1), (-1, -1)]);
      if (low == 'r' || low == 'q') dirs.addAll([(1, 0), (-1, 0), (0, 1), (0, -1)]);
      for (final d in dirs) {
        int nf = f + d.$1;
        int nr = r + d.$2;
        while (_onBoard(nf, nr)) {
          final sq = _sq(nf, nr);
          final target = board[sq];
          if (target == null) {
            out.add(sq);
          } else {
            if (_isWhite(target) != isW) out.add(sq);
            break;
          }
          nf += d.$1;
          nr += d.$2;
        }
      }
    } else if (low == 'k') {
      for (int df = -1; df <= 1; df++) {
        for (int dr = -1; dr <= 1; dr++) {
          if (df == 0 && dr == 0) continue;
          addIf(f + df, r + dr);
        }
      }
      final kingStart = isW ? 'e1' : 'e8';
      if (from == kingStart && !_isSquareAttacked(board, from, !isW)) {
        if (isW) {
          if (!_whiteKingMoved && !_whiteRookHMoved) {
            if (board['f1'] == null && board['g1'] == null) {
              if (!_isSquareAttacked(board, 'f1', false) && !_isSquareAttacked(board, 'g1', false)) {
                out.add('g1');
              }
            }
          }
          if (!_whiteKingMoved && !_whiteRookAMoved) {
            if (board['b1'] == null && board['c1'] == null && board['d1'] == null) {
              if (!_isSquareAttacked(board, 'd1', false) && !_isSquareAttacked(board, 'c1', false)) {
                out.add('c1');
              }
            }
          }
        } else {
          if (!_blackKingMoved && !_blackRookHMoved) {
            if (board['f8'] == null && board['g8'] == null) {
              if (!_isSquareAttacked(board, 'f8', true) && !_isSquareAttacked(board, 'g8', true)) {
                out.add('g8');
              }
            }
          }
          if (!_blackKingMoved && !_blackRookAMoved) {
            if (board['b8'] == null && board['c8'] == null && board['d8'] == null) {
              if (!_isSquareAttacked(board, 'd8', true) && !_isSquareAttacked(board, 'c8', true)) {
                out.add('c8');
              }
            }
          }
        }
      }
    }
    return out;
  }

  List<String> _legalMoves(String from) {
    final piece = _board[from];
    if (piece == null) return [];
    final isW = _isWhite(piece);
    if ((isW && _turn != 'w') || (!isW && _turn != 'b')) return [];
    final pseudos = _pseudoMovesFor(from, _board, _enPassantTarget);
    final List<String> legal = [];
    for (final to in pseudos) {
      final simulation = Map<String, String>.from(_board);
      final moving = simulation.remove(from)!;
      final captured = simulation[to];
      if (moving.toLowerCase() == 'p' && to == _enPassantTarget && captured == null) {
        final capRank = _rankOf(to) + (isW ? -1 : 1);
        final capSq = _sq(_fileOf(to), capRank);
        simulation.remove(capSq);
      }
      if (moving.toLowerCase() == 'k' && (from == 'e1' || from == 'e8')) {
        if (to == 'g1') {
          simulation.remove('h1');
          simulation['f1'] = 'R';
        } else if (to == 'c1') {
          simulation.remove('a1');
          simulation['d1'] = 'R';
        } else if (to == 'g8') {
          simulation.remove('h8');
          simulation['f8'] = 'r';
        } else if (to == 'c8') {
          simulation.remove('a8');
          simulation['d8'] = 'r';
        }
      }
      final isPromo = moving.toLowerCase() == 'p' && (_rankOf(to) == 7 || _rankOf(to) == 0);
      simulation[to] = isPromo ? (isW ? 'Q' : 'q') : moving;
      final kingSq = _findKing(simulation, isW);
      if (kingSq == null) continue;
      if (_isSquareAttacked(simulation, kingSq, !isW)) continue;
      legal.add(to);
    }
    return legal;
  }

  bool _hasAnyLegal(String turn) {
    for (final e in _board.entries) {
      final p = e.value;
      final isW = _isWhite(p);
      if ((turn == 'w' && !isW) || (turn == 'b' && isW)) continue;
      if (_legalMoves(e.key).isNotEmpty) return true;
    }
    return false;
  }

  void _updateGameState() {
    final whiteToMove = _turn == 'w';
    final kingSq = _findKing(_board, whiteToMove);
    _isCheck = false;
    _kingInCheckSq = null;
    if (kingSq != null && _isSquareAttacked(_board, kingSq, !whiteToMove)) {
      _isCheck = true;
      _kingInCheckSq = kingSq;
      _checkPulse.repeat(reverse: true);
    } else {
      _checkPulse.stop();
      _checkPulse.value = 0;
    }
    final hasMoves = _hasAnyLegal(_turn);
    _isCheckmate = _isCheck && !hasMoves;
    _isStalemate = !_isCheck && !hasMoves;
  }

  String _toSAN(String from, String to, String piece, String? captured, String? promo, bool givesCheck, bool isMate, bool isCastleKS, bool isCastleQS) {
    if (isCastleKS) return givesCheck ? 'O-O+' : (isMate ? 'O-O#' : 'O-O');
    if (isCastleQS) return givesCheck ? 'O-O-O+' : (isMate ? 'O-O-O#' : 'O-O-O');
    final low = piece.toLowerCase();
    final isPawn = low == 'p';
    String san = '';
    if (!isPawn) san += piece.toUpperCase();
    if (captured != null) {
      if (isPawn) san += from[0];
      san += 'x';
    }
    san += to;
    if (promo != null) san += '=${promo.toUpperCase()}';
    if (isMate) {
      san += '#';
    } else if (givesCheck) {
      san += '+';
    }
    return san;
  }

  // ── interaction ────────────────────────────────────────────
  void _onTapSquare(String sq) {
    if (_isCheckmate || _isStalemate) return;
    if (_promotionFrom != null) return;
    final piece = _board[sq];
    if (_selected == null) {
      if (piece != null && _isOwnPiece(piece)) {
        final legal = _legalMoves(sq);
        setState(() {
          _selected = sq;
          _legalTargets = legal.toSet();
        });
        HapticFeedback.selectionClick();
      }
    } else {
      if (_selected == sq) {
        setState(() {
          _selected = null;
          _legalTargets = {};
        });
        return;
      }
      if (piece != null && _isOwnPiece(piece)) {
        final legal = _legalMoves(sq);
        setState(() {
          _selected = sq;
          _legalTargets = legal.toSet();
        });
        HapticFeedback.selectionClick();
        return;
      }
      if (_legalTargets.contains(sq)) {
        _attemptMove(_selected!, sq);
      } else {
        setState(() {
          _selected = null;
          _legalTargets = {};
        });
      }
    }
  }

  void _attemptMove(String from, String to) {
    final moving = _board[from]!;
    final isW = _isWhite(moving);
    final isPawn = moving.toLowerCase() == 'p';
    final promoRank = isW ? 7 : 0;
    if (isPawn && _rankOf(to) == promoRank) {
      setState(() {
        _promotionFrom = from;
        _promotionTo = to;
      });
      return;
    }
    _executeMove(from, to, null);
  }

  void _executeMove(String from, String to, String? promotionChoice) {
    final moving = _board[from]!;
    final isW = _isWhite(moving);
    final captured = _board[to];
    final isPawn = moving.toLowerCase() == 'p';
    final isKing = moving.toLowerCase() == 'k';
    bool isEnPass = false;
    String? enPassCapturedSq;
    String? enPassCapturedPiece;
    if (isPawn && to == _enPassantTarget && captured == null) {
      isEnPass = true;
      final capRank = _rankOf(to) + (isW ? -1 : 1);
      enPassCapturedSq = _sq(_fileOf(to), capRank);
      enPassCapturedPiece = _board[enPassCapturedSq];
    }
    bool isCastleKS = false;
    bool isCastleQS = false;
    if (isKing) {
      if (from == 'e1' && to == 'g1') isCastleKS = true;
      if (from == 'e1' && to == 'c1') isCastleQS = true;
      if (from == 'e8' && to == 'g8') isCastleKS = true;
      if (from == 'e8' && to == 'c8') isCastleQS = true;
    }
    final String? actualCaptured = isEnPass ? enPassCapturedPiece : captured;

    _undoStack.add(_Snapshot(
      board: Map.from(_board),
      turn: _turn,
      lastFrom: _lastFrom,
      lastTo: _lastTo,
      enPassant: _enPassantTarget,
      wKing: _whiteKingMoved,
      bKing: _blackKingMoved,
      wRa: _whiteRookAMoved,
      wRh: _whiteRookHMoved,
      bRa: _blackRookAMoved,
      bRh: _blackRookHMoved,
      sanHistory: List.from(_sanHistory),
      capturedW: List.from(_capturedByWhite),
      capturedB: List.from(_capturedByBlack),
      isCheck: _isCheck,
      kingSq: _kingInCheckSq,
      mate: _isCheckmate,
      stale: _isStalemate,
    ));

    if (actualCaptured != null) {
      if (isW) {
        _capturedByWhite.add(actualCaptured);
      } else {
        _capturedByBlack.add(actualCaptured);
      }
    }

    _board.remove(from);
    if (isEnPass && enPassCapturedSq != null) {
      _board.remove(enPassCapturedSq);
    }
    if (isCastleKS) {
      if (isW) {
        _board.remove('h1');
        _board['f1'] = 'R';
      } else {
        _board.remove('h8');
        _board['f8'] = 'r';
      }
    } else if (isCastleQS) {
      if (isW) {
        _board.remove('a1');
        _board['d1'] = 'R';
      } else {
        _board.remove('a8');
        _board['d8'] = 'r';
      }
    }

    String placed = moving;
    if (promotionChoice != null) {
      placed = promotionChoice;
    } else if (isPawn && (_rankOf(to) == 7 || _rankOf(to) == 0)) {
      placed = isW ? 'Q' : 'q';
    }
    _board[to] = placed;

    if (moving == 'K') _whiteKingMoved = true;
    if (moving == 'k') _blackKingMoved = true;
    if (from == 'a1' || to == 'a1') _whiteRookAMoved = true;
    if (from == 'h1' || to == 'h1') _whiteRookHMoved = true;
    if (from == 'a8' || to == 'a8') _blackRookAMoved = true;
    if (from == 'h8' || to == 'h8') _blackRookHMoved = true;

    String? newEnPass;
    if (isPawn && (_rankOf(to) - _rankOf(from)).abs() == 2) {
      final midRank = (_rankOf(from) + _rankOf(to)) ~/ 2;
      newEnPass = _sq(_fileOf(from), midRank);
    }
    _enPassantTarget = newEnPass;

    _lastFrom = from;
    _lastTo = to;

    _turn = _turn == 'w' ? 'b' : 'w';

    final nextWhite = _turn == 'w';
    final nextKing = _findKing(_board, nextWhite);
    bool givesCheck = false;
    if (nextKing != null && _isSquareAttacked(_board, nextKing, !nextWhite)) givesCheck = true;
    final hasMoves = _hasAnyLegal(_turn);
    final isMate = givesCheck && !hasMoves;

    final san = _toSAN(from, to, moving, actualCaptured, promotionChoice, givesCheck, isMate, isCastleKS, isCastleQS);
    _sanHistory.add(san);

    _selected = null;
    _legalTargets = {};
    _promotionFrom = null;
    _promotionTo = null;

    _updateGameState();
    setState(() {});
    HapticFeedback.lightImpact();
  }

  void _onPromotionPick(String pieceLetter) {
    final from = _promotionFrom!;
    final to = _promotionTo!;
    final isW = _isWhite(_board[from]!);
    final promoChar = isW ? pieceLetter.toUpperCase() : pieceLetter.toLowerCase();
    _executeMove(from, to, promoChar);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final snap = _undoStack.removeLast();
    _board = snap.board;
    _turn = snap.turn;
    _lastFrom = snap.lastFrom;
    _lastTo = snap.lastTo;
    _enPassantTarget = snap.enPassant;
    _whiteKingMoved = snap.wKing;
    _blackKingMoved = snap.bKing;
    _whiteRookAMoved = snap.wRa;
    _whiteRookHMoved = snap.wRh;
    _blackRookAMoved = snap.bRa;
    _blackRookHMoved = snap.bRh;
    _sanHistory
      ..clear()
      ..addAll(snap.sanHistory);
    _capturedByWhite
      ..clear()
      ..addAll(snap.capturedW);
    _capturedByBlack
      ..clear()
      ..addAll(snap.capturedB);
    _isCheck = snap.isCheck;
    _kingInCheckSq = snap.kingSq;
    _isCheckmate = snap.mate;
    _isStalemate = snap.stale;
    _selected = null;
    _legalTargets = {};
    _promotionFrom = null;
    _promotionTo = null;
    if (_isCheck) {
      _checkPulse.repeat(reverse: true);
    } else { _checkPulse.stop(); _checkPulse.value=0; }
    setState(() {});
    HapticFeedback.selectionClick();
  }

  int _material(List<String> caps) {
    int s = 0;
    for (final p in caps) {
      s += _values[p] ?? 0;
    }
    return s;
  }

  // ── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 860;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: EverglowBackground(
              baseColor: AppColors.inkDeep,
              glows: [
                RadialGlow(color: AppColors.blushGold, alignment: Alignment(-0.6, -0.85), size: 0.85, opacity: 0.10),
                RadialGlow(color: AppColors.softLavender, alignment: Alignment(0.85, 0.9), size: 0.7, opacity: 0.07),
              ],
              showPetals: false,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                EverglowFeatureHeader(
                  title: 'Couple Chess',
                  subtitle: 'Lila \u2022 synced via Firestore \u2022 Dusk Petal edition',
                  icon: Icons.grid_on_rounded,
                  hue: AppColors.blushGold,
                  onBack: () => Navigator.maybePop(context),
                  actions: [
                    _HeaderIcon(icon: Icons.swap_vert_rounded, tooltip: 'Flip board', onTap: () => setState(() => _flipped = !_flipped)),
                    _HeaderIcon(icon: Icons.restart_alt_rounded, tooltip: 'New game', onTap: _confirmReset),
                  ],
                ),
                _StatusBar(
                  turn: _turn,
                  isCheck: _isCheck,
                  isMate: _isCheckmate,
                  isStale: _isStalemate,
                  moveCount: _sanHistory.length,
                  checkPulse: _checkPulse,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final boardWidget = _BoardSection(
                        board: _board,
                        selected: _selected,
                        legalTargets: _legalTargets,
                        lastFrom: _lastFrom,
                        lastTo: _lastTo,
                        kingInCheck: _kingInCheckSq,
                        flipped: _flipped,
                        isCheck: _isCheck,
                        checkPulse: _checkPulse,
                        onTap: _onTapSquare,
                        pieceEmoji: _pieceEmoji,
                        isWhitePiece: _isWhite,
                      );
                      final sidePanel = _SidePanel(
                        turn: _turn,
                        sanHistory: _sanHistory,
                        capturedByWhite: _capturedByWhite,
                        capturedByBlack: _capturedByBlack,
                        materialWhite: _material(_capturedByWhite),
                        materialBlack: _material(_capturedByBlack),
                        isCheck: _isCheck,
                        isMate: _isCheckmate,
                        isStale: _isStalemate,
                        canUndo: _undoStack.isNotEmpty,
                        onUndo: _undo,
                        onReset: _confirmReset,
                        onFlip: () => setState(() => _flipped = !_flipped),
                        flipped: _flipped,
                      );

                      if (isWide) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 640),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _PlayerBar(
                                          label: _flipped ? 'White \u2022 Khent' : 'Black \u2022 Clair',
                                          isWhite: _flipped,
                                          isTurn: (_turn == 'w') == _flipped,
                                          captured: _flipped ? _capturedByBlack : _capturedByWhite,
                                          materialDiff: _material(_capturedByWhite) - _material(_capturedByBlack),
                                          top: true,
                                        ),
                                        const SizedBox(height: 8),
                                        AspectRatio(aspectRatio: 1, child: boardWidget),
                                        const SizedBox(height: 8),
                                        _PlayerBar(
                                          label: _flipped ? 'Black \u2022 Clair' : 'White \u2022 Khent',
                                          isWhite: !_flipped,
                                          isTurn: (_turn == 'w') != _flipped,
                                          captured: _flipped ? _capturedByWhite : _capturedByBlack,
                                          materialDiff: _material(_capturedByBlack) - _material(_capturedByWhite),
                                          top: false,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(width: 360, child: SingleChildScrollView(child: sidePanel)),
                            ],
                          ),
                        );
                      } else {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                          child: Column(
                            children: [
                              _PlayerBar(
                                label: _flipped ? 'White \u2022 Khent' : 'Black \u2022 Clair',
                                isWhite: _flipped,
                                isTurn: (_turn == 'w') == _flipped,
                                captured: _flipped ? _capturedByBlack : _capturedByWhite,
                                materialDiff: _material(_capturedByWhite) - _material(_capturedByBlack),
                                top: true,
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 560),
                                child: AspectRatio(aspectRatio: 1, child: boardWidget),
                              ),
                              const SizedBox(height: 8),
                              _PlayerBar(
                                label: _flipped ? 'Black \u2022 Clair' : 'White \u2022 Khent',
                                isWhite: !_flipped,
                                isTurn: (_turn == 'w') != _flipped,
                                captured: _flipped ? _capturedByWhite : _capturedByBlack,
                                materialDiff: _material(_capturedByBlack) - _material(_capturedByWhite),
                                top: false,
                              ),
                              const SizedBox(height: 14),
                              sidePanel,
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_promotionFrom != null) _PromotionSheet(onPick: _onPromotionPick, isWhite: _isWhite(_board[_promotionFrom] ?? 'P')),
          if (_isCheckmate || _isStalemate) _GameOverOverlay(isMate: _isCheckmate, turn: _turn, onNewGame: _resetBoard),
        ],
      ),
    );
  }

  void _confirmReset() {
    if (_sanHistory.isEmpty && _undoStack.isEmpty) {
      _resetBoard();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.velvet,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusX2, side: BorderSide(color: AppColors.moonlight.withValues(alpha: 0.12))),
        title: Text('New game?', style: AppTypography.cormorantBold.copyWith(color: AppColors.petalWhite, fontSize: 20)),
        content: Text('Current position will be lost. Start fresh?', style: AppTypography.outfitWhite.copyWith(color: AppColors.textMedium, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: AppTypography.outfitWhite.copyWith(color: AppColors.textMuted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.deepRose, shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusFull)),
            onPressed: () { Navigator.pop(ctx); _resetBoard(); },
            child: Text('New game', style: AppTypography.outfitBold.copyWith(color: AppColors.petalWhite, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

