import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marchkov_flutter/services/auth_service.dart';
import 'package:marchkov_flutter/views/login_page.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户名: ${authService.username}',
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
              child: Text(authService.loginResponse,
                  style: TextStyle(fontFamily: 'Courier')),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              child: Text('退出登录'),
              onPressed: () {
                authService.logout();
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
