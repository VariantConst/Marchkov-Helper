import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_brightness/screen_brightness.dart';

abstract interface class AppBrightnessController {
  Future<void> setBrightness(double brightness);

  Future<void> reset();
}

class PlatformBrightnessController implements AppBrightnessController {
  final ScreenBrightness _screenBrightness;

  PlatformBrightnessController({ScreenBrightness? screenBrightness})
      : _screenBrightness = screenBrightness ?? ScreenBrightness();

  @override
  Future<void> reset() => _screenBrightness.resetScreenBrightness();

  @override
  Future<void> setBrightness(double brightness) {
    return _screenBrightness.setScreenBrightness(brightness);
  }
}

class BrightnessProvider with ChangeNotifier {
  bool _isFlashlightOn = false;
  final AppBrightnessController _brightnessController;
  bool _isAutoMode = false;

  BrightnessProvider({AppBrightnessController? brightnessController})
      : _brightnessController =
            brightnessController ?? PlatformBrightnessController();

  bool get isFlashlightOn => _isFlashlightOn;
  bool get isAutoMode => _isAutoMode;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isFlashlightOn = false;
    await prefs.remove('isFlashlightOn');

    try {
      await syncWithSystemBrightness();
    } catch (e) {
      debugPrint('Error initializing brightness: $e');
    }
  }

  Future<void> syncWithSystemBrightness() async {
    try {
      if (_isFlashlightOn || _isAutoMode) {
        await _applyConfiguredBrightness();
      } else {
        await _brightnessController.reset();
      }
    } catch (e) {
      debugPrint('Error syncing brightness: $e');
    }
  }

  Future<void> enableAutoMode() async {
    try {
      await _applyConfiguredBrightness();
      _isFlashlightOn = false;
      _isAutoMode = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error enabling auto mode: $e');
    }
  }

  Future<void> disableAutoMode() async {
    if (!_isAutoMode) return;

    try {
      _isAutoMode = false;
      if (!_isFlashlightOn) {
        await _brightnessController.reset();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error disabling auto mode: $e');
    }
  }

  Future<void> toggleFlashlight({bool? force}) async {
    final newState = force ?? !_isFlashlightOn;

    if (newState == _isFlashlightOn) return;

    try {
      if (newState) {
        await _applyConfiguredBrightness();
      } else if (!_isAutoMode) {
        await _brightnessController.reset();
      }

      _isFlashlightOn = newState;
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling brightness: $e');
    }
  }

  // 在应用退出或暂停时调用
  Future<void> cleanup() async {
    final prefs = await SharedPreferences.getInstance();
    _isFlashlightOn = false;
    _isAutoMode = false;
    await prefs.remove('isFlashlightOn');
    await _brightnessController.reset();
    notifyListeners();
  }

  Future<void> suspendOverride() async {
    await _brightnessController.reset();
  }

  Future<void> _applyConfiguredBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    final dayBrightness = prefs.getDouble('dayBrightness') ?? 75.0;
    final nightBrightness = prefs.getDouble('nightBrightness') ?? 50.0;
    final hour = DateTime.now().hour;
    final isDaytime = hour >= 6 && hour < 18;
    final targetBrightness =
        (isDaytime ? dayBrightness : nightBrightness) / 100;
    await _brightnessController.setBrightness(targetBrightness);
  }
}
