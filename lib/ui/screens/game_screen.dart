import 'package:flutter/material.dart';
import '../../core/game_state.dart';
import '../../models/move.dart';
import '../../models/piece.dart';
import '../../models/position.dart';
import '../widgets/chess_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState gameState;
  Position? selectedSquare;
  List<Move> legalTargets = [];

  @override
  void initState() {
    super.initState();
    gameState = GameState();
  }

  void _onSquareTap(Position pos) {
    final piece = gameState.board.pieceAt(pos);

    // Case 1: tapping a highlighted legal target -> make the move.
    if (selectedSquare != null) {
      final matchingMoves = legalTargets.where((m) => m.to == pos).toList();
      if (matchingMoves.isNotEmpty) {
        _attemptMove(matchingMoves);
        return;
      }
    }

    // Case 2: tapping a piece of the side to move -> select it.
    if (piece != null && piece.color == gameState.board.turn) {
      setState(() {
        selectedSquare = pos;
        legalTargets = gameState.legalMovesFor(pos);
      });
      return;
    }

    // Case 3: tapping anything else -> deselect.
    setState(() {
      selectedSquare = null;
      legalTargets = [];
    });
  }

  Future<void> _attemptMove(List<Move> matchingMoves) async {
    Move moveToPlay = matchingMoves.first;

    // If multiple matches exist, they're promotion choices -> ask the user.
    if (matchingMoves.length > 1) {
      final color = matchingMoves.first.piece.color;
      final chosenType = await showPromotionDialog(context, color);
      if (chosenType == null) {
        // Dismissed without choosing -> cancel the move.
        setState(() {
          selectedSquare = null;
          legalTargets = [];
        });
        return;
      }
      moveToPlay = matchingMoves.firstWhere((m) => m.promotionType == chosenType);
    }

    setState(() {
      gameState.makeMove(moveToPlay);
      selectedSquare = null;
      legalTargets = [];
    });

    _checkGameOver();
  }

  void _undo() {
    setState(() {
      gameState.undo();
      selectedSquare = null;
      legalTargets = [];
    });
  }

  void _checkGameOver() {
    final result = gameState.result;
    if (result == GameResult.ongoing) return;

    String message;
    switch (result) {
      case GameResult.whiteWins:
        message = 'Checkmate — White wins!';
        break;
      case GameResult.blackWins:
        message = 'Checkmate — Black wins!';
        break;
      case GameResult.drawStalemate:
        message = 'Draw — Stalemate';
        break;
      case GameResult.drawFiftyMove:
        message = 'Draw — 50-move rule';
        break;
      case GameResult.drawRepetition:
        message = 'Draw — Threefold repetition';
        break;
      case GameResult.drawInsufficientMaterial:
        message = 'Draw — Insufficient material';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                gameState = GameState();
                selectedSquare = null;
                legalTargets = [];
              });
            },
            child: const Text('New Game'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final turn = gameState.board.turn;
    final inCheck = gameState.isKingInCheck(turn);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: gameState.canUndo ? _undo : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '${turn == PieceColor.white ? "White" : "Black"} to move'
                '${inCheck ? "  •  CHECK" : ""}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ChessBoard(
                board: gameState.board,
                selectedSquare: selectedSquare,
                legalTargets: legalTargets,
                lastMoveFrom: gameState.board.moveHistory.isNotEmpty
                    ? gameState.board.moveHistory.last.from
                    : null,
                lastMoveTo: gameState.board.moveHistory.isNotEmpty
                    ? gameState.board.moveHistory.last.to
                    : null,
                onSquareTap: _onSquareTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}