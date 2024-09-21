import 'package:flutter/material.dart';
// 需要确保没有遗漏任何必要的导入

class BusRouteCard extends StatelessWidget {
  final Map<String, dynamic> busData;
  final VoidCallback onTap;

  const BusRouteCard({Key? key, required this.busData, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final time = busData['yaxis'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Container(
          width: (MediaQuery.of(context).size.width - 64) / 3, // 调整宽度
          height: 80,
          alignment: Alignment.center,
          child: Text(
            time,
            style: Theme.of(context).textTheme.titleMedium,
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
    final id = busData['bus_id'] ?? 'N/A';
    final period = busData['time_id'] ?? 'N/A';

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(routeName, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text('日期：$date'),
          Text('出发时间：$time'),
          Text('剩余座位：$margin'),
          Text('ID：$id'),
          Text('Period：$period'),
        ],
      ),
    );
  }
}
