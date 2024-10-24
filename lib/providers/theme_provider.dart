import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // 默认设置为浅色模式
  Color _selectedColor = Colors.blue; // 默认颜色

  ThemeMode get themeMode => _themeMode;
  Color get selectedColor => _selectedColor;

  ThemeProvider() {
    _loadThemeMode();
    _loadSelectedColor();
  }

  void _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? themeModeString = prefs.getString('themeMode');
    if (themeModeString != null) {
      _themeMode = ThemeMode.values.firstWhere((e) => e.toString() == themeModeString);
      notifyListeners();
    }
  }

  // load user theme color from storage
  void _loadSelectedColor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('selectedColor');
    if (colorValue != null) {
      _selectedColor = Color(colorValue);
    } else {
      final pekingRed = Color.fromRGBO(140, 0, 0, 1.0); // default color
      _selectedColor = pekingRed;
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString());
  }

  // save user theme color to storage
  void setSelectedColor(Color color) async {
    _selectedColor = color;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedColor', color.value);
  }
}
