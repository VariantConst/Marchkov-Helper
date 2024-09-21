import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import 'dart:convert';
import '../../widgets/bus_route_card.dart';
import 'package:intl/intl.dart';

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
      final dateStrings = [
        today.toIso8601String().split('T')[0],
        today.add(Duration(days: 7)).toIso8601String().split('T')[0],
      ];

      final responses = await Future.wait(
        dateStrings.map((dateString) =>
            reservationService.fetchReservationData(dateString)),
      );

      List<dynamic> allBuses = [];

      for (var response in responses) {
        print(response); // 调试输出

        final data = json.decode(response);

        if (data['e'] == 0) {
          List<dynamic> list = data['d']['list'];

          for (var bus in list) {
            var busId = bus['id'];
            var table = bus['table'];
            // 遍历所有班车的所有时间段
            for (var key in table.keys) {
              var timeSlots = table[key];
              for (var slot in timeSlots) {
                if (slot['row']['margin'] > 0) {
                  // 获取班车的日期时间字符串
                  String dateTimeString =
                      slot['abscissa']; // 班车日期时间，例如 '2023-10-20 08:00:00'

                  // 将字符串转换为 DateTime 对象
                  DateTime busDateTime = DateTime.parse(dateTimeString);

                  // 对比当前时间，只有在当前时间之后的班车才加入列表
                  if (busDateTime.isAfter(DateTime.now())) {
                    // 创建一个新的 Map，将 bus 的信息和 slot 的信息合并
                    Map<String, dynamic> busInfo = {
                      'route_name': bus['name'],
                      'bus_id': busId,
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
          }
        } else {
          throw Exception(data['m']);
        }
      }

      setState(() {
        _busList = allBuses;
        _filterBusList(); // 更新过滤
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
                      itemCount: _getGroupedBusList().length,
                      itemBuilder: (context, index) {
                        final group = _getGroupedBusList()[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                _formatDate(group.key),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: group.value
                                  .map((bus) => BusRouteCard(
                                        busData: bus,
                                        onTap: () =>
                                            _showBusDetails(context, bus),
                                      ))
                                  .toList(),
                            ),
                            SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
    );
  }

  List<MapEntry<String, List<dynamic>>> _getGroupedBusList() {
    final groupedBuses = <String, List<dynamic>>{};
    for (var bus in _filteredBusList) {
      final date = bus['abscissa'].split(' ')[0];
      if (!groupedBuses.containsKey(date)) {
        groupedBuses[date] = [];
      }
      groupedBuses[date]!.add(bus);
    }
    return groupedBuses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return DateFormat('MM-dd').format(date);
  }

  void _showBusDetails(BuildContext context, Map<String, dynamic> busData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: BusRouteDetails(busData: busData),
          actions: [
            TextButton(
              child: Text('关闭'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
