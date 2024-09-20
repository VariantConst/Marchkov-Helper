// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login/login_page.dart';
// 移除未使用的导入
// import 'screens/main/main_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校园出行',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Work Sans', // 设置全局字体
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Colors.blueAccent,
          surface: Colors.grey[50]!, // 替换 background
          onSurface: Colors.black87, // 替换 onBackground
          error: Colors.red,
          onError: Colors.white,
        ),
        textTheme: TextTheme(
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          labelLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold), // 将 button 改为 labelLarge
          labelSmall: TextStyle(fontSize: 12),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, // 按钮背景色
            foregroundColor: Colors.white, // 按钮文本色
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: LoginPage(),
    );
  }
}
