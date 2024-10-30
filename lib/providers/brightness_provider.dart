import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_brightness/screen_brightness.dart';

class BrightnessProvider with ChangeNotifier {
  bool _isFlashlightOn = false;
  double _originalBrightness = 0.0;
  final _screenBrightness = ScreenBrightness();
  bool _isAutoMode = false;

  bool get isFlashlightOn => _isFlashlightOn;
  bool get isAutoMode => _isAutoMode;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isFlashlightOn = prefs.getBool('isFlashlightOn') ?? false;

    try {
      await syncWithSystemBrightness();
    } catch (e) {
      debugPrint('Error initializing brightness: $e');
    }
  }

  Future<void> syncWithSystemBrightness() async {
    try {
      // 获取系统当前亮度
      _originalBrightness = await _screenBrightness.current;

      // 如果当前没有特殊模式启用，就使用系统亮度
      if (!_isFlashlightOn && !_isAutoMode) {
        await _screenBrightness.setScreenBrightness(_originalBrightness);
      }
    } catch (e) {
      debugPrint('Error syncing brightness: $e');
    }
  }

  Future<void> enableAutoMode() async {
    if (_isAutoMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      // 保存当前亮度
      _originalBrightness = await _screenBrightness.current;

      // 获取设置的亮度值
      final dayBrightness = prefs.getDouble('dayBrightness') ?? 75.0;
      final nightBrightness = prefs.getDouble('nightBrightness') ?? 50.0;

      // 判断当前是白天还是夜晚
      final hour = DateTime.now().hour;
      final isDaytime = hour >= 6 && hour < 18;

      // 设置对应的亮度
      final targetBrightness =
          (isDaytime ? dayBrightness : nightBrightness) / 100;
      await _screenBrightness.setScreenBrightness(targetBrightness);

      _isAutoMode = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error enabling auto mode: $e');
    }
  }

  Future<void> disableAutoMode() async {
    if (!_isAutoMode) return;

    try {
      await _screenBrightness.setScreenBrightness(_originalBrightness);
      _isAutoMode = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error disabling auto mode: $e');
    }
  }

  Future<void> toggleFlashlight({bool? force}) async {
    final prefs = await SharedPreferences.getInstance();
    final newState = force ?? !_isFlashlightOn;

    if (newState == _isFlashlightOn) return;

    try {
      if (newState) {
        // 保存当前亮度
        _originalBrightness = await _screenBrightness.current;

        // 获取设置的亮度值
        final dayBrightness = prefs.getDouble('dayBrightness') ?? 75.0;
        final nightBrightness = prefs.getDouble('nightBrightness') ?? 50.0;

        // 判断当前是白天还是夜晚
        final hour = DateTime.now().hour;
        final isDaytime = hour >= 6 && hour < 18;

        // 设置对应的亮度
        final targetBrightness =
            (isDaytime ? dayBrightness : nightBrightness) / 100;
        await _screenBrightness.setScreenBrightness(targetBrightness);
      } else {
        // 恢复原始亮度
        await _screenBrightness.setScreenBrightness(_originalBrightness);
      }

      _isFlashlightOn = newState;
      await prefs.setBool('isFlashlightOn', newState);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling brightness: $e');
    }
  }

  // 在应用退出或暂停时调用
  Future<void> cleanup() async {
    if (_isFlashlightOn) {
      await toggleFlashlight(force: false);
    } else if (_isAutoMode) {
      await disableAutoMode();
    }
  }
}
