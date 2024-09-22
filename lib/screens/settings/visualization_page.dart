import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_history_provider.dart';
import '../../models/ride_info.dart';

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
        title: Text('可视化设置'),
      ),
      body: rideHistoryProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : rideHistoryProvider.error != null
              ? Center(child: Text('加载乘车历史失败: ${rideHistoryProvider.error}'))
              : _buildRideHistoryStats(rideHistoryProvider.rides),
    );
  }

  Widget _buildRideHistoryStats(List<RideInfo> rides) {
    // 统计两种类型的数量
    int status4Count = rides.where((ride) => ride.statusName == '已签到').length;
    int status5Count = rides.where((ride) => ride.statusName != '已签到').length;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('共有 ${rides.length} 条预约信息', style: TextStyle(fontSize: 18)),
          SizedBox(height: 10),
          Text('已签到: $status4Count 条', style: TextStyle(fontSize: 16)),
          Text('未签到: $status5Count 条', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
