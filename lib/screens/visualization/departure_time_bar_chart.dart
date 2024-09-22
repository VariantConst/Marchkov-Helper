import 'package:flutter/material.dart';
import '../../models/ride_info.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class DepartureTimeBarChart extends StatelessWidget {
  final List<RideInfo> rides;

  DepartureTimeBarChart({required this.rides});

  @override
  Widget build(BuildContext context) {
    // 处理数据
    final data = _prepareChartData();

    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            '各时段出发班次统计',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: data['maxY'],
                minY: data['minY'],
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int index = value.toInt();
                        if (index % 2 == 0) {
                          return Transform.rotate(
                            angle: pi / 3, // 60度旋转（pi/3 弧度）
                            child: Text(
                              '$index:00',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                              ),
                            ),
                          );
                        } else {
                          return SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: false),
                barGroups: data['barGroups'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _prepareChartData() {
    Map<int, int> toYanyuan = {};
    Map<int, int> toChangping = {};

    for (var ride in rides) {
      DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
      int hour = appointmentTime.hour;

      if (ride.resourceName.contains('燕园')) {
        toYanyuan[hour] = (toYanyuan[hour] ?? 0) + 1;
      } else if (ride.resourceName.contains('昌平')) {
        toChangping[hour] = (toChangping[hour] ?? 0) + 1;
      }
    }

    List<BarChartGroupData> barGroups = [];

    double maxY = 0;
    double minY = 0;

    for (int i = 0; i < 24; i++) {
      int toYanyuanCount = toYanyuan[i] ?? 0;
      int toChangpingCount = toChangping[i] ?? 0;

      if (toYanyuanCount > maxY) maxY = toYanyuanCount.toDouble();
      if (-toChangpingCount < minY) minY = -toChangpingCount.toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            // 去燕园（正值）
            BarChartRodData(
              fromY: 0,
              toY: toYanyuanCount.toDouble(),
              color: Colors.blueAccent,
              width: 8,
            ),
            // 去昌平（负值）
            BarChartRodData(
              fromY: 0,
              toY: -toChangpingCount.toDouble(),
              color: Colors.redAccent,
              width: 8,
            ),
          ],
        ),
      );
    }

    // 为了视觉效果，增加一定的上下边距
    maxY = maxY + 1;
    minY = minY - 1;

    return {
      'barGroups': barGroups,
      'maxY': maxY,
      'minY': minY,
    };
  }
}
