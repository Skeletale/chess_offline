import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ai_engine.dart';
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
  final AiDifficulty? aiDifficulty; // null = 2-player mode
  final PieceColor humanColor; // which side the human plays in vs-AI mode

  const GameScreen({
    super.key,
    required this.whiteTime,
    required this.blackTime,
    required this.timeControlMode,
    this.aiDifficulty,
    this.humanColor = PieceColor.white,
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
  bool _isAiThinking = false;

  bool get _isVsAi => widget.aiDifficulty != null;
  PieceColor get _aiColor =>
      widget.humanColor == PieceColor.white ? PieceColor.black : PieceColor.white;

  final List<(Duration, Duration)> _clockSnapshots = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameState = GameState();
    _clock = Clock(
      whiteTime: widget.whiteTime,
      blackTime: widget.blackTime,
      initialPlayer: PieceColor.white,
    );
    _startGameClock();

    // If human plays Black, AI (White) must make the opening move.
    if (_isVsAi && widget.humanColor == PieceColor.black) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerAiMove());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameClockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_gameOver || _isAiThinking) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _gameClockTimer?.cancel();
      _gameClockTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_gameClockTimer == null) _startGameClock();
    }
  }

  String _format(Duration d) {
    if (widget.timeControlMode == TimeControlMode.unlimited) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startGameClock() {
    if (widget.timeControlMode == TimeControlMode.unlimited) return;
    _gameClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _clock.decrement(const Duration(seconds: 1)));
      _checkTimeout();
    });
  }

  void _onSquareTap(Position pos) {
    if (_gameOver || _isAiThinking) return;
    if (_isVsAi && _gameState.board.turn != widget.humanColor) return;

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

    _clockSnapshots.add((_clock.whiteRemaining, _clock.blackRemaining));

    setState(() {
      _gameState.makeMove(moveToPlay);
      _selectedSquare = null;
      _legalTargets = [];
      _clock.switchPlayer();
    });

    _checkTimeout();
    if (_gameOver) return;
    _checkGameOver();
    if (_gameOver) return;

    if (_isVsAi) _triggerAiMove();
  }

  Future<void> _triggerAiMove() async {
    setState(() => _isAiThinking = true);

    // Run the AI computation alongside a minimum 2s delay so the response
    // never feels instant/unnatural, even on Easy/Medium difficulty.
    final results = await Future.wait<dynamic>([
      AiEngine.getBestMove(_gameState.board, widget.aiDifficulty!),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    final move = results[0] as Move?;

    if (!mounted) return;

    if (move != null) {
      _clockSnapshots.add((_clock.whiteRemaining, _clock.blackRemaining));

      setState(() {
        _gameState.makeMove(move);
        _clock.switchPlayer();
        _isAiThinking = false;
      });

      _checkTimeout();
      if (!_gameOver) _checkGameOver();
    } else {
      setState(() => _isAiThinking = false);
    }
  }

  void _undo() {
    if (!_gameState.canUndo || _isAiThinking) return;
    setState(() {
      if (_isVsAi) {
        _gameState.undo();
        if (_clockSnapshots.isNotEmpty) _clockSnapshots.removeLast();

        if (_gameState.canUndo) {
          _gameState.undo();
          if (_clockSnapshots.isNotEmpty) {
            final snapshot = _clockSnapshots.removeLast();
            _clock.whiteRemaining = snapshot.$1;
            _clock.blackRemaining = snapshot.$2;
            _clock.currentPlayer = _gameState.board.turn;
          }
        }
      } else {
        _gameState.undo();
        if (_clockSnapshots.isNotEmpty) {
          final snapshot = _clockSnapshots.removeLast();
          _clock.whiteRemaining = snapshot.$1;
          _clock.blackRemaining = snapshot.$2;
          _clock.currentPlayer = _gameState.board.turn;
        }
      }

      _selectedSquare = null;
      _legalTargets = [];

      if (_gameOver) {
        _gameOver = false;
        _startGameClock();
      }
    });
  }

  void _checkTimeout() {
    if (_gameOver) return;
    if (widget.timeControlMode == TimeControlMode.unlimited) return;

    final whiteOut = !_clock.hasTimeLeft(PieceColor.white);
    final blackOut = !_clock.hasTimeLeft(PieceColor.black);
    if (!whiteOut && !blackOut) return;

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
      _isAiThinking = false;
      _clockSnapshots.clear();
      _clock.resetClocks();
      _gameClockTimer?.cancel();
      _startGameClock();
    });

    if (_isVsAi && widget.humanColor == PieceColor.black) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerAiMove());
    }
  }

  // ---------------------------------------------------------------------
  // Captured pieces — derived from move history, so undo keeps this correct.
  // ---------------------------------------------------------------------

  List<Piece> _capturedPieces(PieceColor color) {
    final captured = <Piece>[];
    for (final move in _gameState.board.moveHistory) {
      if (move.capturedPiece != null && move.capturedPiece!.color == color) {
        captured.add(move.capturedPiece!);
      }
    }
    captured.sort((a, b) => _pieceOrder(b.type) - _pieceOrder(a.type));
    return captured;
  }

  int _pieceOrder(PieceType t) {
    switch (t) {
      case PieceType.queen:  return 5;
      case PieceType.rook:   return 4;
      case PieceType.bishop: return 3;
      case PieceType.knight: return 2;
      case PieceType.pawn:   return 1;
      case PieceType.king:   return 0;
    }
  }

  Widget _capturedRow(PieceColor colorCaptured) {
    final pieces = _capturedPieces(colorCaptured);
    return SizedBox(
      height: 28,
      child: pieces.isEmpty
          ? const SizedBox.shrink()
          : Row(
              children: pieces
                  .map((p) => Text(
                        pieceSymbol(p),
                        style: const TextStyle(fontSize: 22),
                      ))
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final turn = _gameState.board.turn;
    final inCheck = _gameState.isKingInCheck(turn);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D6A4F),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('White',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  _format(_clock.whiteRemaining),
                  style: TextStyle(
                    color: _clock.hasTimeLeft(PieceColor.white) ||
                            widget.timeControlMode == TimeControlMode.unlimited
                        ? Colors.white
                        : Colors.redAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Black',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  _format(_clock.blackRemaining),
                  style: TextStyle(
                    color: _clock.hasTimeLeft(PieceColor.black) ||
                            widget.timeControlMode == TimeControlMode.unlimited
                        ? Colors.white
                        : Colors.redAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: (_gameState.canUndo && !_isAiThinking) ? _undo : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _isAiThinking
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2D6A4F),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AI is thinking...',
                          style: TextStyle(
                              fontSize: 16, fontStyle: FontStyle.italic),
                        ),
                      ],
                    )
                  : Text(
                      '${turn == PieceColor.white ? "White" : "Black"} to move'
                      '${inCheck ? "  •  CHECK" : ""}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
            // Black's captured pieces (white pieces black has taken)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _capturedRow(PieceColor.white),
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
            // White's captured pieces (black pieces white has taken)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _capturedRow(PieceColor.black),
            ),
          ],
        ),
      ),
    );
  }
}