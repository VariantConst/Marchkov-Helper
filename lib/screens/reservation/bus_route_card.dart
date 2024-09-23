import 'package:flutter/material.dart';

class BusRouteCard extends StatelessWidget {
  final Map<String, dynamic> busData;
  final VoidCallback? onTap; // 将 onTap 改为可空类型
  final VoidCallback? onLongPress;
  final bool isReserved;
  final bool isPast; // 新增 isPast 参数
  final Color cardColor; // 新增 cardColor 参数

  const BusRouteCard({
    Key? key,
    required this.busData,
    this.onTap, // 修改为可空类型
    this.onLongPress,
    this.isReserved = false,
    this.isPast = false, // 初始化 isPast 参数
    required this.cardColor, // 添加 cardColor 参数
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String departureTime = busData['yaxis'] ?? '';

    return GestureDetector(
      onTap: isPast ? null : onTap, // 如果过期，不可点击
      onLongPress: onLongPress,
      child: SizedBox(
        // 包裹一个SizedBox，设置固定高度
        height: 50, // 设置固定高度，根据需要调整
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: 2, horizontal: 4), // 缩小 padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isReserved
                ? isPast
                    ? Colors.grey[300] // 已过期的预约班车用淡灰色
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : cardColor, // 使用传入的 cardColor
            border: isReserved
                ? Border.all(
                    color: isPast
                        ? Colors.grey // 已过期的预约班车边框用灰色
                        : Theme.of(context).colorScheme.primary,
                    width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.none, // 允许溢出部分显示
          child: Stack(
            clipBehavior: Clip.none, // 允许溢出部分显示
            children: [
              Center(
                // 确保文本居中
                child: Text(
                  departureTime,
                  style: TextStyle(
                    fontSize: 16, // 缩小文字
                    fontWeight: FontWeight.bold,
                    color: isReserved
                        ? isPast
                            ? Colors.grey // 已过期的预约班车文本用灰色
                            : Theme.of(context).colorScheme.primary
                        : isPast
                            ? Colors.grey // 已过期的非预约班车文本用灰色
                            : Colors.black, // 非预约状态下的文本颜色
                  ),
                ),
              ),
              if (isReserved)
                Positioned(
                  top: -12, // 调整位置，使其悬浮在边框内
                  right: -12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white, // 背景色为白色，确保图标清晰可见
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: isPast
                          ? Colors.grey
                          : Theme.of(context).colorScheme.primary,
                      size: 24, // 将尺寸从16调整为20
                    ),
                  ),
                ),
            ],
          ),
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
