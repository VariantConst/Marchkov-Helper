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
      child: Center(
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
                  alignment: BarChartAlignment.center,
                  maxY: data['maxY'],
                  minY: data['minY'],
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (data['maxY'] - data['minY']) / 10,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            value.toInt().abs().toString(),
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
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: 0, color: Colors.black, strokeWidth: 1),
                  ]),
                ),
              ),
            ),
            SizedBox(height: 8),
            // 添加自定义图例
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LegendItem(color: Colors.redAccent, text: '去昌平'),
                SizedBox(width: 16),
                LegendItem(color: Colors.blueAccent, text: '去燕园'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _prepareChartData() {
    Map<int, int> toYanyuan = {};
    Map<int, int> toChangping = {};

    for (var ride in rides) {
      DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
      int hour = appointmentTime.hour;

      String resourceName = ride.resourceName;
      int indexYan = resourceName.indexOf('燕');
      int indexXin = resourceName.indexOf('新');

      if (indexYan == -1 || indexXin == -1) {
        // 无法判断方向，跳过
        continue;
      }

      if (indexXin < indexYan) {
        // 去燕园
        toYanyuan[hour] = (toYanyuan[hour] ?? 0) + 1;
      } else if (indexYan < indexXin) {
        // 去昌平
        toChangping[hour] = (toChangping[hour] ?? 0) + 1;
      }
    }

    List<BarChartGroupData> barGroups = [];

    double maxY = 0;
    double minY = 0;

    // 将时间范围调整为6到23点
    for (int i = 6; i <= 23; i++) {
      int toYanyuanCount = toYanyuan[i] ?? 0;
      int toChangpingCount = toChangping[i] ?? 0;

      // 更新最大最小值
      if (toChangpingCount > maxY) maxY = toChangpingCount.toDouble();
      if (-toYanyuanCount < minY) minY = -toYanyuanCount.toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            // 去昌平（正值）
            BarChartRodData(
              fromY: 0,
              toY: toChangpingCount.toDouble(),
              color: Colors.redAccent,
              width: 8,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            // 去燕园（负值）
            BarChartRodData(
              fromY: 0,
              toY: -toYanyuanCount.toDouble(),
              color: Colors.blueAccent,
              width: 8,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(0),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
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

// 添加图例项组件
class LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}
