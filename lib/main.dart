import 'package:flutter/material.dart';
import 'ui/screens/game_screen.dart';

void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Chess',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const GameScreen(),
    );
  }
}