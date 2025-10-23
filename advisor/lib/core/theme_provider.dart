import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // Private state
  ThemeMode _themeMode = ThemeMode.dark;

  // Public getter
  ThemeMode get themeMode => _themeMode;

  // This is called by main.dart before the app runs
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the saved preference, defaulting to 'true' (dark) if not found
    final isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // This is called by your button
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

    // 1. Tell all listening widgets to rebuild
    notifyListeners();

    // 2. Save the new preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    } catch (e) {
      debugPrint("Failed to save theme preference: $e");
    }
  }
}