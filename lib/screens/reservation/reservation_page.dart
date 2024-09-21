import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import 'dart:convert';
import '../../widgets/bus_route_card.dart';

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _busList = []; // 原始班车列表
  List<dynamic> _filteredBusList = []; // 过滤后的班车列表
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedIndex = 0; // 0: 去昌平, 1: 去燕园
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadReservationData();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
          _filterBusList();
        });
      }
    });
  }

  void _filterBusList() {
    setState(() {
      if (_selectedIndex == 0) {
        // 去昌平
        _filteredBusList = _busList.where((bus) {
          final name = bus['route_name'] ?? '';
          final indexYan = name.indexOf('燕');
          final indexXin = name.indexOf('新');
          if (indexYan != -1 && indexXin != -1) {
            return indexYan < indexXin;
          }
          return false;
        }).toList();
      } else {
        // 去燕园
        _filteredBusList = _busList.where((bus) {
          final name = bus['route_name'] ?? '';
          final indexYan = name.indexOf('燕');
          final indexXin = name.indexOf('新');
          if (indexYan != -1 && indexXin != -1) {
            return indexXin < indexYan;
          }
          return false;
        }).toList();
      }
    });
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
                // 过滤班车名称，根据要求分类
                final name = busInfo['route_name'] ?? '';
                final indexYan = name.indexOf('燕');
                final indexXin = name.indexOf('新');
                if (indexYan != -1 && indexXin != -1) {
                  allBuses.add(busInfo);
                }
              }
            }
          }
        }

        _busList = allBuses;
        _filterBusList(); // 初始过滤
        setState(() {
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('预约'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '去昌平'),
            Tab(text: '去燕园'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _filteredBusList.isEmpty
                  ? Center(child: Text('暂无班车信息'))
                  : ListView.builder(
                      itemCount: _filteredBusList.length,
                      itemBuilder: (context, index) {
                        final bus = _filteredBusList[index];
                        return BusRouteCard(busData: bus);
                      },
                    ),
    );
  }
}
