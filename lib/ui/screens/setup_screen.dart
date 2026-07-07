import 'package:flutter/material.dart';
import 'package:chess_offline/core/ai_engine.dart';
import 'package:chess_offline/core/theme_storage.dart';
import 'package:chess_offline/core/time_control.dart';
import 'package:chess_offline/models/board_theme.dart';
import 'package:chess_offline/models/piece.dart';
import 'game_screen.dart';

enum GameMode { twoPlayer, vsAi }

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  GameMode? _gameMode;
  AiDifficulty? _difficulty;
  PieceColor? _playerColor;
  TimeControlMode? _timeControl;
  BoardTheme _boardTheme = BoardTheme.classicGreen;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final saved = await ThemeStorage.loadTheme();
    setState(() => _boardTheme = saved);
  }

  bool get _canStart {
    if (_gameMode == null || _timeControl == null) return false;
    if (_gameMode == GameMode.vsAi && (_difficulty == null || _playerColor == null)) {
      return false;
    }
    return true;
  }

  void _startGame() {
    final mode = _timeControl!;
    Duration getDuration() {
      switch (mode) {
        case TimeControlMode.fiveMinutes:  return const Duration(minutes: 5);
        case TimeControlMode.tenMinutes:   return const Duration(minutes: 10);
        case TimeControlMode.unlimited:    return Duration.zero;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          whiteTime: getDuration(),
          blackTime: getDuration(),
          timeControlMode: mode,
          aiDifficulty: _gameMode == GameMode.vsAi ? _difficulty : null,
          humanColor: _gameMode == GameMode.vsAi ? _playerColor! : PieceColor.white,
          boardTheme: _boardTheme,
        ),
      ),
    );
  }

  Future<void> _openThemePicker() async {
    final chosen = await showDialog<BoardTheme>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Board Theme'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: BoardTheme.all.length,
              itemBuilder: (context, index) {
                final theme = BoardTheme.all[index];
                final isSelected = theme.name == _boardTheme.name;
                return ListTile(
                  onTap: () => Navigator.of(context).pop(theme),
                  leading: _ThemeSwatch(theme: theme),
                  title: Text(theme.name),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF2D6A4F))
                      : null,
                );
              },
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      setState(() => _boardTheme = chosen);
      await ThemeStorage.saveTheme(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Game'),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Board Theme',
            onPressed: _openThemePicker,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Game Mode'),
            const SizedBox(height: 12),
            _choiceRow([
              _ChoiceButton(
                label: '2 Player',
                selected: _gameMode == GameMode.twoPlayer,
                onTap: () => setState(() {
                  _gameMode = GameMode.twoPlayer;
                  _difficulty = null;
                  _playerColor = null;
                }),
              ),
              _ChoiceButton(
                label: 'vs AI',
                selected: _gameMode == GameMode.vsAi,
                onTap: () => setState(() => _gameMode = GameMode.vsAi),
              ),
            ]),

            if (_gameMode == GameMode.vsAi) ...[
              const SizedBox(height: 28),
              _sectionTitle('AI Difficulty'),
              const SizedBox(height: 12),
              _choiceRow([
                _ChoiceButton(
                  label: 'Easy',
                  selected: _difficulty == AiDifficulty.easy,
                  onTap: () => setState(() => _difficulty = AiDifficulty.easy),
                ),
                _ChoiceButton(
                  label: 'Medium',
                  selected: _difficulty == AiDifficulty.medium,
                  onTap: () => setState(() => _difficulty = AiDifficulty.medium),
                ),
                _ChoiceButton(
                  label: 'Hard',
                  selected: _difficulty == AiDifficulty.hard,
                  onTap: () => setState(() => _difficulty = AiDifficulty.hard),
                ),
              ]),

              const SizedBox(height: 28),
              _sectionTitle('Play As'),
              const SizedBox(height: 12),
              _choiceRow([
                _ChoiceButton(
                  label: 'White',
                  selected: _playerColor == PieceColor.white,
                  onTap: () => setState(() => _playerColor = PieceColor.white),
                ),
                _ChoiceButton(
                  label: 'Black',
                  selected: _playerColor == PieceColor.black,
                  onTap: () => setState(() => _playerColor = PieceColor.black),
                ),
              ]),
            ],

            const SizedBox(height: 28),
            _sectionTitle('Time Control'),
            const SizedBox(height: 12),
            _choiceRow([
              _ChoiceButton(
                label: '∞',
                selected: _timeControl == TimeControlMode.unlimited,
                onTap: () => setState(() => _timeControl = TimeControlMode.unlimited),
              ),
              _ChoiceButton(
                label: '5 min',
                selected: _timeControl == TimeControlMode.fiveMinutes,
                onTap: () => setState(() => _timeControl = TimeControlMode.fiveMinutes),
              ),
              _ChoiceButton(
                label: '10 min',
                selected: _timeControl == TimeControlMode.tenMinutes,
                onTap: () => setState(() => _timeControl = TimeControlMode.tenMinutes),
              ),
            ]),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _canStart ? _startGame : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Start Game'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
  );

  Widget _choiceRow(List<Widget> choices) => Row(
    children: choices
        .map((c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              ),
            ))
        .toList(),
  );
}

class _ThemeSwatch extends StatelessWidget {
  final BoardTheme theme;

  const _ThemeSwatch({required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: ColoredBox(color: theme.lightSquare)),
                Expanded(child: ColoredBox(color: theme.darkSquare)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: ColoredBox(color: theme.darkSquare)),
                Expanded(child: ColoredBox(color: theme.lightSquare)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D6A4F) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF2D6A4F) : Colors.grey.shade400,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}