import 'package:flutter/material.dart';

class BusRouteCard extends StatelessWidget {
  final Map<String, dynamic> busData;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isReserved;
  final bool isPast;
  final Color cardColor;

  const BusRouteCard({
    super.key,
    required this.busData,
    this.onTap,
    this.onLongPress,
    this.isReserved = false,
    this.isPast = false,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    String departureTime = busData['yaxis'] ?? '';
    int seatsLeft = busData['row']['margin'] ?? 0;

    return Card(
      color: theme.cardColor, // 使用主题卡片颜色
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isPast ? null : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 时间列
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departureTime,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    '$seatsLeft 个座位剩余',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
              // 右侧按钮
              if (!isPast)
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReserved
                        ? theme.colorScheme.primary
                        : (isDarkMode ? Colors.grey[800] : Colors.white),
                    foregroundColor: isReserved
                        ? theme.colorScheme.onPrimary
                        : theme.textTheme.bodyLarge?.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(
                    isReserved ? '已预约' : '预约',
                    style: TextStyle(fontSize: 14),
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

  const BusRouteDetails({super.key, required this.busData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final routeName = busData['route_name'] ?? '未知路线';
    final date = busData['abscissa'] ?? '';
    final time = busData['yaxis'] ?? '';
    final margin = busData['row']['margin'] ?? 0;
    final id = busData['bus_id']?.toString() ?? 'N/A'; // 转换为字符串
    final period = busData['time_id']?.toString() ?? 'N/A'; // 转换为字符串

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            routeName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
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
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
