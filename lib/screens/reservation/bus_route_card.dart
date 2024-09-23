import 'package:flutter/material.dart';

class BusRouteCard extends StatelessWidget {
  final Map<String, dynamic> busData;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress; // 新增
  final bool isReserved; // 新增
  final bool isPast; // 新增
  final Color cardColor; // 新增

  const BusRouteCard({
    Key? key,
    required this.busData,
    this.onTap,
    this.onLongPress, // 新增
    this.isReserved = false, // 新增
    this.isPast = false, // 新增
    required this.cardColor, // 新增
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String departureTime = busData['yaxis'] ?? '';
    int seatsLeft = busData['row']['margin'] ?? 0;

    return GestureDetector(
      onTap: isPast ? null : onTap, // 如果过期，不可点击
      onLongPress: onLongPress, // 新增
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16),
        height: 72,
        decoration: BoxDecoration(
          color: isReserved
              ? isPast
                  ? Colors.grey[300] // 已过期的预约班车用淡灰色
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : cardColor, // 使用传入的 cardColor
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.directions_bus, color: Colors.blueAccent, size: 32),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departureTime,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$seatsLeft 个座位剩余',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent, // 修改为 backgroundColor
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text('预约'),
            ),
          ],
        ),
      ),
    );
  }
}

class BusRouteDetails extends StatelessWidget {
  final Map<String, dynamic> busData;

  const BusRouteDetails({Key? key, required this.busData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final routeName = busData['route_name'] ?? '未知路线';
    final date = busData['abscissa'] ?? '';
    final time = busData['yaxis'] ?? '';
    final margin = busData['row']['margin'] ?? 0;
    final id = busData['bus_id']?.toString() ?? 'N/A'; // 转换为字符串
    final period = busData['time_id']?.toString() ?? 'N/A'; // 转换为字符串

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            routeName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 16),
          _buildDetailRow(context, '日期', date),
          _buildDetailRow(context, '出发时间', time),
          _buildDetailRow(context, '剩余座位', margin.toString()),
          _buildDetailRow(context, 'ID', id),
          _buildDetailRow(context, 'Period', period),
          SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: Text('关闭'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
