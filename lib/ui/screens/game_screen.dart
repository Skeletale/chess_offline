// lib/ui/screens/game_screen.dart
// ──────────────────────────────────────────────────────────────
//  GameScreen – shows the board and the two clocks
// ──────────────────────────────────────────────────────────────
import 'dart:async'; // NEW: Required for Timer
import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../core/game_state.dart';
import '../../models/move.dart';
import '../../models/piece.dart';
import '../../models/position.dart';
import '../widgets/chess_board.dart';
import 'package:chess_offline/core/time_control.dart'; // Import the enum

class GameScreen extends StatefulWidget {
  final Duration whiteTime;
  final Duration blackTime;
  final TimeControlMode timeControlMode;

  const GameScreen({
    super.key,
    required this.whiteTime,
    required this.blackTime,
    required this.timeControlMode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _gameState;
  late Clock _clock;
  Position? _selectedSquare;
  List<Move> _legalTargets = [];
  Stopwatch? _moveTimer = Stopwatch(); // Measures time for individual moves
  Timer? _gameClockTimer; // NEW: The main timer for decrementing game time

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _clock = Clock(
      whiteTime: widget.whiteTime,
      blackTime: widget.blackTime,
      initialPlayer: PieceColor.white, // White starts
    );
    _moveTimer?.start(); // Start the move timer
    _startGameClock(); // NEW: Start the main game clock
  }

  @override
  void dispose() {
    _moveTimer?.stop(); // Stop the move timer
    _moveTimer = null;
    _gameClockTimer?.cancel(); // NEW: Cancel the game clock timer
    super.dispose();
  }

  /// Helper – formats a [Duration] as `mm:ss`.
  String _format(Duration d) {
    if (d == Duration.zero) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // NEW: Starts the main game clock
  void _startGameClock() {
    if (widget.timeControlMode == TimeControlMode.unlimited) {
      return; // No timer for unlimited mode
    }
    _gameClockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _clock.decrement(const Duration(seconds: 1));
        _checkTimeout(); // Check for timeout every second
      });
    });
  }

  void _onSquareTap(Position pos) {
    final piece = _gameState.board.pieceAt(pos);

    // Case 1: Tapping a highlighted legal target -> make the move.
    if (_selectedSquare != null) {
      final matchingMoves = _legalTargets.where((m) => m.to == pos).toList();
      if (matchingMoves.isNotEmpty) {
        _attemptMove(matchingMoves);
        return;
      }
    }

    // Case 2: Tapping a piece of the side to move -> select it.
    if (piece != null && piece.color == _gameState.board.turn) {
      setState(() {
        _selectedSquare = pos;
        _legalTargets = _gameState.legalMovesFor(pos);
      });
      return;
    }

    // Case 3: Tapping anything else -> deselect.
    setState(() {
      _selectedSquare = null;
      _legalTargets = [];
    });
  }

  Future<void> _attemptMove(List<Move> matchingMoves) async {
    Move moveToPlay = matchingMoves.first; // Default to the first move

    // Handle promotion choices
    if (matchingMoves.length > 1) {
      final color = matchingMoves.first.piece.color;
      final chosenType = await showPromotionDialog(context, color);
      if (chosenType == null) {
        // Cancel the move if the dialog was dismissed
        setState(() {
          _selectedSquare = null;
          _legalTargets = [];
        });
        return;
      }
      // Find the specific move that matches the chosen promotion type
      moveToPlay = matchingMoves.firstWhere((m) => m.promotionType == chosenType, orElse: () => matchingMoves.first);
    }

    setState(() {
      _gameState.makeMove(moveToPlay);
      _selectedSquare = null;
      _legalTargets = [];

      // Switch to the other player's turn and clock
      _clock.switchPlayer();
      _moveTimer?.reset(); // Reset move timer for the next player's move
      _moveTimer?.start(); // Start timer for the next move
    });

    _checkTimeout();
    _checkGameOver();
  }

  void _checkTimeout() {
    // If time controls are active and a player's time runs out
    if (widget.timeControlMode != TimeControlMode.unlimited) {
      if (!_clock.hasTimeLeft(PieceColor.white) || !_clock.hasTimeLeft(PieceColor.black)) {
        // Game over due to timeout
        _gameClockTimer?.cancel(); // Stop the clock on timeout
        _moveTimer?.stop();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Game Over'),
            content: Text('${_clock.currentPlayer == PieceColor.white ? "White" : "Black"}\'s time ran out!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startNewGame(); // Start a new game
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
    }
  }

  void _undo() {
    setState(() {
      _gameState.undo();
      _selectedSquare = null;
      _legalTargets = [];
      // TODO: Restore time for undone move here if needed
    });
  }

  void _startNewGame() {
    setState(() {
      _gameState = GameState(); // Reset game state
      _selectedSquare = null;
      _legalTargets = [];
      _clock.resetClocks(); // Reset clocks
      _moveTimer?.reset(); // Reset move timer
      _moveTimer?.start();
      _gameClockTimer?.cancel(); // Cancel old timer
      _startGameClock(); // Start new game clock
    });
  }

  void _checkGameOver() {
    final result = _gameState.result;
    if (result == GameResult.ongoing) return;

    _gameClockTimer?.cancel(); // Stop the clock on game over
    _moveTimer?.stop();

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
        return; // Should not happen
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _startNewGame(); // Start a new game
            },
            child: const Text('New Game'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Close dialog
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final turn = _gameState.board.turn;
    final inCheck = _gameState.isKingInCheck(turn);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // White Clock Display
            Text(
              'White: ${_format(_clock.whiteRemaining)}',
              style: TextStyle(
                color: _clock.hasTimeLeft(PieceColor.white) ? Colors.white : Colors.red,
              ),
            ),
            const SizedBox(width: 20),
            // Black Clock Display
            Text(
              'Black: ${_format(_clock.blackRemaining)}',
              style: TextStyle(
                color: _clock.hasTimeLeft(PieceColor.black) ? Colors.white : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _gameState.canUndo ? _undo : null,
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
            Expanded(
              child: ChessBoard(
                board: _gameState.board,
                selectedSquare: _selectedSquare,
                legalTargets: _legalTargets,
                lastMoveFrom: _gameState.board.moveHistory.isNotEmpty
                    ? _gameState.board.moveHistory.last.from
                    : null,
                lastMoveTo: _gameState.board.moveHistory.isNotEmpty
                    ? _gameState.board.moveHistory.last.to
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