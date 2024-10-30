import 'package:flutter/material.dart';
import '../../models/ride_info.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class DepartureTimeBarChart extends StatefulWidget {
  final List<RideInfo> rides;

  DepartureTimeBarChart({required this.rides});

  @override
  State<DepartureTimeBarChart> createState() => _DepartureTimeBarChartState();
}

class _DepartureTimeBarChartState extends State<DepartureTimeBarChart> {
  Map<String, dynamic>? _chartData;

  @override
  Widget build(BuildContext context) {
    _chartData ??= _prepareChartData(context);

    if (_chartData == null) {
      return Center(child: CircularProgressIndicator());
    }

    // 处理数据
    final data = _chartData;

    // **动态计算 y 轴间隔**
    double range = data?['maxY'] - data?['minY'];
    int desiredIntervals = 9; // 期望的标签数量
    double interval = (range / desiredIntervals).ceilToDouble();

    // **调整间隔为友好的数值**
    if (interval > 10) {
      interval = (interval / 10).ceil() * 10;
    } else if (interval > 5) {
      interval = (interval / 5).ceil() * 5;
    } else {
      interval = interval.ceilToDouble();
    }

    // **调整 maxY 和 minY 为 interval 的整数倍**
    double adjustedMaxY = (data?['maxY'] / interval).ceil() * interval;
    double adjustedMinY = (data?['minY'] / interval).floor() * interval;

    final textColor = Theme.of(context).colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final chartHeight = availableHeight * 2 / 3;

        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: chartHeight,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.center,
                      maxY: adjustedMaxY,
                      minY: adjustedMinY,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: interval,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              // **只显示数据范围内的标签，且不显示最大值标签**
                              if (value >= adjustedMaxY ||
                                  value <= adjustedMinY) {
                                return SizedBox.shrink();
                              }
                              return Text(
                                value.toInt().abs().toString(),
                                style: TextStyle(
                                  color: textColor,
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
                                      color: textColor,
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
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: interval,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: data?['barGroups'],
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                            y: 0, color: Colors.black, strokeWidth: 1),
                      ]),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // 添加自定义图例
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LegendItem(
                        color: Theme.of(context).colorScheme.primary,
                        text: '去昌平'),
                    SizedBox(width: 16),
                    LegendItem(
                        color: Theme.of(context).colorScheme.secondary,
                        text: '去燕园'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _prepareChartData(BuildContext context) {
    Map<int, int> toYanyuan = {};
    Map<int, int> toChangping = {};

    for (var ride in widget.rides) {
      DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
      int hour = appointmentTime.hour;

      String resourceName = ride.resourceName;
      int indexYan = resourceName.indexOf('燕');
      int indexXin = resourceName.indexOf('新');

      if (indexYan == -1 || indexXin == -1) {
        continue;
      }

      if (indexXin < indexYan) {
        toYanyuan[hour] = (toYanyuan[hour] ?? 0) + 1;
      } else if (indexYan < indexXin) {
        toChangping[hour] = (toChangping[hour] ?? 0) + 1;
      }
    }

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    double minY = 0;

    for (int i = 6; i <= 23; i++) {
      int toYanyuanCount = toYanyuan[i] ?? 0;
      int toChangpingCount = toChangping[i] ?? 0;

      if (toChangpingCount > maxY) maxY = toChangpingCount.toDouble();
      if (-toYanyuanCount < minY) minY = -toYanyuanCount.toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              fromY: 0,
              toY: toChangpingCount.toDouble(),
              color: Theme.of(context).colorScheme.primary,
              width: 8,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            BarChartRodData(
              fromY: 0,
              toY: -toYanyuanCount.toDouble(),
              color: Theme.of(context).colorScheme.secondary,
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

    maxY = maxY + 1;
    minY = minY - 1;

    return {
      'barGroups': barGroups,
      'maxY': maxY,
      'minY': minY,
    };
  }

  @override
  void didUpdateWidget(DepartureTimeBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rides != oldWidget.rides) {
      setState(() {
        _chartData = _prepareChartData(context);
      });
    }
  }
}

// 添加例项组件
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
