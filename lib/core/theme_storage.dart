import 'package:shared_preferences/shared_preferences.dart';
import '../models/board_theme.dart';

/// Handles persisting and retrieving the user's selected board theme
/// across app restarts.
class ThemeStorage {
  static const _key = 'selected_board_theme_index';

  /// Loads the saved theme, or returns the default (Classic Green) if
  /// nothing has been saved yet.
  static Future<BoardTheme> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);

    if (index == null || index < 0 || index >= BoardTheme.all.length) {
      return BoardTheme.classicGreen;
    }
    return BoardTheme.all[index];
  }

  /// Saves the selected theme by its index in [BoardTheme.all].
  static Future<void> saveTheme(BoardTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final index = BoardTheme.all.indexOf(theme);
    if (index != -1) {
      await prefs.setInt(_key, index);
    }
  }
}