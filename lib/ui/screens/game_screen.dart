// lib/ui/screens/game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/clock.dart';
import '../../core/game_state.dart';
import '../../models/move.dart';
import '../../models/piece.dart';
import '../../models/position.dart';
import '../widgets/chess_board.dart';
import 'package:chess_offline/core/time_control.dart';

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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameState _gameState;
  late Clock _clock;
  Position? _selectedSquare;
  List<Move> _legalTargets = [];
  Timer? _gameClockTimer;
  bool _gameOver = false;

  // Per-move clock snapshots for undo time restoration.
  // Each entry stores [whiteRemaining, blackRemaining] before that move was made.
  final List<(Duration, Duration)> _clockSnapshots = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // FIX 2: register lifecycle observer
    _gameState = GameState();
    _clock = Clock(
      whiteTime: widget.whiteTime,
      blackTime: widget.blackTime,
      initialPlayer: PieceColor.white,
    );
    _startGameClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // FIX 2: clean up observer
    _gameClockTimer?.cancel();
    super.dispose();
  }

  // FIX 2: Pause clock when app goes to background, resume when it returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_gameOver) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _gameClockTimer?.cancel();
      _gameClockTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_gameClockTimer == null) {
        _startGameClock();
      }
    }
  }

  String _format(Duration d) {
    if (d == Duration.zero && widget.timeControlMode == TimeControlMode.unlimited) {
      return '--:--';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startGameClock() {
    if (widget.timeControlMode == TimeControlMode.unlimited) return;
    _gameClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _clock.decrement(const Duration(seconds: 1));
      });
      _checkTimeout();
    });
  }

  void _onSquareTap(Position pos) {
    if (_gameOver) return;
    final piece = _gameState.board.pieceAt(pos);

    if (_selectedSquare != null) {
      final matchingMoves = _legalTargets.where((m) => m.to == pos).toList();
      if (matchingMoves.isNotEmpty) {
        _attemptMove(matchingMoves);
        return;
      }
    }

    if (piece != null && piece.color == _gameState.board.turn) {
      setState(() {
        _selectedSquare = pos;
        _legalTargets = _gameState.legalMovesFor(pos);
      });
      return;
    }

    setState(() {
      _selectedSquare = null;
      _legalTargets = [];
    });
  }

  Future<void> _attemptMove(List<Move> matchingMoves) async {
    Move moveToPlay = matchingMoves.first;

    if (matchingMoves.length > 1) {
      final color = matchingMoves.first.piece.color;
      final chosenType = await showPromotionDialog(context, color);
      if (chosenType == null) {
        setState(() {
          _selectedSquare = null;
          _legalTargets = [];
        });
        return;
      }
      moveToPlay = matchingMoves.firstWhere(
        (m) => m.promotionType == chosenType,
        orElse: () => matchingMoves.first,
      );
    }

    // FIX 1: Snapshot the clock BEFORE applying the move so undo can restore it.
    _clockSnapshots.add((_clock.whiteRemaining, _clock.blackRemaining));

    setState(() {
      _gameState.makeMove(moveToPlay);
      _selectedSquare = null;
      _legalTargets = [];
      _clock.switchPlayer();
    });

    _checkTimeout();
    _checkGameOver();
  }

  void _undo() {
    if (!_gameState.canUndo) return;
    setState(() {
      _gameState.undo();
      _selectedSquare = null;
      _legalTargets = [];

      // FIX 1: Restore the clock snapshot from before this move.
      if (_clockSnapshots.isNotEmpty) {
        final snapshot = _clockSnapshots.removeLast();
        _clock.whiteRemaining = snapshot.$1;
        _clock.blackRemaining = snapshot.$2;
        _clock.currentPlayer = _gameState.board.turn;
      }

      // If game was over and player undoes, re-enable play and restart clock.
      if (_gameOver) {
        _gameOver = false;
        _startGameClock();
      }
    });
  }

  void _checkTimeout() {
    if (_gameOver) return; // FIX 3: prevent firing multiple times
    if (widget.timeControlMode == TimeControlMode.unlimited) return;

    final whiteOut = !_clock.hasTimeLeft(PieceColor.white);
    final blackOut = !_clock.hasTimeLeft(PieceColor.black);
    if (!whiteOut && !blackOut) return;

    // FIX 3: Cancel timer BEFORE showing dialog so it can't fire again.
    _gameClockTimer?.cancel();
    _gameClockTimer = null;
    _gameOver = true;

    final loser = whiteOut ? PieceColor.white : PieceColor.black;
    final message = '${loser == PieceColor.white ? "White" : "Black"}\'s time ran out!';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
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

  void _checkGameOver() {
    if (_gameOver) return;
    final result = _gameState.result;
    if (result == GameResult.ongoing) return;

    _gameClockTimer?.cancel();
    _gameClockTimer = null;
    _gameOver = true;

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
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewGame();
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

  void _startNewGame() {
    setState(() {
      _gameState = GameState();
      _selectedSquare = null;
      _legalTargets = [];
      _gameOver = false;
      _clockSnapshots.clear();
      _clock.resetClocks();
      _gameClockTimer?.cancel();
      _startGameClock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final turn = _gameState.board.turn;
    final inCheck = _gameState.isKingInCheck(turn);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'W: ${_format(_clock.whiteRemaining)}',
              style: TextStyle(
                color: _clock.hasTimeLeft(PieceColor.white) || widget.timeControlMode == TimeControlMode.unlimited
                    ? Colors.white
                    : Colors.red,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              'B: ${_format(_clock.blackRemaining)}',
              style: TextStyle(
                color: _clock.hasTimeLeft(PieceColor.black) || widget.timeControlMode == TimeControlMode.unlimited
                    ? Colors.white
                    : Colors.red,
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
           LayoutBuilder(
  builder: (context, constraints) {
    final boardSize = constraints.maxWidth;
    return SizedBox(
      width: boardSize,
      height: boardSize,
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
    );
  },
),
          ],
        ),
      ),
    );
  }
}