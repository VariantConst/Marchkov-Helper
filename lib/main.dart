import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/reservation_provider.dart';
import 'providers/theme_provider.dart'; // 新增
import 'providers/ride_history_provider.dart'; // 新增
import 'screens/login/login_page.dart';
import 'screens/main/main_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ReservationProvider>(
          create: (context) => ReservationProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previous) => ReservationProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, RideHistoryProvider>(
          create: (context) => RideHistoryProvider(
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previous) => RideHistoryProvider(auth),
        ),
      ],
      child: MyApp(),
    ),
  );

  // 添加全局错误处理
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(details.toString());
  };
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Marchkov Helper',
          debugShowCheckedModeBanner: false, // 添加这一行
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.light,
            // 添加更多的主题配置以适配夜间模式
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: Brightness.dark,
            // 添加更多的暗黑主题配置
          ),
          themeMode: themeProvider.themeMode,
          home: AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return FutureBuilder<bool>(
      future: authProvider.checkLoginState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final isLoggedIn = snapshot.data ?? false;
        return isLoggedIn ? MainPage() : LoginPage();
      },
    );
  }
}
