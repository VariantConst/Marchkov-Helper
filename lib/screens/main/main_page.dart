// lib/screens/main/main_page.dart
import 'package:flutter/material.dart';
import '../ride/ride_page.dart';
import '../settings/settings_page.dart';
import '../reservation/reservation_page.dart';
import 'package:flutter/services.dart'; // 新增导入
import 'package:shared_preferences/shared_preferences.dart'; // 新增
import '../visualization/visualization_page.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/version_service.dart';

class MainPage extends StatefulWidget {
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSelectedIndex();
    _checkAndShowAnnualSummaryDialog();
    _silentlyRefreshCookie();
    _checkForUpdates();
  }

  // 加载保存的页面索引
  Future<void> _loadSelectedIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedIndex = prefs.getInt('selectedMainPageIndex') ?? 0;
    });
  }

  // 保存当前页面索引
  Future<void> _saveSelectedIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedMainPageIndex', index);
  }

  // 添加检查和显示年度总结弹窗的方法
  Future<void> _checkAndShowAnnualSummaryDialog() async {
    if (!mounted) return;

    // 检查是否是12月或1月
    final now = DateTime.now();
    if (now.month != 12 && now.month != 1) return;

    // 生成当前年度的唯一标识符
    // 如果是12月，使用当前年份；如果是1月，使用上一年
    final yearId = now.month == 12 ? now.year : now.year - 1;
    final key = 'annualSummaryDismissed_$yearId';

    // 检查是否已经选择了不再显示
    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool(key) ?? false;

    if (isDismissed) return;

    // 显示弹窗
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Text('班车年度总结'),
          ],
        ),
        content: Text('现在可以前往设置-预约历史查看你的班车年度总结啦！'),
        actions: [
          TextButton(
            onPressed: () async {
              // 存储用户的选择
              await prefs.setBool(key, true);
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
            },
            child: Text('不再显示'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _selectedIndex = 2); // 切换到设置页面
              // 延迟一下再导航到预约历史页面，确保设置页面已加载
              Future.delayed(Duration(milliseconds: 100), () {
                Navigator.push(
                  // ignore: use_build_context_synchronously
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisualizationSettingsPage(),
                  ),
                );
              });
            },
            child: Text('前往查看'),
          ),
        ],
      ),
    );
  }

  // 添加新的方法
  Future<void> _silentlyRefreshCookie() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.silentlyRefreshCookie();
    } catch (e) {
      print('静默刷新 cookie 时出错: $e');
    }
  }

  // 添加检查更新的方法
  Future<void> _checkForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skipVersion = prefs.getString('skipVersion') ?? '';

      final versionService = VersionService();
      final currentVersion = await versionService.getCurrentVersion();
      final latestVersion = await versionService.getLatestVersion();

      if (latestVersion == null || !mounted) return;

      // 如果用户选择跳过了这个版本，则不再提示
      if (skipVersion == latestVersion) return;

      // 比较版本号
      if (latestVersion != currentVersion) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.system_update_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text('发现新版本'),
              ],
            ),
            content: Text('新版本 $latestVersion 已发布，是否前往更新？'),
            actions: [
              TextButton(
                onPressed: () async {
                  // 记住用户选择跳过此版本
                  await prefs.setString('skipVersion', latestVersion);
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                },
                child: Text('不再提示'),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await launchUrl(
                    Uri.parse('https://shuttle.variantconst.com'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text('前往更新'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('检查更新时出错: $e');
    }
  }

  static List<Widget> _widgetOptions = <Widget>[
    RidePage(),
    ReservationPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick(); // 修改为更轻柔的震动反馈
    setState(() {
      _selectedIndex = index;
    });
    _saveSelectedIndex(index); // 保存选中的索引
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前主题的亮度
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: '乘车',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '预约',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: brightness == Brightness.dark
            ? Colors.white
            : Theme.of(context).primaryColor,
        unselectedItemColor:
            brightness == Brightness.dark ? Colors.white70 : Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
