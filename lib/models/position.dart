class Position {
  final int row; // 0–7, 0 = rank 8 (top), 7 = rank 1 (bottom) — internal convention
  final int col; // 0–7, 0 = file a, 7 = file h

  const Position(this.row, this.col);

  bool get isValid => row >= 0 && row <= 7 && col >= 0 && col <= 7;

  /// Converts to algebraic notation, e.g. (0,0) -> "a8"
  String get algebraic {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = (8 - row).toString();
    return '$file$rank';
  }

  /// Parses algebraic notation, e.g. "e4" -> Position
  factory Position.fromAlgebraic(String alg) {
    final file = alg.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(alg.substring(1));
    return Position(8 - rank, file);
  }

  Position offset(int dRow, int dCol) => Position(row + dRow, col + dCol);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => algebraic;
}