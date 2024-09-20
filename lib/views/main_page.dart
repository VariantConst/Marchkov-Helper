import 'package:flutter/material.dart';
import 'package:marchkov_flutter/views/reservation_page.dart';
import 'package:marchkov_flutter/views/ride_page.dart';
import 'package:marchkov_flutter/views/settings_page.dart';

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
        child: Icon(Icons.directions_car),
        elevation: 2.0,
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
