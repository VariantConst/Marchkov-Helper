import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../login/login_page.dart';
import '../../services/user_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
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
      // 处理错误,例如显示一个错误提示
      print('获取用户信息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Card(
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
      ),
    );
  }
}
