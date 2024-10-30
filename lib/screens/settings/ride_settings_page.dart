import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class RideSettingsPage extends StatefulWidget {
  @override
  RideSettingsPageState createState() => RideSettingsPageState();
}

class RideSettingsPageState extends State<RideSettingsPage> {
  bool? _isAutoReservationEnabled;
  bool? _isSafariStyleEnabled;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isAutoReservationEnabled == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '乘车设置',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '乘车设置',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Card(
                elevation: 0,
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: ListTile(
                  title: Text(
                    '自动预约班车',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '开启后将自动预约最近的班车',
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: Switch(
                    value: _isAutoReservationEnabled!,
                    onChanged: (bool value) async {
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
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 0,
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: ListTile(
                  title: Text(
                    '仿官方页面',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '开启后点击二维码可切换到仿官方页面',
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: Switch(
                    value: _isSafariStyleEnabled!,
                    onChanged: (bool value) async {
                      HapticFeedback.mediumImpact();
                      await _saveSafariStyleSetting(value);
                      setState(() {
                        _isSafariStyleEnabled = value;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
