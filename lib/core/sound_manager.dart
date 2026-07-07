import 'package:audioplayers/audioplayers.dart';

/// Centralized sound effect playback for the game.
///
/// Uses one persistent AudioPlayer per sound type, set to low-latency mode
/// (SoundPool on Android), so repeated playback is fast and consistent
/// without the overhead of creating a new player each time.
class SoundManager {
  static bool enabled = true;
  static bool _initialized = false;

  static final AudioPlayer _movePlayer = AudioPlayer();
  static final AudioPlayer _capturePlayer = AudioPlayer();
  static final AudioPlayer _checkPlayer = AudioPlayer();
  static final AudioPlayer _gameEndPlayer = AudioPlayer();

  /// Call once at app startup (see main.dart) to switch players into
  /// low-latency mode ahead of time.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Future.wait([
        _movePlayer.setPlayerMode(PlayerMode.lowLatency),
        _capturePlayer.setPlayerMode(PlayerMode.lowLatency),
        _checkPlayer.setPlayerMode(PlayerMode.lowLatency),
        _gameEndPlayer.setPlayerMode(PlayerMode.lowLatency),
      ]);
    } catch (_) {
      // If this fails, players just default to normal mode — still works.
    }
  }

  static Future<void> _play(AudioPlayer player, String fileName) async {
    if (!enabled) return;
    try {
      await player.stop();
      await player.play(AssetSource('sounds/$fileName'));
    } catch (_) {
      // Ignore playback errors so a sound issue never blocks gameplay.
    }
  }

  static Future<void> playMove() => _play(_movePlayer, 'move.wav');
  static Future<void> playCapture() => _play(_capturePlayer, 'capture.mp3');
  static Future<void> playCheck() => _play(_checkPlayer, 'check.ogg');
  static Future<void> playGameEnd() => _play(_gameEndPlayer, 'game_end.ogg');
}