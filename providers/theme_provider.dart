// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  // Carrega a preferência de tema do armazenamento local
  void _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final bool isDark = _prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Salva a preferência de tema no armazenamento local
  void _saveTheme(bool isDark) {
    _prefs.setBool('isDarkMode', isDark);
  }

  // Alterna o tema e notifica os ouvintes
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(isDark);
    notifyListeners();
  }
}
