import 'package:flutter/material.dart';
import '../../models/ride_info.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class CheckInTimeHistogram extends StatelessWidget {
  final List<RideInfo> rides;

  CheckInTimeHistogram({required this.rides});

  @override
  Widget build(BuildContext context) {
    final data = _prepareHistogramData();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final chartHeight = availableHeight * 3 / 5; // 将图表高度设置为页面高度的 3/5

        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            // 添加 Center 小部件，使内容居中
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 在垂直方向上居中对齐
              children: [
                SizedBox(
                  height: chartHeight,
                  child: BarChart(
                    BarChartData(
                      // 将 'data:' 移除，作为位置参数传递
                      alignment: BarChartAlignment.center,
                      minY: 0, // Y轴从0开始
                      maxY: data['maxY'],
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: data['interval'],
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
                          // 移动到 titlesData 内部
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            // 设置 x ��的刻度间隔
                            interval: 2,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              // 仅显示 -10 到 10 的刻度标签
                              if (value.toInt() % 2 == 0 &&
                                  value >= -10 &&
                                  value <= 10) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                  ),
                                );
                              } else {
                                return SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          // 移动到 titlesData 内部
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          // 移动到 titlesData 内部
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: data['interval'],
                        verticalInterval: 2,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: data['barGroups'],
                      baselineY: 0,
                    ), // 添加逗号并关闭 BarChartData
                  ), // 关闭 BarChart
                ),
                SizedBox(height: 8),
                // 添加图例
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LegendItem(color: Colors.amber, text: '提前签到'), // 改为琥珀色
                    SizedBox(width: 16),
                    LegendItem(color: Colors.teal, text: '迟到签到'), // 改为青色
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _prepareHistogramData() {
    List<int> timeDifferences = [];

    for (var ride in rides) {
      if (ride.statusName == '已签到') {
        // 根据 statusName 过滤
        try {
          DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
          DateTime signTime = DateTime.parse(ride.appointmentSignTime!);
          int difference = signTime.difference(appointmentTime).inMinutes;
          timeDifferences.add(difference);
        } catch (e) {
          continue;
        }
      }
    }

    // 计算频率
    Map<int, int> frequencyMap = {};
    for (var diff in timeDifferences) {
      int clampedDiff = diff.clamp(-10, 10);
      frequencyMap[clampedDiff] = (frequencyMap[clampedDiff] ?? 0) + 1;
    }

    // 确保包含所有从 -10 到 10 的 x 值
    List<BarChartGroupData> barGroups = [];
    for (int i = -10; i <= 10; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (frequencyMap[i] ?? 0).toDouble(),
              color: i < 0 ? Colors.amber : Colors.teal, // 提前签到为琥珀色，迟到签到青色
              width: 8, // 调整柱子宽度，与出发时间统计图表一致
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ), // 调整圆角样式，与出发时间统计图表一致
            ),
          ],
        ),
      );
    }

    // 计算 Y 轴的最大值
    int maxYValue =
        frequencyMap.values.isNotEmpty ? frequencyMap.values.reduce(max) : 0;
    double maxY = (maxYValue + 1).toDouble();

    // 设置间隔，确保 interval 不为零
    double interval = (maxY / 5).ceilToDouble();
    if (interval == 0) {
      interval = 1.0;
    }

    return {
      'barGroups': barGroups,
      'maxY': maxY,
      'interval': interval,
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
