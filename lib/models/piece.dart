// lib/models/piece.dart
// ──────────────────────────────────────────────────────────────
//  Piece – chess piece representation
// ──────────────────────────────────────────────────────────────

/// Defines the type of chess piece (e.g., Pawn, Knight).
enum PieceType { pawn, knight, bishop, rook, queen, king }

/// Defines the colour of a chess piece (White or Black).
enum PieceColor { white, black }

/// Represents a single chess piece on the board.
class Piece {
  final PieceType type;
  final PieceColor color;

  /// Creates a new `Piece` instance.
  const Piece({
    required this.type,
    required this.color,
  });

  /// Returns the opposite colour of this piece.
  PieceColor get opposite =>
      color == PieceColor.white ? PieceColor.black : PieceColor.white;

  /// Creates a copy of this piece, but with the given fields replaced.
  Piece copyWith({PieceType? type, PieceColor? color}) {
    return Piece(
      type: type ?? this.type,
      color: color ?? this.color,
    );
  }

  /// Returns a string representation of the piece (e.g., "P" for white pawn, "k" for black king).
  @override
  String toString() {
    final symbol = {
      PieceType.pawn: 'P',
      PieceType.knight: 'N',
      PieceType.bishop: 'B',
      PieceType.rook: 'R',
      PieceType.queen: 'Q',
      PieceType.king: 'K',
    }[type]!;
    return color == PieceColor.white ? symbol : symbol.toLowerCase();
  }

  /// Checks if two `Piece` objects are equal (same type and same colour).
  @override
  bool operator ==(Object other) =>
      other is Piece && other.type == type && other.color == color;

  /// Generates a hash code for the `Piece` object based on its type and colour.
  @override
  int get hashCode => Object.hash(type, color);
}