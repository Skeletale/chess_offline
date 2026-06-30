// ──────────────────────────────────────────────────────────────
//  Entry point – now launches the SetupScreen instead of GameScreen
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'ui/screens/setup_screen.dart';

void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Chess',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const SetupScreen(),
    );
  }
}