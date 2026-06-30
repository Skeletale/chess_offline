// ──────────────────────────────────────────────────────────────
//  SetupScreen – lets the user pick a time‑control mode
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:chess_offline/core/clock.dart';
import 'package:chess_offline/ui/screens/game_screen.dart';
import 'package:chess_offline/core/time_control.dart';


// ──────────────────────────────────────────────────────────────

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  void _startGame(BuildContext context, TimeControlMode mode) {
    Duration getDuration() {
      switch (mode) {
        case TimeControlMode.fiveMinutes:
          return const Duration(minutes: 5);
        case TimeControlMode.tenMinutes:
          return const Duration(minutes: 10);
        case TimeControlMode.unlimited:
          return Duration.zero;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          whiteTime: getDuration(),
          blackTime: getDuration(),
          timeControlMode: mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Game')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Time Control',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 30),
            _buildOption(context, TimeControlMode.unlimited, 'Unlimited'),
            _buildOption(context, TimeControlMode.fiveMinutes, '5 Minutes'),
            _buildOption(context, TimeControlMode.tenMinutes, '10 Minutes'),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, TimeControlMode mode, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: () => _startGame(context, mode),
        child: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}