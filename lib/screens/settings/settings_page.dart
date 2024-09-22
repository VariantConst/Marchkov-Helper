import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart'; // 新增
import '../login/login_page.dart';
import '../../services/user_service.dart';
import 'theme_settings_page.dart'; // 新增

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState(); // 修改这一行
}

class _SettingsPageState extends State<SettingsPage> {
  String name = '';
  String studentId = '';
  String college = '';
  late UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = UserService(context.read<AuthProvider>());
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    try {
      final userInfo = await _userService.fetchUserInfo();
      setState(() {
        name = userInfo['name'] ?? '';
        studentId = userInfo['studentId'] ?? '';
        college = userInfo['college'] ?? '';
      });
    } catch (e) {
      print('获取用户信息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = Provider.of<ThemeProvider>(context); // 修改这一行

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text(college, style: TextStyle(fontSize: 16)),
                        SizedBox(height: 8),
                        Text(studentId, style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.exit_to_app),
                      onPressed: () {
                        authProvider.logout();
                        Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => LoginPage()));
                      },
                      tooltip: '退出登录',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            // 新增主题设置按钮
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ThemeSettingsPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Row(
                // 将 child 移到最后
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('主题设置'),
                  Icon(Icons.arrow_forward_ios),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
