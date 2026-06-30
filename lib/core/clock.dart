// lib/core/clock.dart
// ──────────────────────────────────────────────────────────────
//  Clock – simple container for the two players’ remaining times
// ──────────────────────────────────────────────────────────────
import '../models/piece.dart';

class Clock {
  final Duration whiteTime;   // total time for White
  final Duration blackTime;   // total time for Black
  Duration whiteRemaining;    // will be updated as the game progresses
  Duration blackRemaining;    // will be updated as the game progresses
  PieceColor currentPlayer;   // whose turn it is (starts as White)

  Clock({
    required this.whiteTime,
    required this.blackTime,
    PieceColor initialPlayer = PieceColor.white,
  })  : whiteRemaining = whiteTime,
        blackRemaining = blackTime,
        currentPlayer = initialPlayer;

  /// Factory that creates an “unlimited” clock (both sides have 0 seconds).
  factory Clock.unlimited() => Clock(
        whiteTime: Duration.zero,
        blackTime: Duration.zero,
        initialPlayer: PieceColor.white,
      );

  /// Switches the turn to the other player.
  void switchPlayer() {
    currentPlayer = currentPlayer == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;
  }

  /// Decrements the current player's remaining time by [amount].
  void decrement(Duration amount) {
    if (currentPlayer == PieceColor.white) {
      whiteRemaining -= amount;
      if (whiteRemaining < Duration.zero) {
        whiteRemaining = Duration.zero; // Prevent negative time
      }
    } else {
      blackRemaining -= amount;
      if (blackRemaining < Duration.zero) {
        blackRemaining = Duration.zero; // Prevent negative time
      }
    }
  }

  /// Resets both players' clocks to their initial total times.
  void resetClocks() {
    whiteRemaining = whiteTime;
    blackRemaining = blackTime;
    currentPlayer = PieceColor.white; // Always reset to White's turn
  }

  /// Returns true if the given colour still has time left.
  bool hasTimeLeft(PieceColor colour) {
    final remaining = colour == PieceColor.white
        ? whiteRemaining
        : blackRemaining;
    return remaining > Duration.zero;
  }
}