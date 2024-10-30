import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../login/login_page.dart';
import '../../services/user_service.dart';
import 'theme_settings_page.dart';
import '../visualization/visualization_page.dart';
import 'about_page.dart';
import 'ride_settings_page.dart';
import 'help_page.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String name = '';
  String studentId = '';
  String college = '';
  late UserService _userService;
  String _selectedEmoji = '🐴';

  @override
  void initState() {
    super.initState();
    _userService = UserService(context.read<AuthProvider>());
    _loadUserInfo();
    _loadSelectedEmoji();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? '';
      studentId = prefs.getString('studentId') ?? '';
      college = prefs.getString('college') ?? '';
    });

    if (name.isEmpty || studentId.isEmpty || college.isEmpty) {
      await fetchUserInfo();
    }
  }

  Future<void> fetchUserInfo() async {
    try {
      final userInfo = await _userService.fetchUserInfo();
      setState(() {
        name = userInfo['name'] ?? '';
        studentId = userInfo['studentId'] ?? '';
        college = userInfo['college'] ?? '';
      });
      _saveUserInfo();
    } catch (e) {
      print('获取用户信息失败: $e');
    }
  }

  Future<void> _saveUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('studentId', studentId);
    await prefs.setString('college', college);
  }

  Future<void> _loadSelectedEmoji() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedEmoji = prefs.getString('selectedEmoji') ?? '🐴';
    });
  }

  Future<void> _saveSelectedEmoji(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedEmoji', emoji);
  }

  void _selectEmoji() async {
    final List<String> emojis = [
      '🐴',
      '😀',
      '😎',
      '🎉',
      '🚀',
      '🐼',
      '🦄',
      '🐶',
      '🐱',
      '🦊',
      '🦁',
      '🐯',
      '🐨',
      '🐻',
      '🐸',
      '🐙',
      '🐵',
      '🐷',
      '🐮',
      '🐔',
      '🦉',
      '🦇',
      '🦋',
      '🐝',
      '🐞'
    ];
    final String? selectedEmoji = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('选择一个 Emoji'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: emojis.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context, emojis[index]);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        emojis[index],
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedEmoji != null) {
      setState(() {
        _selectedEmoji = selectedEmoji;
      });
      await _saveSelectedEmoji(selectedEmoji);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ListView(
          children: [
            // 个人信息区域
            Container(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _selectEmoji,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _selectedEmoji,
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    college,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ID: $studentId',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // 设置选项组
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      '应用设置',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    child: Column(
                      children: [
                        _buildSettingOption(
                          title: '主题设置',
                          icon: Icons.palette_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ThemeSettingsPage()),
                          ),
                        ),
                        Divider(height: 1, indent: 56),
                        _buildSettingOption(
                          title: '乘车设置',
                          icon: Icons.directions_bus_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => RideSettingsPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      '信息与帮助',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    child: Column(
                      children: [
                        _buildSettingOption(
                          title: '预约历史',
                          icon: Icons.history_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    VisualizationSettingsPage()),
                          ),
                        ),
                        Divider(height: 1, indent: 56),
                        _buildSettingOption(
                          title: '帮助中心',
                          icon: Icons.help_outline,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => HelpPage()),
                          ),
                        ),
                        Divider(height: 1, indent: 56),
                        _buildSettingOption(
                          title: '关于应用',
                          icon: Icons.info_outline,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AboutPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 退出登录按钮
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: FilledButton.tonal(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await _clearUserInfo();
                  await authProvider.logout();
                  if (!mounted) return;
                  navigator.pushReplacement(
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('退出登录'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
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
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Future<void> _clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
    await prefs.remove('studentId');
    await prefs.remove('college');
    await prefs.remove('selectedEmoji');
    await prefs.remove('cachedRideHistory');
    await prefs.remove('lastDauSentDate');
    // await prefs.remove('autoReservationEnabled');
    // await prefs.remove('safariStyleEnabled');
    await prefs.remove('isBrightnessEnhanced');
  }
}
