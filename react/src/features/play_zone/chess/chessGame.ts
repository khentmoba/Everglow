// The rules half of lib/features/play_zone/presentation/screens/chess_game_screen.dart:
// a two-player chess board with castling, en passant, promotion, undo and SAN.
export type Board = Map<string, string>;
type Snapshot = Omit<ChessState, 'selected' | 'legalTargets' | 'promotionFrom' | 'promotionTo' | 'flipped'>;

type ChessState = {
  board: Board;
  turn: 'w' | 'b';
  selected: string | null;
  legalTargets: Set<string>;
  lastFrom: string | null;
  lastTo: string | null;
  enPassant: string | null;
  wKing: boolean;
  bKing: boolean;
  wRa: boolean;
  wRh: boolean;
  bRa: boolean;
  bRh: boolean;
  capturedByWhite: string[];
  capturedByBlack: string[];
  sanHistory: string[];
  isCheck: boolean;
  kingInCheck: string | null;
  isCheckmate: boolean;
  isStalemate: boolean;
  promotionFrom: string | null;
  promotionTo: string | null;
  flipped: boolean;
};

const VALUES: Record<string, number> = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 };
const GLYPHS: Record<string, string> = {
  K: '♔',
  Q: '♕',
  R: '♖',
  B: '♗',
  N: '♘',
  P: '♙',
  k: '♚',
  q: '♛',
  r: '♜',
  b: '♝',
  n: '♞',
  p: '♟',
};
const KNIGHT: Array<[number, number]> = [
  [1, 2],
  [2, 1],
  [2, -1],
  [1, -2],
  [-1, -2],
  [-2, -1],
  [-2, 1],
  [-1, 2],
];
const DIAG: Array<[number, number]> = [
  [1, 1],
  [1, -1],
  [-1, 1],
  [-1, -1],
];
const ORTH: Array<[number, number]> = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
];
const START = 'rnbqkbnr';

export const fileOf = (sq: string) => sq.charCodeAt(0) - 97;
export const rankOf = (sq: string) => Number(sq[1]) - 1;
export const square = (f: number, r: number) => String.fromCharCode(97 + f) + (r + 1);
const onBoard = (f: number, r: number) => f >= 0 && f < 8 && r >= 0 && r < 8;
export const isWhitePiece = (p: string) => p === p.toUpperCase();
export const pieceGlyph = (p: string | undefined) => (p ? (GLYPHS[p] ?? '') : '');
export const material = (caps: string[]) => caps.reduce((s, p) => s + (VALUES[p.toLowerCase()] ?? 0), 0);

function startBoard(): Board {
  const b: Board = new Map();
  for (let f = 0; f < 8; f++) {
    const file = String.fromCharCode(97 + f);
    b.set(`${file}8`, START[f]);
    b.set(`${file}7`, 'p');
    b.set(`${file}2`, 'P');
    b.set(`${file}1`, START[f].toUpperCase());
  }
  return b;
}

function findKing(board: Board, white: boolean) {
  const k = white ? 'K' : 'k';
  for (const [sq, p] of board) if (p === k) return sq;
  return null;
}

export function isSquareAttacked(board: Board, sq: string, byWhite: boolean): boolean {
  const tf = fileOf(sq);
  const tr = rankOf(sq);
  for (const df of [-1, 1]) {
    const pf = tf + df;
    const pr = tr + (byWhite ? -1 : 1);
    if (onBoard(pf, pr) && board.get(square(pf, pr)) === (byWhite ? 'P' : 'p')) return true;
  }
  const near = (deltas: Array<[number, number]>, kind: string) =>
    deltas.some(([df, dr]) => {
      const nf = tf + df;
      const nr = tr + dr;
      if (!onBoard(nf, nr)) return false;
      const p = board.get(square(nf, nr));
      return p != null && p.toLowerCase() === kind && isWhitePiece(p) === byWhite;
    });
  if (near(KNIGHT, 'n')) return true;
  if (near([...DIAG, ...ORTH], 'k')) return true;
  const slides = (dirs: Array<[number, number]>, kinds: string) =>
    dirs.some(([df, dr]) => {
      let nf = tf + df;
      let nr = tr + dr;
      while (onBoard(nf, nr)) {
        const p = board.get(square(nf, nr));
        if (p != null) return isWhitePiece(p) === byWhite && kinds.includes(p.toLowerCase());
        nf += df;
        nr += dr;
      }
      return false;
    });
  return slides(DIAG, 'bq') || slides(ORTH, 'rq');
}

export class ChessGame implements ChessState {
  board: Board = startBoard();
  turn: 'w' | 'b' = 'w';
  selected: string | null = null;
  legalTargets = new Set<string>();
  lastFrom: string | null = null;
  lastTo: string | null = null;
  enPassant: string | null = null;
  wKing = false;
  bKing = false;
  wRa = false;
  wRh = false;
  bRa = false;
  bRh = false;
  capturedByWhite: string[] = [];
  capturedByBlack: string[] = [];
  sanHistory: string[] = [];
  isCheck = false;
  kingInCheck: string | null = null;
  isCheckmate = false;
  isStalemate = false;
  promotionFrom: string | null = null;
  promotionTo: string | null = null;
  flipped = false;
  undoStack: Snapshot[] = [];

  reset() {
    const flipped = this.flipped;
    Object.assign(this, new ChessGame());
    this.flipped = flipped;
  }

  private isOwn(p: string | undefined) {
    return p != null && (this.turn === 'w' ? isWhitePiece(p) : !isWhitePiece(p));
  }

  private pseudoMoves(from: string, board: Board, enPassant: string | null): string[] {
    const piece = board.get(from);
    if (piece == null) return [];
    const isW = isWhitePiece(piece);
    const f = fileOf(from);
    const r = rankOf(from);
    const low = piece.toLowerCase();
    const out: string[] = [];
    const addIf = (nf: number, nr: number) => {
      if (!onBoard(nf, nr)) return;
      const sq = square(nf, nr);
      const target = board.get(sq);
      if (target == null || isWhitePiece(target) !== isW) out.push(sq);
    };

    if (low === 'p') {
      const dir = isW ? 1 : -1;
      const oneR = r + dir;
      if (onBoard(f, oneR) && board.get(square(f, oneR)) == null) {
        out.push(square(f, oneR));
        const twoR = r + 2 * dir;
        if (r === (isW ? 1 : 6) && onBoard(f, twoR) && board.get(square(f, twoR)) == null) out.push(square(f, twoR));
      }
      for (const df of [-1, 1]) {
        const nf = f + df;
        const nr = r + dir;
        if (!onBoard(nf, nr)) continue;
        const sq = square(nf, nr);
        const target = board.get(sq);
        if ((target != null && isWhitePiece(target) !== isW) || (enPassant != null && sq === enPassant)) out.push(sq);
      }
    } else if (low === 'n') {
      for (const [df, dr] of KNIGHT) addIf(f + df, r + dr);
    } else if (low === 'b' || low === 'r' || low === 'q') {
      const dirs = [...(low !== 'r' ? DIAG : []), ...(low !== 'b' ? ORTH : [])];
      for (const [df, dr] of dirs) {
        let nf = f + df;
        let nr = r + dr;
        while (onBoard(nf, nr)) {
          const sq = square(nf, nr);
          const target = board.get(sq);
          if (target == null) out.push(sq);
          else {
            if (isWhitePiece(target) !== isW) out.push(sq);
            break;
          }
          nf += df;
          nr += dr;
        }
      }
    } else if (low === 'k') {
      for (const [df, dr] of [...DIAG, ...ORTH].sort(([a, b], [c, d]) => a - c || b - d)) addIf(f + df, r + dr);
      if (from === (isW ? 'e1' : 'e8') && !isSquareAttacked(board, from, !isW)) {
        const rank = isW ? '1' : '8';
        const kingMoved = isW ? this.wKing : this.bKing;
        const free = (files: string) => [...files].every((c) => board.get(c + rank) == null);
        const safe = (files: string) => [...files].every((c) => !isSquareAttacked(board, c + rank, !isW));
        if (!kingMoved && !(isW ? this.wRh : this.bRh) && free('fg') && safe('fg')) out.push(`g${rank}`);
        if (!kingMoved && !(isW ? this.wRa : this.bRa) && free('bcd') && safe('dc')) out.push(`c${rank}`);
      }
    }
    return out;
  }

  legalMoves(from: string): string[] {
    const piece = this.board.get(from);
    if (piece == null) return [];
    const isW = isWhitePiece(piece);
    if ((isW && this.turn !== 'w') || (!isW && this.turn !== 'b')) return [];
    const legal: string[] = [];
    for (const to of this.pseudoMoves(from, this.board, this.enPassant)) {
      const sim = new Map(this.board);
      const moving = sim.get(from)!;
      sim.delete(from);
      if (moving.toLowerCase() === 'p' && to === this.enPassant && sim.get(to) == null) {
        sim.delete(square(fileOf(to), rankOf(to) + (isW ? -1 : 1)));
      }
      if (moving.toLowerCase() === 'k' && (from === 'e1' || from === 'e8')) castleRook(sim, to);
      const isPromo = moving.toLowerCase() === 'p' && (rankOf(to) === 7 || rankOf(to) === 0);
      sim.set(to, isPromo ? (isW ? 'Q' : 'q') : moving);
      const kingSq = findKing(sim, isW);
      if (kingSq == null || isSquareAttacked(sim, kingSq, !isW)) continue;
      legal.push(to);
    }
    return legal;
  }

  private hasAnyLegal(turn: 'w' | 'b') {
    for (const [sq, p] of this.board) {
      if ((turn === 'w') !== isWhitePiece(p)) continue;
      if (this.legalMoves(sq).length) return true;
    }
    return false;
  }

  private updateGameState() {
    const whiteToMove = this.turn === 'w';
    const kingSq = findKing(this.board, whiteToMove);
    this.isCheck = kingSq != null && isSquareAttacked(this.board, kingSq, !whiteToMove);
    this.kingInCheck = this.isCheck ? kingSq : null;
    const hasMoves = this.hasAnyLegal(this.turn);
    this.isCheckmate = this.isCheck && !hasMoves;
    this.isStalemate = !this.isCheck && !hasMoves;
  }

  /** Returns true when a selection changed (Flutter plays a selection click then). */
  tap(sq: string): boolean {
    if (this.isCheckmate || this.isStalemate || this.promotionFrom != null) return false;
    const piece = this.board.get(sq);
    if (this.selected != null && this.selected === sq) {
      this.selected = null;
      this.legalTargets = new Set();
      return false;
    }
    if (this.isOwn(piece)) {
      this.selected = sq;
      this.legalTargets = new Set(this.legalMoves(sq));
      return true;
    }
    if (this.selected == null) return false;
    if (this.legalTargets.has(sq)) this.attemptMove(this.selected, sq);
    else {
      this.selected = null;
      this.legalTargets = new Set();
    }
    return false;
  }

  private attemptMove(from: string, to: string) {
    const moving = this.board.get(from)!;
    if (moving.toLowerCase() === 'p' && rankOf(to) === (isWhitePiece(moving) ? 7 : 0)) {
      this.promotionFrom = from;
      this.promotionTo = to;
      return;
    }
    this.executeMove(from, to, null);
  }

  pickPromotion(letter: string) {
    const from = this.promotionFrom!;
    const to = this.promotionTo!;
    const isW = isWhitePiece(this.board.get(from)!);
    this.executeMove(from, to, isW ? letter.toUpperCase() : letter.toLowerCase());
  }

  private executeMove(from: string, to: string, promotion: string | null) {
    const moving = this.board.get(from)!;
    const isW = isWhitePiece(moving);
    const captured = this.board.get(to);
    const isPawn = moving.toLowerCase() === 'p';
    let epSq: string | null = null;
    if (isPawn && to === this.enPassant && captured == null) epSq = square(fileOf(to), rankOf(to) + (isW ? -1 : 1));
    const isKing = moving.toLowerCase() === 'k';
    const castleKS = isKing && ((from === 'e1' && to === 'g1') || (from === 'e8' && to === 'g8'));
    const castleQS = isKing && ((from === 'e1' && to === 'c1') || (from === 'e8' && to === 'c8'));
    const actualCaptured = epSq != null ? this.board.get(epSq) : captured;

    this.undoStack.push({
      board: new Map(this.board),
      turn: this.turn,
      lastFrom: this.lastFrom,
      lastTo: this.lastTo,
      enPassant: this.enPassant,
      wKing: this.wKing,
      bKing: this.bKing,
      wRa: this.wRa,
      wRh: this.wRh,
      bRa: this.bRa,
      bRh: this.bRh,
      sanHistory: [...this.sanHistory],
      capturedByWhite: [...this.capturedByWhite],
      capturedByBlack: [...this.capturedByBlack],
      isCheck: this.isCheck,
      kingInCheck: this.kingInCheck,
      isCheckmate: this.isCheckmate,
      isStalemate: this.isStalemate,
    });

    if (actualCaptured != null) (isW ? this.capturedByWhite : this.capturedByBlack).push(actualCaptured);
    this.board.delete(from);
    if (epSq != null) this.board.delete(epSq);
    if (castleKS || castleQS) castleRook(this.board, to);

    let placed = moving;
    if (promotion != null) placed = promotion;
    else if (isPawn && (rankOf(to) === 7 || rankOf(to) === 0)) placed = isW ? 'Q' : 'q';
    this.board.set(to, placed);

    if (moving === 'K') this.wKing = true;
    if (moving === 'k') this.bKing = true;
    if (from === 'a1' || to === 'a1') this.wRa = true;
    if (from === 'h1' || to === 'h1') this.wRh = true;
    if (from === 'a8' || to === 'a8') this.bRa = true;
    if (from === 'h8' || to === 'h8') this.bRh = true;

    this.enPassant =
      isPawn && Math.abs(rankOf(to) - rankOf(from)) === 2
        ? square(fileOf(from), Math.floor((rankOf(from) + rankOf(to)) / 2))
        : null;
    this.lastFrom = from;
    this.lastTo = to;
    this.turn = this.turn === 'w' ? 'b' : 'w';

    const nextWhite = this.turn === 'w';
    const nextKing = findKing(this.board, nextWhite);
    const givesCheck = nextKing != null && isSquareAttacked(this.board, nextKing, !nextWhite);
    const isMate = givesCheck && !this.hasAnyLegal(this.turn);
    this.sanHistory.push(toSAN(from, to, moving, actualCaptured ?? null, promotion, givesCheck, isMate, castleKS, castleQS));

    this.selected = null;
    this.legalTargets = new Set();
    this.promotionFrom = null;
    this.promotionTo = null;
    this.updateGameState();
  }

  undo(): boolean {
    const snap = this.undoStack.pop();
    if (!snap) return false;
    Object.assign(this, snap);
    this.selected = null;
    this.legalTargets = new Set();
    this.promotionFrom = null;
    this.promotionTo = null;
    return true;
  }
}

function castleRook(board: Board, kingTo: string) {
  const moves: Record<string, [string, string, string]> = {
    g1: ['h1', 'f1', 'R'],
    c1: ['a1', 'd1', 'R'],
    g8: ['h8', 'f8', 'r'],
    c8: ['a8', 'd8', 'r'],
  };
  const m = moves[kingTo];
  if (!m) return;
  board.delete(m[0]);
  board.set(m[1], m[2]);
}

function toSAN(
  from: string,
  to: string,
  piece: string,
  captured: string | null,
  promo: string | null,
  givesCheck: boolean,
  isMate: boolean,
  castleKS: boolean,
  castleQS: boolean,
) {
  // Flutter checks "+" before "#", so a castling mate reads O-O+ (kept as-is).
  if (castleKS) return givesCheck ? 'O-O+' : isMate ? 'O-O#' : 'O-O';
  if (castleQS) return givesCheck ? 'O-O-O+' : isMate ? 'O-O-O#' : 'O-O-O';
  const isPawn = piece.toLowerCase() === 'p';
  let san = isPawn ? '' : piece.toUpperCase();
  if (captured != null) san += (isPawn ? from[0] : '') + 'x';
  san += to;
  if (promo != null) san += `=${promo.toUpperCase()}`;
  return san + (isMate ? '#' : givesCheck ? '+' : '');
}

export function toPgn(sans: string[]) {
  let out = '';
  sans.forEach((s, i) => (out += i % 2 === 0 ? `${i / 2 + 1}. ${s} ` : `${s} `));
  return out.trim() + (sans.length ? ' *' : '');
}
