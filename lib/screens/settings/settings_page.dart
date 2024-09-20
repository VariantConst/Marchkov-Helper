// lib/screens/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../login/login_page.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户名: ${authProvider.username}',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            Text('登录响应:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(authProvider.loginResponse,
                  style: TextStyle(fontFamily: 'Courier')),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              child: Text('退出登录'),
              onPressed: () {
                authProvider.logout();
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => LoginPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
