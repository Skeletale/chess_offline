import 'piece.dart';
import 'position.dart';

enum SpecialMove { none, castleKingside, castleQueenside, enPassant, promotion }

class Move {
  final Position from;
  final Position to;
  final Piece piece;
  final Piece? capturedPiece;
  final SpecialMove special;
  final PieceType? promotionType; // only set when special == promotion

  const Move({
    required this.from,
    required this.to,
    required this.piece,
    this.capturedPiece,
    this.special = SpecialMove.none,
    this.promotionType,
  });

  bool get isCapture => capturedPiece != null;

  Move copyWith({PieceType? promotionType}) {
    return Move(
      from: from,
      to: to,
      piece: piece,
      capturedPiece: capturedPiece,
      special: special,
      promotionType: promotionType ?? this.promotionType,
    );
  }

  @override
  String toString() {
    final cap = isCapture ? 'x' : '-';
    return '${piece.type.name}${from.algebraic}$cap${to.algebraic}';
  }
}