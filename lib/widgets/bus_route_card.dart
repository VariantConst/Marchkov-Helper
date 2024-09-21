import 'package:flutter/material.dart';
import '../models/bus_route.dart';

class BusRouteCard extends StatelessWidget {
  final BusRoute busRoute;

  const BusRouteCard({Key? key, required this.busRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(busRoute.name, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            Text('起点: ${busRoute.jsonAddress.campusName}'),
            Text('终点: ${busRoute.jsonAddress.buildName}'),
            SizedBox(height: 8),
            Text('容量: ${busRoute.capacity}'),
            SizedBox(height: 8),
            Text('时间表:'),
            ...busRoute.table.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entry.value.map((timeSlot) {
                  return Text(
                    '${timeSlot.date} ${timeSlot.yaxis}: 剩余座位 ${timeSlot.row.margin}',
                  );
                }).toList(),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
