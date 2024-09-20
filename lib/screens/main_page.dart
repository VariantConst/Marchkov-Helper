import 'package:flutter/material.dart';
import 'package:marchkov_flutter/screens/reservation/reservation_page.dart';
import 'package:marchkov_flutter/screens/ride/ride_page.dart';
import 'package:marchkov_flutter/screens/settings/settings_page.dart';

class MainPage extends StatefulWidget {
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    ReservationPage(),
    RidePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _selectedIndex = 1; // 直接设置索引为1，对应RidePage
          });
        },
        elevation: 2.0,
        child: Icon(Icons.directions_car),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.book),
              onPressed: () => _onItemTapped(0),
              color: _selectedIndex == 0 ? Colors.blue : null,
            ),
            SizedBox(width: 48),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => _onItemTapped(2),
              color: _selectedIndex == 2 ? Colors.blue : null,
            ),
          ],
        ),
      ),
    );
  }
}
