enum PieceType { pawn, knight, bishop, rook, queen, king }

enum PieceColor { white, black }

class Piece {
  final PieceType type;
  final PieceColor color;

  const Piece({required this.type, required this.color});

  Piece copyWith({PieceType? type, PieceColor? color}) {
    return Piece(
      type: type ?? this.type,
      color: color ?? this.color,
    );
  }

  PieceColor get opposite =>
      color == PieceColor.white ? PieceColor.black : PieceColor.white;

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

  @override
  bool operator ==(Object other) =>
      other is Piece && other.type == type && other.color == color;

  @override
  int get hashCode => Object.hash(type, color);
}