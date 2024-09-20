import 'package:flutter/material.dart';
import 'package:marchkov_flutter/views/ride_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主页'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('欢迎来到主页'),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('乘车'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RidePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
