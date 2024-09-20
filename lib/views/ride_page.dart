import 'package:flutter/material.dart';

class RidePage extends StatelessWidget {
  const RidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('乘车'),
      ),
      body: const Center(
        child: Text('这是乘车页面的占位符'),
      ),
    );
  }
}
