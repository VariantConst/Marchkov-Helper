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
      body: Column(
        children: [
          rideHistoryProvider.isLoading
              ? Center(child: CircularProgressIndicator())
              : rideHistoryProvider.error != null
                  ? Center(
                      child: Text('加载乘车历史失败: ${rideHistoryProvider.error}'))
                  : _buildRideHistoryStats(rideHistoryProvider.rides),
        ],
      ),
    );
  }

  Widget _buildRideHistoryStats(List<RideInfo> rides) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 将预约信息数量放入一个卡片中
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '共有 ${rides.length} 条预约信息',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
