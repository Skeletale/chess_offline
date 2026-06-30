import 'piece.dart';
import 'position.dart';
import 'move.dart';

class Board {
  // 8x8 grid, board[row][col]. null = empty square.
  late List<List<Piece?>> squares;

  PieceColor turn;

  // Castling rights
  bool whiteCanCastleKingside;
  bool whiteCanCastleQueenside;
  bool blackCanCastleKingside;
  bool blackCanCastleQueenside;

  // En passant target square (the square a pawn can capture into, if any)
  Position? enPassantTarget;

  // Halfmove clock for 50-move rule (resets on pawn move or capture)
  int halfmoveClock;

  // Full move history, used for undo and repetition detection
  final List<Move> moveHistory;

  Board({
    List<List<Piece?>>? squares,
    this.turn = PieceColor.white,
    this.whiteCanCastleKingside = true,
    this.whiteCanCastleQueenside = true,
    this.blackCanCastleKingside = true,
    this.blackCanCastleQueenside = true,
    this.enPassantTarget,
    this.halfmoveClock = 0,
    List<Move>? moveHistory,
  })  : moveHistory = moveHistory ?? [],
        squares = squares ?? _emptyGrid();

  static List<List<Piece?>> _emptyGrid() {
    return List.generate(8, (_) => List<Piece?>.filled(8, null));
  }

  /// Creates a board set up in the standard starting chess position.
  factory Board.initial() {
    final board = Board();
    final backRank = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];

    for (int col = 0; col < 8; col++) {
      // Black back rank (row 0) and pawns (row 1)
      board.squares[0][col] =
          Piece(type: backRank[col], color: PieceColor.black);
      board.squares[1][col] = Piece(
        type: PieceType.pawn,
        color: PieceColor.black,
      );

      // White pawns (row 6) and back rank (row 7)
      board.squares[6][col] = Piece(
        type: PieceType.pawn,
        color: PieceColor.white,
      );
      board.squares[7][col] =
          Piece(type: backRank[col], color: PieceColor.white);
    }

    return board;
  }

  Piece? pieceAt(Position pos) {
    if (!pos.isValid) return null;
    return squares[pos.row][pos.col];
  }

  void setPieceAt(Position pos, Piece? piece) {
    squares[pos.row][pos.col] = piece;
  }

  /// Finds the king's position for the given color.
  Position? findKing(PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = squares[r][c];
        if (p != null && p.type == PieceType.king && p.color == color) {
          return Position(r, c);
        }
      }
    }
    return null; // shouldn't happen in a valid game
  }

  /// Deep copy of the board — needed for move simulation (check testing) and AI search.
  Board clone() {
    return Board(
      squares: List.generate(
        8,
        (r) => List<Piece?>.generate(8, (c) => squares[r][c]),
      ),
      turn: turn,
      whiteCanCastleKingside: whiteCanCastleKingside,
      whiteCanCastleQueenside: whiteCanCastleQueenside,
      blackCanCastleKingside: blackCanCastleKingside,
      blackCanCastleQueenside: blackCanCastleQueenside,
      enPassantTarget: enPassantTarget,
      halfmoveClock: halfmoveClock,
      moveHistory: List.from(moveHistory),
    );
  }

  /// Simple text representation for debugging (prints to console).
  String toAscii() {
    final buffer = StringBuffer();
    for (int r = 0; r < 8; r++) {
      buffer.write('${8 - r} ');
      for (int c = 0; c < 8; c++) {
        final p = squares[r][c];
        buffer.write(p == null ? '. ' : '${p.toString()} ');
      }
      buffer.writeln();
    }
    buffer.writeln('  a b c d e f g h');
    return buffer.toString();
  }
}