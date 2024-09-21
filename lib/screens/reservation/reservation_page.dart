import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import 'dart:convert'; // 添加导入
import '../../widgets/bus_route_card.dart'; // 添加导入

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  List<dynamic> _busList = []; // 用于存储班车信息
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadReservationData();
  }

  Future<void> _loadReservationData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final today = DateTime.now();
      final dateString = today.toIso8601String().split('T')[0];

      final response =
          await reservationService.fetchReservationData(dateString);
      print(response); // 打印响应内容以调试

      final data = json.decode(response); // 解析响应字符串

      if (data['e'] == 0) {
        List<dynamic> list = data['d']['list'];
        List<dynamic> allBuses = [];

        for (var bus in list) {
          var busId = bus['id'];
          var table = bus['table'];
          // 遍历所有班车的所有时间段
          for (var key in table.keys) {
            var timeSlots = table[key];
            for (var slot in timeSlots) {
              if (slot['row']['margin'] > 0) {
                // 创建一个新的 Map，将 bus 的信息和 slot 的信息合并
                Map<String, dynamic> busInfo = {
                  'route_name': bus['name'],
                  'bus_id': busId, // 这里确保 bus_id 正确赋值
                  'abscissa': slot['abscissa'],
                  'yaxis': slot['yaxis'],
                  'row': slot['row'],
                  'time_id': slot['time_id'],
                };
                allBuses.add(busInfo);
              }
            }
          }
        }

        setState(() {
          _busList = allBuses;
          _isLoading = false;
        });
      } else {
        throw Exception(data['m']);
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('预约'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : ListView.builder(
                  itemCount: _busList.length,
                  itemBuilder: (context, index) {
                    final bus = _busList[index];
                    return BusRouteCard(busData: bus);
                  },
                ),
    );
  }
}
