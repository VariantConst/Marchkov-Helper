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
          theme: ThemeData(
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme(
              primary: Colors.blue,
              primaryContainer: Colors.blueAccent,
              secondary: Colors.teal,
              secondaryContainer: Colors.tealAccent,
              surface: Colors.grey[800]!,
              error: Colors.red,
              onPrimary: Colors.white,
              onSecondary: Colors.black,
              onSurface: Colors.white,
              onError: Colors.white,
              brightness: Brightness.dark,
            ),
            textTheme: TextTheme(
              headlineMedium: TextStyle(color: Colors.white),
              bodyLarge: TextStyle(color: Colors.white70),
              // 添加更多文本样式以确保在深色背景上的可读性
            ),
          ),
          themeMode: themeProvider.themeMode,
          home: SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    await Future.delayed(Duration(seconds: 2));
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = await authProvider.checkLoginState();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? MainPage() : LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            Text('Marchkov Helper',
                style: Theme.of(context).textTheme.headlineMedium),
            // 删除转圈动画
            // SizedBox(height: 20),
            // CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
