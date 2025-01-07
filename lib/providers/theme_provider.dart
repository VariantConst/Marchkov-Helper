import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Color _selectedColor = Colors.blue;

  ThemeMode get themeMode => _themeMode;
  Color get selectedColor => _selectedColor;

  ThemeProvider() {
    _loadThemeMode();
    _loadSelectedColor();
  }

  void _updateSystemUIOverlay(BuildContext context) {
    final isDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _selectedColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      brightness: isDark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
    );

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  void _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? themeModeString = prefs.getString('themeMode');
    if (themeModeString != null) {
      _themeMode =
          ThemeMode.values.firstWhere((e) => e.toString() == themeModeString);
      notifyListeners();
    }
  }

  Future<void> _loadSelectedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('selectedColor');
    if (colorValue == null) {
      _selectedColor = Colors.blue;
    } else {
      _selectedColor = Color(colorValue);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode, [BuildContext? context]) async {
    _themeMode = mode;
    notifyListeners();

    // 先保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString());

    // 如果提供了 context 并且它仍然有效，则更新系统UI
    if (context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSystemUIOverlay(context);
      });
    }
  }

  Future<void> setSelectedColor(Color color, [BuildContext? context]) async {
    _selectedColor = color;
    notifyListeners();

    // 保存颜色的完整 value
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    await prefs.setInt('selectedColor', color.value);

    // 如果提供了 context 并且它仍然有效，则更新系统UI
    if (context != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSystemUIOverlay(context);
      });
    }
  }
}
