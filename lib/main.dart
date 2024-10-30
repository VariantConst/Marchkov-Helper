import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/reservation_provider.dart';
import 'providers/theme_provider.dart'; // 新增
import 'providers/ride_history_provider.dart'; // 新增
import 'providers/brightness_provider.dart';
import 'screens/login/login_page.dart';
import 'screens/main/main_page.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
            create: (_) => BrightnessProvider()..initialize()),
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
        final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

        // 创建主题以获取正确的背景颜色
        final currentTheme = isDarkMode
            ? ThemeData(
                colorScheme: ColorScheme.fromSeed(
                    seedColor: themeProvider.selectedColor,
                    brightness: Brightness.dark),
                brightness: Brightness.dark,
                useMaterial3: true,
              )
            : ThemeData(
                colorScheme: ColorScheme.fromSeed(
                    seedColor: themeProvider.selectedColor,
                    brightness: Brightness.light),
                brightness: Brightness.light,
                useMaterial3: true,
              );

        // 使用主题的背景颜色
        final backgroundColor = currentTheme.colorScheme.background;

        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          systemNavigationBarColor: backgroundColor,
          systemNavigationBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
        ));

        return MaterialApp(
          title: 'Marchkov Helper',
          debugShowCheckedModeBanner: false, // 添加这一行
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: themeProvider.selectedColor,
                brightness: Brightness.light),
            brightness: Brightness.light,
            useMaterial3: true,
            // 添加更多的主题配置以适配夜间模式
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: themeProvider.selectedColor,
                brightness: Brightness.dark),
            brightness: Brightness.dark,
            useMaterial3: true,
            // 添加更多的暗黑主题配置
          ),
          themeMode: themeProvider.themeMode,
          home: AuthWrapper(),
          builder: (context, child) {
            return LifecycleWrapper(child: child!);
          },
        );
      },
    );
  }
}

class LifecycleWrapper extends StatefulWidget {
  final Widget child;

  const LifecycleWrapper({super.key, required this.child});

  @override
  LifecycleWrapperState createState() => LifecycleWrapperState();
}

class LifecycleWrapperState extends State<LifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final brightnessProvider =
        Provider.of<BrightnessProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        // 从后台恢复时，同步系统亮度
        brightnessProvider.syncWithSystemBrightness();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // 进入后台或关闭时，清理亮度设置
        brightnessProvider.cleanup();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
