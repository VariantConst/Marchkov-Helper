import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

enum BrightnessControlMode {
  auto('自动调节'),
  manual('手动调节'),
  none('不调节');

  final String label;
  const BrightnessControlMode(this.label);
}

class RideSettingsPage extends StatefulWidget {
  @override
  RideSettingsPageState createState() => RideSettingsPageState();
}

class RideSettingsPageState extends State<RideSettingsPage> {
  bool? _isAutoReservationEnabled;
  bool? _isSafariStyleEnabled;
  BrightnessControlMode? _brightnessMode;
  double? _dayBrightness;
  double? _nightBrightness;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoReservationEnabled =
          prefs.getBool('autoReservationEnabled') ?? false;
      _isSafariStyleEnabled = prefs.getBool('safariStyleEnabled') ?? false;
      _brightnessMode = BrightnessControlMode.values[
          prefs.getInt('brightnessMode') ?? BrightnessControlMode.auto.index];
      _dayBrightness = prefs.getDouble('dayBrightness') ?? 75.0;
      _nightBrightness = prefs.getDouble('nightBrightness') ?? 50.0;
    });
  }

  Future<void> _saveSettings(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoReservationEnabled', value);
  }

  Future<void> _saveSafariStyleSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safariStyleEnabled', value);
  }

  Future<void> _saveBrightnessMode(BrightnessControlMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('brightnessMode', mode.index);
  }

  Future<void> _saveBrightness(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('自动预约功能使用须知'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('请确认您同意以下条款：'),
              SizedBox(height: 16),
              Text('1. 我承诺不会滥用自动预约功能'),
              Text('2. 如果预约后不想乘坐，我会及时取消预约'),
              Text('3. 我理解频繁预约后取消可能会影响他人乘车'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('暂不开启'),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                HapticFeedback.mediumImpact();
                await _saveSettings(true);
                setState(() {
                  _isAutoReservationEnabled = true;
                });
                if (!mounted) return;
                navigator.pop();
              },
              child: Text('同意并开启'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();

    // 恢复所有设置为默认值
    await prefs.setBool('autoReservationEnabled', false);
    await prefs.setBool('safariStyleEnabled', false);
    await prefs.setInt('brightnessMode', BrightnessControlMode.auto.index);
    await prefs.setDouble('dayBrightness', 75.0);
    await prefs.setDouble('nightBrightness', 50.0);

    // 更新状态
    setState(() {
      _isAutoReservationEnabled = false;
      _isSafariStyleEnabled = false;
      _brightnessMode = BrightnessControlMode.auto;
      _dayBrightness = 75.0;
      _nightBrightness = 50.0;
    });
  }

  void _showResetConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('恢复默认设置'),
          content: Text('确定要将所有设置恢复为默认值吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                HapticFeedback.mediumImpact();
                await _resetToDefaults();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text('恢复默认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isAutoReservationEnabled == null ||
        _isSafariStyleEnabled == null ||
        _brightnessMode == null ||
        _dayBrightness == null ||
        _nightBrightness == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '乘车设置',
            style: theme.textTheme.titleLarge,
          ),
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '乘车设置',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 功能设置组
                  _buildSettingsGroup(
                    title: '功能设置',
                    children: [
                      _buildSettingTile(
                        title: '自动预约班车',
                        subtitle: '开启后将自动预约最近的班车',
                        icon: Icons.schedule_outlined,
                        value: _isAutoReservationEnabled!,
                        onChanged: (value) async {
                          if (value) {
                            _showConfirmationDialog();
                          } else {
                            HapticFeedback.mediumImpact();
                            await _saveSettings(false);
                            setState(() {
                              _isAutoReservationEnabled = false;
                            });
                          }
                        },
                      ),
                      Divider(height: 1, indent: 56),
                      _buildSettingTile(
                        title: '仿官方页面',
                        subtitle: '开启后点击二维码可切换到仿官方页面',
                        icon: Icons.qr_code_outlined,
                        value: _isSafariStyleEnabled!,
                        onChanged: (value) async {
                          HapticFeedback.mediumImpact();
                          await _saveSafariStyleSetting(value);
                          setState(() {
                            _isSafariStyleEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),

                  // 显示设置组
                  _buildSettingsGroup(
                    title: '显示设置',
                    children: [
                      _buildBrightnessModeSelector(),
                      if (_brightnessMode != BrightnessControlMode.none) ...[
                        Divider(height: 1),
                        _buildBrightnessSlider(
                          title: '白天亮度',
                          value: _dayBrightness!,
                          min: 50,
                          max: 100,
                          onChanged: (value) {
                            setState(() {
                              _dayBrightness = value;
                            });
                            _saveBrightness('dayBrightness', value);
                          },
                        ),
                        Divider(height: 1),
                        _buildBrightnessSlider(
                          title: '夜间亮度',
                          value: _nightBrightness!,
                          min: 50,
                          max: 100,
                          onChanged: (value) {
                            setState(() {
                              _nightBrightness = value;
                            });
                            _saveBrightness('nightBrightness', value);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 添加恢复默认按钮
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: FilledButton.tonal(
              onPressed: _showResetConfirmationDialog,
              style: FilledButton.styleFrom(
                minimumSize: Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restore, size: 20),
                  SizedBox(width: 8),
                  Text('恢复默认设置'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title: ${value.toInt()}%',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            label: '${value.toInt()}%',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: theme.colorScheme.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildBrightnessModeSelector() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
          child: Text(
            '二维码亮度控制方式',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...BrightnessControlMode.values
            .map((mode) => RadioListTile<BrightnessControlMode>(
                  title: Text(mode.label),
                  subtitle: Text(_getBrightnessModeDescription(mode)),
                  value: mode,
                  groupValue: _brightnessMode,
                  onChanged: (BrightnessControlMode? value) {
                    if (value != null) {
                      setState(() {
                        _brightnessMode = value;
                      });
                      _saveBrightnessMode(value);
                      HapticFeedback.mediumImpact();
                    }
                  },
                )),
      ],
    );
  }

  String _getBrightnessModeDescription(BrightnessControlMode mode) {
    switch (mode) {
      case BrightnessControlMode.auto:
        return '根据时间自动调节二维码亮度';
      case BrightnessControlMode.manual:
        return '在乘车页面显示亮度调节开关';
      case BrightnessControlMode.none:
        return '使用系统默认亮度';
    }
  }
}
