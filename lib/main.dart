import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:marchkov_flutter/services/auth_service.dart';
import 'package:marchkov_flutter/views/login_page.dart';
import 'package:marchkov_flutter/views/main_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
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
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<AuthService>(
        builder: (context, authService, child) {
          return authService.isLoggedIn ? MainPage() : LoginPage();
        },
      ),
    );
  }
}
