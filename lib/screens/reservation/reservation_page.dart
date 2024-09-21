import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import 'dart:convert'; // 添加导入

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  List<dynamic> _busList = []; // 添加列表用于存储班车信息
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
      final dateList = List.generate(7, (index) {
        final date = today.add(Duration(days: index));
        return date.toIso8601String().split('T')[0];
      });

      List<dynamic> allBuses = [];

      for (String date in dateList) {
        final response = await reservationService.fetchReservationData(date);
        print(response); // 打印响应内容以调试

        final data = json.decode(response); // 解析响应字符串

        if (data['e'] == 0) {
          List<dynamic> list = data['d']['list'];
          for (var bus in list) {
            var busId = bus['id'].toString();
            var table = bus['table'];
            if (table.containsKey(busId)) {
              var timeSlots = table[busId];
              for (var slot in timeSlots) {
                if (slot['row']['margin'] > 0) {
                  slot['route_name'] = bus['name']; // 添加路线名称
                  allBuses.add(slot);
                }
              }
            }
          }
        } else {
          throw Exception(data['m']);
        }
      }

      setState(() {
        _busList = allBuses;
        _isLoading = false;
      });
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
                    return ExpansionTile(
                      title: Text(bus['route_name']),
                      children: [
                        Text(
                          '日期：${bus['abscissa']} 出发时间：${bus['yaxis']} 剩余座位：${bus['row']['margin']}',
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
