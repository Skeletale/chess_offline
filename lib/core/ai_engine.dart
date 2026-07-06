import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/board.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/position.dart';
import 'game_state.dart';

enum AiDifficulty { easy, medium, hard }

// ── Message passed to the isolate ──────────────────────────────
class _AiRequest {
  final Board board;
  final AiDifficulty difficulty;
  const _AiRequest(this.board, this.difficulty);
}

// ── Top-level function required by compute() ───────────────────
Move? _isolateComputeMove(_AiRequest request) {
  return _MinimaxEngine(request.difficulty).getBestMove(request.board);
}

// ── Public API ─────────────────────────────────────────────────
class AiEngine {
  /// Returns the best move for the current side to move on [board],
  /// computed on a separate isolate so the UI stays responsive.
  static Future<Move?> getBestMove(Board board, AiDifficulty difficulty) {
    return compute(_isolateComputeMove, _AiRequest(board.clone(), difficulty));
  }
}

// ── Minimax engine (runs entirely inside the isolate) ──────────
class _MinimaxEngine {
  final AiDifficulty difficulty;
  final Random _rng = Random();

  _MinimaxEngine(this.difficulty);

  int get _depth {
    switch (difficulty) {
      case AiDifficulty.easy:   return 2;
      case AiDifficulty.medium: return 3;
      case AiDifficulty.hard:   return 4;
    }
  }

  Move? getBestMove(Board board) {
    final gs = GameState(board: board);
    final moves = gs.allLegalMoves(board.turn);
    if (moves.isEmpty) return null;

    // Easy mode: 30% chance of a random legal move
    if (difficulty == AiDifficulty.easy && _rng.nextDouble() < 0.3) {
      return moves[_rng.nextInt(moves.length)];
    }

    moves.shuffle(_rng); // shuffle for variety at equal scores

    Move? bestMove;
    int bestScore = -999999;
    int alpha = -999999;
    const int beta = 999999;

    for (final move in moves) {
      final childGs = GameState(board: board.clone());
      childGs.makeMove(move);
      final score = -_negamax(childGs, _depth - 1, -beta, -alpha);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
        if (score > alpha) alpha = score;
      }
    }

    return bestMove;
  }

  int _negamax(GameState gs, int depth, int alpha, int beta) {
    if (depth == 0) return _evaluate(gs.board);

    final moves = gs.allLegalMoves(gs.board.turn);

    if (moves.isEmpty) {
      // No moves: checkmate or stalemate
      return gs.isKingInCheck(gs.board.turn) ? -99000 - depth : 0;
    }

    int best = -999999;
    for (final move in moves) {
      final childGs = GameState(board: gs.board.clone());
      childGs.makeMove(move);
      final score = -_negamax(childGs, depth - 1, -beta, -alpha);
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break; // alpha-beta cutoff
    }
    return best;
  }

  /// Static evaluation from the perspective of the side to move.
  /// Positive = good for the side to move.
  int _evaluate(Board board) {
    int score = 0;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board.pieceAt(Position(r, c));
        if (piece == null) continue;
        final value = _pieceValue(piece.type) + _squareBonus(piece, r, c);
        if (piece.color == board.turn) {
          score += value;
        } else {
          score -= value;
        }
      }
    }
    return score;
  }

  int _pieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn:   return 100;
      case PieceType.knight: return 320;
      case PieceType.bishop: return 330;
      case PieceType.rook:   return 500;
      case PieceType.queen:  return 900;
      case PieceType.king:   return 20000;
    }
  }

  int _squareBonus(Piece piece, int row, int col) {
    // For white: flip row so rank 1 (row 7) maps to table index row 0
    // For black: use row as-is (black advances toward row 7)
    final idx = piece.color == PieceColor.white
        ? (7 - row) * 8 + col
        : row * 8 + col;

    switch (piece.type) {
      case PieceType.pawn:   return _pawnTable[idx];
      case PieceType.knight: return _knightTable[idx];
      case PieceType.bishop: return _bishopTable[idx];
      case PieceType.rook:   return _rookTable[idx];
      case PieceType.queen:  return _queenTable[idx];
      case PieceType.king:   return _kingTable[idx];
    }
  }

  // ── Piece-square tables ──────────────────────────────────────
  static const _pawnTable = [
     0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
     5,  5, 10, 25, 25, 10,  5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5, -5,-10,  0,  0,-10, -5,  5,
     5, 10, 10,-20,-20, 10, 10,  5,
     0,  0,  0,  0,  0,  0,  0,  0,
  ];

  static const _knightTable = [
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
  ];

  static const _bishopTable = [
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
  ];

  static const _rookTable = [
     0,  0,  0,  0,  0,  0,  0,  0,
     5, 10, 10, 10, 10, 10, 10,  5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
     0,  0,  0,  5,  5,  0,  0,  0,
  ];

  static const _queenTable = [
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5,  5,  5,  5,  0,-10,
     -5,  0,  5,  5,  5,  5,  0, -5,
      0,  0,  5,  5,  5,  5,  0, -5,
    -10,  5,  5,  5,  5,  5,  0,-10,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20,
  ];

  static const _kingTable = [
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -10,-20,-20,-20,-20,-20,-20,-10,
     20, 20,  0,  0,  0,  0, 20, 20,
     20, 30, 10,  0,  0, 10, 30, 20,
  ];
}