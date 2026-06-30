import '../models/board.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/position.dart';
import 'move_generator.dart';

enum GameResult {
  ongoing,
  whiteWins,
  blackWins,
  drawStalemate,
  drawFiftyMove,
  drawRepetition,
  drawInsufficientMaterial,
}

/// Wraps a Board and provides legal-move generation, check/checkmate/
/// stalemate detection, move application (including special moves), undo,
/// and draw-rule detection.
class GameState {
  Board board;

  /// Stack of board snapshots taken before each move, used for undo.
  final List<Board> _history = [];

  /// Position keys (piece placement + turn + castling rights + en passant)
  /// used for threefold repetition detection.
  final List<String> _positionKeys = [];

  GameState({Board? board}) : board = board ?? Board.initial() {
    _positionKeys.add(_positionKey(this.board));
  }

  // ---------------------------------------------------------------------
  // Legal move generation
  // ---------------------------------------------------------------------

  /// All legal moves for the piece at [pos] — pseudo-legal moves filtered
  /// to exclude any that leave the mover's own king in check.
  List<Move> legalMovesFor(Position pos) {
    final piece = board.pieceAt(pos);
    if (piece == null) return [];

    final pseudoMoves = MoveGenerator.pseudoLegalMovesFor(board, pos);
    return pseudoMoves.where((move) => !_leavesKingInCheck(move, piece.color)).toList();
  }

  /// All legal moves for every piece of [color].
  List<Move> allLegalMoves(PieceColor color) {
    final moves = <Move>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final pos = Position(r, c);
        final piece = board.pieceAt(pos);
        if (piece != null && piece.color == color) {
          moves.addAll(legalMovesFor(pos));
        }
      }
    }
    return moves;
  }

  /// Simulates [move] on a cloned board and checks if it leaves the king
  /// of [color] in check. Used to filter pseudo-legal moves down to legal.
  bool _leavesKingInCheck(Move move, PieceColor color) {
    final simulated = board.clone();
    _applyMoveToBoard(simulated, move);
    final kingPos = simulated.findKing(color);
    if (kingPos == null) return false; // shouldn't happen
    return MoveGenerator.isSquareAttacked(simulated, kingPos, color == PieceColor.white ? PieceColor.black : PieceColor.white);
  }

  // ---------------------------------------------------------------------
  // Check / checkmate / stalemate
  // ---------------------------------------------------------------------

  bool isKingInCheck(PieceColor color) {
    final kingPos = board.findKing(color);
    if (kingPos == null) return false;
    final opponent = color == PieceColor.white ? PieceColor.black : PieceColor.white;
    return MoveGenerator.isSquareAttacked(board, kingPos, opponent);
  }

  bool isCheckmate(PieceColor color) {
    return isKingInCheck(color) && allLegalMoves(color).isEmpty;
  }

  bool isStalemate(PieceColor color) {
    return !isKingInCheck(color) && allLegalMoves(color).isEmpty;
  }

  // ---------------------------------------------------------------------
  // Draw conditions
  // ---------------------------------------------------------------------

  bool get isFiftyMoveRule => board.halfmoveClock >= 100; // 50 full moves = 100 half-moves

  bool get isThreefoldRepetition {
    final current = _positionKeys.last;
    final count = _positionKeys.where((k) => k == current).length;
    return count >= 3;
  }

  bool get isInsufficientMaterial {
    final pieces = <Piece>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board.pieceAt(Position(r, c));
        if (p != null) pieces.add(p);
      }
    }

    final nonKingPieces = pieces.where((p) => p.type != PieceType.king).toList();

    // King vs King
    if (nonKingPieces.isEmpty) return true;

    // King + single minor piece (bishop or knight) vs King
    if (nonKingPieces.length == 1 &&
        (nonKingPieces[0].type == PieceType.bishop || nonKingPieces[0].type == PieceType.knight)) {
      return true;
    }

    // King + bishop vs King + bishop, same-colored bishops
    if (nonKingPieces.length == 2 &&
        nonKingPieces.every((p) => p.type == PieceType.bishop) &&
        nonKingPieces[0].color != nonKingPieces[1].color) {
      // Need their squares to check same-color-square bishops; find positions.
      final bishopPositions = <Position>[];
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final p = board.pieceAt(Position(r, c));
          if (p != null && p.type == PieceType.bishop) bishopPositions.add(Position(r, c));
        }
      }
      if (bishopPositions.length == 2) {
        final sameSquareColor =
            (bishopPositions[0].row + bishopPositions[0].col) % 2 ==
            (bishopPositions[1].row + bishopPositions[1].col) % 2;
        if (sameSquareColor) return true;
      }
    }

    return false;
  }

  /// Computes the current game result. Call after each move.
  GameResult get result {
    final sideToMove = board.turn;

    if (isCheckmate(sideToMove)) {
      return sideToMove == PieceColor.white ? GameResult.blackWins : GameResult.whiteWins;
    }
    if (isStalemate(sideToMove)) return GameResult.drawStalemate;
    if (isFiftyMoveRule) return GameResult.drawFiftyMove;
    if (isThreefoldRepetition) return GameResult.drawRepetition;
    if (isInsufficientMaterial) return GameResult.drawInsufficientMaterial;

    return GameResult.ongoing;
  }

  bool get isGameOver => result != GameResult.ongoing;

  // ---------------------------------------------------------------------
  // Making moves
  // ---------------------------------------------------------------------

  /// Applies [move] to the live board, updating turn, castling rights,
  /// en passant target, halfmove clock, and move history. Saves a snapshot
  /// for undo.
  void makeMove(Move move) {
    _history.add(board.clone());
    _applyMoveToBoard(board, move);
    board.moveHistory.add(move);
    _positionKeys.add(_positionKey(board));
  }

  /// Reverts the most recent move, if any. Returns the undone move, or null
  /// if there was nothing to undo.
  Move? undo() {
    if (_history.isEmpty) return null;
    board = _history.removeLast();
    _positionKeys.removeLast();
    return board.moveHistory.isNotEmpty ? board.moveHistory.last : null;
  }

  bool get canUndo => _history.isNotEmpty;

  /// Core move application logic, shared by makeMove and the check-simulation
  /// path. Mutates [b] directly — caller is responsible for cloning first
  /// if the original must be preserved.
  void _applyMoveToBoard(Board b, Move move) {
    final piece = move.piece;
    final movingColor = piece.color;

    // Reset or increment halfmove clock (resets on pawn move or capture).
    if (piece.type == PieceType.pawn || move.isCapture) {
      b.halfmoveClock = 0;
    } else {
      b.halfmoveClock++;
    }

    // Handle en passant capture: remove the captured pawn (it's not on `to`).
    if (move.special == SpecialMove.enPassant) {
      final capturedPawnPos = Position(move.from.row, move.to.col);
      b.setPieceAt(capturedPawnPos, null);
    }

    // Move the piece.
    b.setPieceAt(move.from, null);
    if (move.special == SpecialMove.promotion && move.promotionType != null) {
      b.setPieceAt(move.to, Piece(type: move.promotionType!, color: movingColor));
    } else {
      b.setPieceAt(move.to, piece);
    }

    // Handle castling: move the rook too.
    if (move.special == SpecialMove.castleKingside) {
      final row = move.from.row;
      final rook = b.pieceAt(Position(row, 7));
      b.setPieceAt(Position(row, 7), null);
      b.setPieceAt(Position(row, 5), rook);
    } else if (move.special == SpecialMove.castleQueenside) {
      final row = move.from.row;
      final rook = b.pieceAt(Position(row, 0));
      b.setPieceAt(Position(row, 0), null);
      b.setPieceAt(Position(row, 3), rook);
    }

    // Update castling rights if king or rook moved, or a rook was captured.
    if (piece.type == PieceType.king) {
      if (movingColor == PieceColor.white) {
        b.whiteCanCastleKingside = false;
        b.whiteCanCastleQueenside = false;
      } else {
        b.blackCanCastleKingside = false;
        b.blackCanCastleQueenside = false;
      }
    }
    _updateCastlingRightsForRookMove(b, move.from);
    _updateCastlingRightsForRookMove(b, move.to);

    // Update en passant target: only set if this was a pawn double-step.
    if (piece.type == PieceType.pawn && (move.to.row - move.from.row).abs() == 2) {
      final midRow = (move.to.row + move.from.row) ~/ 2;
      b.enPassantTarget = Position(midRow, move.from.col);
    } else {
      b.enPassantTarget = null;
    }

    // Flip turn.
    b.turn = movingColor == PieceColor.white ? PieceColor.black : PieceColor.white;
  }

  /// If a rook moves away from or is captured on its home square, that
  /// side loses castling rights for that side.
  void _updateCastlingRightsForRookMove(Board b, Position pos) {
    if (pos.row == 7 && pos.col == 0) b.whiteCanCastleQueenside = false;
    if (pos.row == 7 && pos.col == 7) b.whiteCanCastleKingside = false;
    if (pos.row == 0 && pos.col == 0) b.blackCanCastleQueenside = false;
    if (pos.row == 0 && pos.col == 7) b.blackCanCastleKingside = false;
  }

  // ---------------------------------------------------------------------
  // Position key for repetition detection
  // ---------------------------------------------------------------------

  String _positionKey(Board b) {
    final buffer = StringBuffer();
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = b.pieceAt(Position(r, c));
        buffer.write(p == null ? '.' : p.toString());
      }
    }
    buffer.write('|${b.turn.name}');
    buffer.write('|${b.whiteCanCastleKingside}${b.whiteCanCastleQueenside}');
    buffer.write('${b.blackCanCastleKingside}${b.blackCanCastleQueenside}');
    buffer.write('|${b.enPassantTarget?.algebraic ?? "-"}');
    return buffer.toString();
  }
}