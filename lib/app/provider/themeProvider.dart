import 'package:flutter/material.dart';
import 'package:ott/data/themes/custom_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'baseProvider.dart';

class ThemeProvider extends BaseProvider {
  late ThemeData _selectedTheme;
  late SharedPreferences _prefs;

  ThemeProvider({bool isDark = false, SharedPreferences? prefs}) {
    _selectedTheme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
    if (prefs != null) {
      _prefs = prefs;
    } else {
      _initPrefs();
    }
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  ThemeData get getTheme => _selectedTheme;

  bool get isDark => _selectedTheme == AppTheme.darkTheme;

  Future<void> toggleTheme() async {
    _selectedTheme = isDark ? AppTheme.lightTheme : AppTheme.darkTheme;
    try {
      _prefs = await SharedPreferences.getInstance();
      await _prefs.setBool("isDark", isDark);
    } catch (_) {}
    notifyListeners();
  }
}
