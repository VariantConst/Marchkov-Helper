import 'package:flutter/material.dart';

class BusRouteCard extends StatelessWidget {
  final Map<String, dynamic> busData;

  const BusRouteCard({Key? key, required this.busData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final routeName = busData['route_name'] ?? '未知路线';
    final date = busData['abscissa'] ?? '';
    final time = busData['yaxis'] ?? '';
    final margin = busData['row']['margin'] ?? 0;
    final id = busData['bus_id'] ?? 'N/A'; // 正确获取班车的 id
    final period = busData['time_id'] ?? 'N/A';

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routeName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text('日期：$date'),
            Text('出发时间：$time'),
            Text('剩余座位：$margin'),
            Text('id：$id'), // 显示班车的 id
            Text('period：$period'),
          ],
        ),
      ),
    );
  }
}
