import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_history_provider.dart';
import '../../models/ride_info.dart';
import 'ride_calendar_card.dart';
// 添加以下导入
import 'departure_time_bar_chart.dart';

// 将 TimeRange 枚举移动到类外部
enum TimeRange { threeMonths, sixMonths, oneYear, all }

class VisualizationSettingsPage extends StatefulWidget {
  @override
  State<VisualizationSettingsPage> createState() =>
      _VisualizationSettingsPageState();
}

class _VisualizationSettingsPageState extends State<VisualizationSettingsPage> {
  @override
  void initState() {
    super.initState();
    // 每次进入页面时刷新数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RideHistoryProvider>(context, listen: false)
          .loadRideHistory();
    });
  }

  // 添加选择的时间范围变量，默认值为全部
  TimeRange _selectedTimeRange = TimeRange.all;

  // 根据选定的时间范围过滤乘车数据
  List<RideInfo> _filterRides(List<RideInfo> rides) {
    final now = DateTime.now();
    late DateTime startDate;

    switch (_selectedTimeRange) {
      case TimeRange.threeMonths:
        startDate = now.subtract(Duration(days: 90));
        break;
      case TimeRange.sixMonths:
        startDate = now.subtract(Duration(days: 180));
        break;
      case TimeRange.oneYear:
        startDate = now.subtract(Duration(days: 365));
        break;
      case TimeRange.all:
        return rides; // 不过滤，返回全部数据
    }

    // 过滤掉不在选定时间范围内的乘车记录
    return rides.where((ride) {
      DateTime rideDate = DateTime.parse(ride.appointmentTime);
      return rideDate.isAfter(startDate) && rideDate.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rideHistoryProvider = Provider.of<RideHistoryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('乘车数据可视化'),
      ),
      body: rideHistoryProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : rideHistoryProvider.error != null
              ? Center(child: Text('加载乘车历史失败: ${rideHistoryProvider.error}'))
              : Column(
                  children: [
                    // 添加顶部栏下拉框
                    Container(
                      color: Colors.grey[200],
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Text('选择时间范围: '),
                          SizedBox(width: 8),
                          DropdownButton<TimeRange>(
                            value: _selectedTimeRange,
                            onChanged: (TimeRange? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedTimeRange = newValue;
                                });
                              }
                            },
                            items: [
                              DropdownMenuItem(
                                value: TimeRange.threeMonths,
                                child: Text('过去3个月'),
                              ),
                              DropdownMenuItem(
                                value: TimeRange.sixMonths,
                                child: Text('过去半年'),
                              ),
                              DropdownMenuItem(
                                value: TimeRange.oneYear,
                                child: Text('过去一年'),
                              ),
                              DropdownMenuItem(
                                value: TimeRange.all,
                                child: Text('全部'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 显示过滤后的数据
                    Expanded(
                      child: _buildVisualizationCards(
                          _filterRides(rideHistoryProvider.rides)),
                    ),
                  ],
                ),
    );
  }

  Widget _buildVisualizationCards(List<RideInfo> rides) {
    return PageView(
      children: [
        RideCalendarCard(rides: rides),
        DepartureTimeBarChart(rides: rides), // 新增的可视化卡片
      ],
    );
  }
}
