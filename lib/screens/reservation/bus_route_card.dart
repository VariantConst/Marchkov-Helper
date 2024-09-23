import 'package:flutter/material.dart';

class BusRouteCard extends StatelessWidget {
  final Map<String, dynamic> busData;
  final VoidCallback? onTap; // 将 onTap 改为可空类型
  final VoidCallback? onLongPress;
  final bool isReserved;
  final bool isPast; // 新增 isPast 参数

  const BusRouteCard({
    Key? key,
    required this.busData,
    this.onTap, // 修改为可空类型
    this.onLongPress,
    this.isReserved = false,
    this.isPast = false, // 初始化 isPast 参数
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String departureTime = busData['yaxis'] ?? '';

    return GestureDetector(
      onTap: onTap, // 保持不变，onTap 已经是可空类型
      onLongPress: onLongPress,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isReserved
              ? isPast
                  ? Colors.grey.withOpacity(0.5) // 如果过期，显示灰色
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          border: isReserved
              ? Border.all(
                  color: isPast
                      ? Colors.grey // 如果过期，边框也显示灰色
                      : Theme.of(context).colorScheme.primary,
                  width: 2)
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  departureTime,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isReserved
                        ? isPast
                            ? Colors.grey // 如果过期，文本颜色也显示灰色
                            : Theme.of(context).colorScheme.primary
                        : isPast // 根据 isPast 改变文本颜色
                            ? Colors.grey
                            : Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            if (isReserved && !isPast)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 16,
                ),
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
