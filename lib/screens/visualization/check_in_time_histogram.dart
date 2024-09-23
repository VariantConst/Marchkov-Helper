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
        final chartHeight = availableHeight * 2 / 3;

        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                '签到时间差（分钟）分布',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              SizedBox(
                height: chartHeight,
                child: BarChart(
                  BarChartData(
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
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            // 设置 x 轴的刻度间隔
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
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: data['interval'],
                        verticalInterval: 2,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: data['barGroups'],
                      baselineY: 0),
                ),
              ),
              SizedBox(height: 8),
              // 添加图例
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LegendItem(color: Colors.green, text: '提前签到'),
                  SizedBox(width: 16),
                  LegendItem(color: Colors.red, text: '迟到签到'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _prepareHistogramData() {
    List<int> timeDifferences = [];

    for (var ride in rides) {
      if (ride.appointmentSignTime != null &&
          ride.appointmentSignTime!.isNotEmpty) {
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

    // 确保包含所有从 -10 ��� 10 的 x 值
    List<BarChartGroupData> barGroups = [];
    for (int i = -10; i <= 10; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (frequencyMap[i] ?? 0).toDouble(),
              color: i < 0 ? Colors.green : Colors.red, // 负数为绿色，正数为红色
              width: 4,
              borderRadius: BorderRadius.circular(0),
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
