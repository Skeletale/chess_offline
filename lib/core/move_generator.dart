import '../models/board.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/position.dart';

/// Generates pseudo-legal moves: moves that follow each piece's movement
/// rules, but WITHOUT checking whether the move leaves your own king in check.
/// Legal-move filtering happens in a later step (game_state.dart).
class MoveGenerator {
  static const _diagonalDirections = [
    [-1, -1], [-1, 1], [1, -1], [1, 1],
  ];

  static const _straightDirections = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
  ];

  static const _allDirections = [
    [-1, -1], [-1, 1], [1, -1], [1, 1],
    [-1, 0], [1, 0], [0, -1], [0, 1],
  ];

  /// Returns all pseudo-legal moves for the piece at [pos], or an empty list
  /// if there's no piece there.
  static List<Move> pseudoLegalMovesFor(Board board, Position pos) {
    final piece = board.pieceAt(pos);
    if (piece == null) return [];

    switch (piece.type) {
      case PieceType.pawn:
        return _pawnMoves(board, pos, piece);
      case PieceType.knight:
        return _knightMoves(board, pos, piece);
      case PieceType.bishop:
        return _slidingMoves(board, pos, piece, _diagonalDirections);
      case PieceType.rook:
        return _slidingMoves(board, pos, piece, _straightDirections);
      case PieceType.queen:
        return _slidingMoves(board, pos, piece, _allDirections);
      case PieceType.king:
        return _kingMoves(board, pos, piece);
    }
  }

  static List<Move> _pawnMoves(Board board, Position pos, Piece pawn) {
    final moves = <Move>[];
    final direction = pawn.color == PieceColor.white ? -1 : 1; // white moves toward row 0
    final startRow = pawn.color == PieceColor.white ? 6 : 1;
    final promotionRow = pawn.color == PieceColor.white ? 0 : 7;

    // 1. Single square forward
    final oneForward = pos.offset(direction, 0);
    if (oneForward.isValid && board.pieceAt(oneForward) == null) {
      _addPawnMove(moves, pos, oneForward, pawn, null, promotionRow);

      // 2. Double square forward (only from starting row, only if path clear)
      if (pos.row == startRow) {
        final twoForward = pos.offset(direction * 2, 0);
        if (twoForward.isValid && board.pieceAt(twoForward) == null) {
          moves.add(Move(from: pos, to: twoForward, piece: pawn));
        }
      }
    }

    // 3. Diagonal captures (including en passant)
    for (final dCol in [-1, 1]) {
      final target = pos.offset(direction, dCol);
      if (!target.isValid) continue;

      final occupant = board.pieceAt(target);
      if (occupant != null && occupant.color != pawn.color) {
        _addPawnMove(moves, pos, target, pawn, occupant, promotionRow);
      } else if (occupant == null && board.enPassantTarget == target) {
        // En passant: the captured pawn sits beside the moving pawn, not on the target square.
        final capturedPawnPos = Position(pos.row, target.col);
        final capturedPawn = board.pieceAt(capturedPawnPos);
        moves.add(Move(
          from: pos,
          to: target,
          piece: pawn,
          capturedPiece: capturedPawn,
          special: SpecialMove.enPassant,
        ));
      }
    }

    return moves;
  }

  /// Adds a pawn move, splitting into 4 promotion moves if it lands on the promotion row.
  static void _addPawnMove(
    List<Move> moves,
    Position from,
    Position to,
    Piece pawn,
    Piece? captured,
    int promotionRow,
  ) {
    if (to.row == promotionRow) {
      for (final promo in [
        PieceType.queen,
        PieceType.rook,
        PieceType.bishop,
        PieceType.knight,
      ]) {
        moves.add(Move(
          from: from,
          to: to,
          piece: pawn,
          capturedPiece: captured,
          special: SpecialMove.promotion,
          promotionType: promo,
        ));
      }
    } else {
      moves.add(Move(from: from, to: to, piece: pawn, capturedPiece: captured));
    }
  }

  static List<Move> _knightMoves(Board board, Position pos, Piece knight) {
    final moves = <Move>[];
    const offsets = [
      [-2, -1], [-2, 1],
      [-1, -2], [-1, 2],
      [1, -2], [1, 2],
      [2, -1], [2, 1],
    ];

    for (final o in offsets) {
      final target = pos.offset(o[0], o[1]);
      if (!target.isValid) continue;

      final occupant = board.pieceAt(target);
      if (occupant == null || occupant.color != knight.color) {
        moves.add(Move(from: pos, to: target, piece: knight, capturedPiece: occupant));
      }
    }

    return moves;
  }

  /// Shared logic for bishop, rook, and queen: slide in each direction
  /// until hitting a piece or the board edge.
  static List<Move> _slidingMoves(
    Board board,
    Position pos,
    Piece piece,
    List<List<int>> directions,
  ) {
    final moves = <Move>[];

    for (final dir in directions) {
      var current = pos.offset(dir[0], dir[1]);
      while (current.isValid) {
        final occupant = board.pieceAt(current);
        if (occupant == null) {
          moves.add(Move(from: pos, to: current, piece: piece));
        } else {
          if (occupant.color != piece.color) {
            moves.add(Move(from: pos, to: current, piece: piece, capturedPiece: occupant));
          }
          break; // blocked, whether by enemy (after capture) or own piece
        }
        current = current.offset(dir[0], dir[1]);
      }
    }

    return moves;
  }

  /// King's basic one-square moves, plus castling if legal.
  static List<Move> _kingMoves(Board board, Position pos, Piece king) {
    final moves = <Move>[];

    for (final dir in _allDirections) {
      final target = pos.offset(dir[0], dir[1]);
      if (!target.isValid) continue;

      final occupant = board.pieceAt(target);
      if (occupant == null || occupant.color != king.color) {
        moves.add(Move(from: pos, to: target, piece: king, capturedPiece: occupant));
      }
    }

    moves.addAll(_castlingMoves(board, pos, king));

    return moves;
  }

  /// Generates castling moves if all conditions are met:
  /// - king and rook haven't moved (tracked via board castling-rights flags)
  /// - squares between king and rook are empty
  /// - king is not currently in check
  /// - king does not pass through or land on an attacked square
  static List<Move> _castlingMoves(Board board, Position kingPos, Piece king) {
    final moves = <Move>[];
    final color = king.color;
    final opponent = king.opposite;
    final row = color == PieceColor.white ? 7 : 0;

    // King must be on its original square (e1/e8) for either side.
    if (kingPos.row != row || kingPos.col != 4) return moves;

    final canKingside = color == PieceColor.white
        ? board.whiteCanCastleKingside
        : board.blackCanCastleKingside;
    final canQueenside = color == PieceColor.white
        ? board.whiteCanCastleQueenside
        : board.blackCanCastleQueenside;

    if (!canKingside && !canQueenside) return moves;

    // King can't castle out of check.
    if (isSquareAttacked(board, kingPos, opponent)) return moves;

    if (canKingside) {
      final f = Position(row, 5);
      final g = Position(row, 6);
      final h = Position(row, 7);
      final rook = board.pieceAt(h);

      final pathClear = board.pieceAt(f) == null && board.pieceAt(g) == null;
      final rookInPlace = rook != null && rook.type == PieceType.rook && rook.color == color;

      if (pathClear &&
          rookInPlace &&
          !isSquareAttacked(board, f, opponent) &&
          !isSquareAttacked(board, g, opponent)) {
        moves.add(Move(
          from: kingPos,
          to: g,
          piece: king,
          special: SpecialMove.castleKingside,
        ));
      }
    }

    if (canQueenside) {
      final d = Position(row, 3);
      final c = Position(row, 2);
      final b = Position(row, 1);
      final a = Position(row, 0);
      final rook = board.pieceAt(a);

      final pathClear =
          board.pieceAt(d) == null && board.pieceAt(c) == null && board.pieceAt(b) == null;
      final rookInPlace = rook != null && rook.type == PieceType.rook && rook.color == color;

      if (pathClear &&
          rookInPlace &&
          !isSquareAttacked(board, d, opponent) &&
          !isSquareAttacked(board, c, opponent)) {
        // Note: the b-square doesn't need to be unattacked (king never passes
        // through it), it just needs to be empty (checked above).
        moves.add(Move(
          from: kingPos,
          to: c,
          piece: king,
          special: SpecialMove.castleQueenside,
        ));
      }
    }

    return moves;
  }

  /// Returns true if [square] is attacked by any piece of [byColor].
  /// Used for check detection, castling legality, and (later) legal-move
  /// filtering. Does not generate Move objects — checks attack patterns
  /// directly for efficiency.
  static bool isSquareAttacked(Board board, Position square, PieceColor byColor) {
    // Pawn attacks: a pawn attacks diagonally forward relative to its own color.
    // So to check if `square` is attacked by a pawn, look at the squares a
    // defending pawn of byColor would attack FROM.
    final pawnDir = byColor == PieceColor.white ? 1 : -1; // reverse of pawn's move direction
    for (final dCol in [-1, 1]) {
      final from = square.offset(pawnDir, dCol);
      if (!from.isValid) continue;
      final occupant = board.pieceAt(from);
      if (occupant != null && occupant.type == PieceType.pawn && occupant.color == byColor) {
        return true;
      }
    }

    // Knight attacks
    const knightOffsets = [
      [-2, -1], [-2, 1],
      [-1, -2], [-1, 2],
      [1, -2], [1, 2],
      [2, -1], [2, 1],
    ];
    for (final o in knightOffsets) {
      final from = square.offset(o[0], o[1]);
      if (!from.isValid) continue;
      final occupant = board.pieceAt(from);
      if (occupant != null && occupant.type == PieceType.knight && occupant.color == byColor) {
        return true;
      }
    }

    // King attacks (adjacent squares)
    for (final dir in _allDirections) {
      final from = square.offset(dir[0], dir[1]);
      if (!from.isValid) continue;
      final occupant = board.pieceAt(from);
      if (occupant != null && occupant.type == PieceType.king && occupant.color == byColor) {
        return true;
      }
    }

    // Sliding attacks: bishop/queen on diagonals, rook/queen on straights
    for (final dir in _diagonalDirections) {
      var current = square.offset(dir[0], dir[1]);
      while (current.isValid) {
        final occupant = board.pieceAt(current);
        if (occupant != null) {
          if (occupant.color == byColor &&
              (occupant.type == PieceType.bishop || occupant.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        current = current.offset(dir[0], dir[1]);
      }
    }

    for (final dir in _straightDirections) {
      var current = square.offset(dir[0], dir[1]);
      while (current.isValid) {
        final occupant = board.pieceAt(current);
        if (occupant != null) {
          if (occupant.color == byColor &&
              (occupant.type == PieceType.rook || occupant.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        current = current.offset(dir[0], dir[1]);
      }
    }

    return false;
  }
}
