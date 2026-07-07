// ──────────────────────────────────────────────────────────────
//  Entry point – launches the SetupScreen, preloads sound effects
// ──────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'core/sound_manager.dart';
import 'ui/screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundManager.init();
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