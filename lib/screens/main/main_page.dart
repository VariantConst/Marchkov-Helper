// lib/screens/main/main_page.dart
import 'package:flutter/material.dart';
import '../ride/ride_page.dart';
import '../settings/settings_page.dart';
import '../reservation/reservation_page.dart';
import 'package:flutter/services.dart'; // 新增导入
import 'package:shared_preferences/shared_preferences.dart'; // 新增

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
