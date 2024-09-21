import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  String _responseText = '加载中...';

  @override
  void initState() {
    super.initState();
    _loadReservationData();
  }

  Future<void> _loadReservationData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final date = DateTime.now().toIso8601String().split('T')[0]; // 获取当前日期
      final response = await reservationService.fetchReservationData(date);
      setState(() {
        _responseText = response;
      });
    } catch (e) {
      setState(() {
        _responseText = '加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('预约'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(_responseText),
      ),
    );
  }
}
