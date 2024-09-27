import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../login/login_page.dart';
import '../../services/user_service.dart';
import 'theme_settings_page.dart';
import '../visualization/visualization_page.dart';
import 'about_page.dart';

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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(top: 20),
          child: Column(
            children: [
              SizedBox(height: 40),
              GestureDetector(
                onTap: _selectEmoji,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                  child: Text(
                    _selectedEmoji,
                    style: TextStyle(fontSize: 48),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                name,
                style: theme.textTheme.titleLarge, // 修改：headline6 改为 titleLarge
              ),
              SizedBox(height: 8),
              Text(
                college,
                style:
                    theme.textTheme.titleMedium, // 修改：subtitle1 改为 titleMedium
              ),
              SizedBox(height: 8),
              Text(
                'ID: $studentId',
                style: theme.textTheme.bodySmall, // 修改：caption 改为 bodySmall
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildSettingOption(
                      title: '主题设置',
                      icon: Icons.palette,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ThemeSettingsPage()),
                        );
                      },
                    ),
                    _buildSettingOption(
                      title: '乘车历史',
                      icon: Icons.history,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  VisualizationSettingsPage()),
                        );
                      },
                    ),
                    _buildSettingOption(
                      title: '关于',
                      icon: Icons.info,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AboutPage()),
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.logout),
                        label: Text('退出登录'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme
                              .secondary, // 修改：primary 改为 backgroundColor
                          foregroundColor: theme.colorScheme
                              .onSecondary, // 修改：onPrimary 改为 foregroundColor
                        ),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await _clearUserInfo();
                          await authProvider.logout();
                          if (!mounted) return;
                          navigator.pushReplacement(
                              MaterialPageRoute(builder: (_) => LoginPage()));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ListTile _buildSettingOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.iconTheme.color),
      title: Text(
        title,
        style: theme.textTheme.titleMedium, // 修改：subtitle1 改为 titleMedium
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: theme.iconTheme.color),
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
    await prefs.remove('showReservationTip'); // 添加此行以清除使用提示设置
    await prefs.remove('showRideTip'); // 添加此行以清除使用提示设置
  }
}
