import 'package:flutter/material.dart';
import '../../models/board.dart';
import '../../models/board_theme.dart';
import '../../models/move.dart';
import '../../models/piece.dart';
import '../../models/position.dart';

const Map<PieceType, String> _whiteSymbols = {
  PieceType.king: '♔',
  PieceType.queen: '♕',
  PieceType.rook: '♖',
  PieceType.bishop: '♗',
  PieceType.knight: '♘',
  PieceType.pawn: '♙',
};

const Map<PieceType, String> _blackSymbols = {
  PieceType.king: '♚',
  PieceType.queen: '♛',
  PieceType.rook: '♜',
  PieceType.bishop: '♝',
  PieceType.knight: '♞',
  PieceType.pawn: '♟',
};

String pieceSymbol(Piece piece) {
  final map = piece.color == PieceColor.white ? _whiteSymbols : _blackSymbols;
  return map[piece.type]!;
}

class ChessBoard extends StatelessWidget {
  final Board board;
  final BoardTheme theme;
  final Position? selectedSquare;
  final List<Move> legalTargets;
  final Position? lastMoveFrom;
  final Position? lastMoveTo;
  final void Function(Position pos) onSquareTap;

  const ChessBoard({
    super.key,
    required this.board,
    required this.theme,
    required this.onSquareTap,
    this.selectedSquare,
    this.legalTargets = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: List.generate(8, (row) {
          return Expanded(
            child: Row(
              children: List.generate(8, (col) {
                final pos = Position(row, col);
                return Expanded(child: _buildSquare(pos));
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSquare(Position pos) {
    final isDark = (pos.row + pos.col) % 2 == 1;
    final baseColor = isDark ? theme.darkSquare : theme.lightSquare;

    final isSelected = selectedSquare == pos;
    final isLastMove = pos == lastMoveFrom || pos == lastMoveTo;
    final legalMoveHere = legalTargets.where((m) => m.to == pos).toList();
    final isLegalTarget = legalMoveHere.isNotEmpty;
    final isCapture = isLegalTarget && legalMoveHere.first.isCapture;

    Color squareColor = baseColor;
    if (isSelected) {
      squareColor = theme.selectedSquare;
    } else if (isLastMove) {
      squareColor = isDark ? theme.lastMoveDark : theme.lastMoveLight;
    }

    final piece = board.pieceAt(pos);

    return GestureDetector(
      onTap: () => onSquareTap(pos),
      child: SizedBox.expand(
        child: ColoredBox(
          color: squareColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (piece != null)
                Center(
                  child: Text(
                    pieceSymbol(piece),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              if (isLegalTarget && piece == null)
                Center(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (isCapture)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withOpacity(0.4),
                      width: 3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<PieceType?> showPromotionDialog(BuildContext context, PieceColor color) {
  return showDialog<PieceType>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final options = [
        PieceType.queen,
        PieceType.rook,
        PieceType.bishop,
        PieceType.knight,
      ];
      return AlertDialog(
        title: const Text('Promote pawn to:'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.map((type) {
            final symbol =
                (color == PieceColor.white ? _whiteSymbols : _blackSymbols)[type]!;
            return IconButton(
              iconSize: 36,
              onPressed: () => Navigator.of(context).pop(type),
              icon: Text(symbol, style: const TextStyle(fontSize: 36)),
            );
          }).toList(),
        ),
      );
    },
  );
}