import 'package:flutter_test/flutter_test.dart';
import 'package:marchkov_helper/providers/brightness_provider.dart';
import 'package:marchkov_helper/screens/settings/ride_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryBrightnessController implements AppBrightnessController {
  double? brightness;
  int resetCount = 0;

  @override
  Future<void> reset() async {
    brightness = null;
    resetCount++;
  }

  @override
  Future<void> setBrightness(double brightness) async {
    this.brightness = brightness;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('invalid stored brightness modes fall back to following the system', () {
    expect(
      BrightnessControlMode.fromStoredIndex(null),
      BrightnessControlMode.none,
    );
    expect(
      BrightnessControlMode.fromStoredIndex(99),
      BrightnessControlMode.none,
    );
  });

  test('cleanup releases the app override back to system brightness', () async {
    SharedPreferences.setMockInitialValues({
      'dayBrightness': 80.0,
      'nightBrightness': 60.0,
    });
    final controller = _MemoryBrightnessController();
    final provider = BrightnessProvider(brightnessController: controller);

    await provider.enableAutoMode();
    expect(controller.brightness, isNotNull);

    await provider.cleanup();
    expect(controller.brightness, isNull);
    expect(controller.resetCount, 1);
    expect(provider.isAutoMode, isFalse);
    expect(provider.isFlashlightOn, isFalse);
  });

  test('system sync resets brightness when no override is enabled', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = _MemoryBrightnessController();
    final provider = BrightnessProvider(brightnessController: controller);

    await provider.syncWithSystemBrightness();

    expect(controller.brightness, isNull);
    expect(controller.resetCount, 1);
  });

  test('background suspension resumes the selected automatic override',
      () async {
    SharedPreferences.setMockInitialValues({'dayBrightness': 80.0});
    final controller = _MemoryBrightnessController();
    final provider = BrightnessProvider(brightnessController: controller);

    await provider.enableAutoMode();
    final configuredBrightness = controller.brightness;
    await provider.suspendOverride();

    expect(controller.brightness, isNull);
    expect(provider.isAutoMode, isTrue);

    await provider.syncWithSystemBrightness();
    expect(controller.brightness, configuredBrightness);
  });
}
