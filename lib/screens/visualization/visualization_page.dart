import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_history_provider.dart';
import '../../models/ride_info.dart';
import 'ride_calendar_card.dart';
// 添加以下导入
import 'departure_time_bar_chart.dart';

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
              : _buildVisualizationCards(rideHistoryProvider.rides),
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
