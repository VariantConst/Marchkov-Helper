import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/ride_info.dart';

class CheckedInReservedPieChart extends StatefulWidget {
  final List<RideInfo> rides;

  CheckedInReservedPieChart({required this.rides});

  @override
  State<CheckedInReservedPieChart> createState() =>
      _CheckedInReservedPieChartState();
}

class _CheckedInReservedPieChartState extends State<CheckedInReservedPieChart> {
  List<PieChartSectionData>? _pieData;

  @override
  void initState() {
    super.initState();
    _preparePieData(null, null, null);
  }

  @override
  void didUpdateWidget(CheckedInReservedPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rides != oldWidget.rides) {
      setState(() {
        _preparePieData(null, null, null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final textColor = Theme.of(context).colorScheme.onSurface;

    _pieData = _preparePieData(primaryColor, secondaryColor, textColor);

    if (_pieData == null) {
      return Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final chartHeight = availableHeight * 3 / 5; // 将图表高度设置为页面高度的 3/5

        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  height: chartHeight,
                  child: PieChart(
                    PieChartData(
                      sections: _pieData!,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // 图例
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LegendItem(
                        color: Theme.of(context).colorScheme.primary,
                        text: '已签到'),
                    SizedBox(width: 16),
                    LegendItem(
                        color: Theme.of(context).colorScheme.secondary,
                        text: '已违约'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _preparePieData(
    Color? primaryColor,
    Color? secondaryColor,
    Color? textColor,
  ) {
    int checkedInCount =
        widget.rides.where((ride) => ride.statusName == '已签到').length;
    int reservedCount =
        widget.rides.where((ride) => ride.statusName == '已预约').length;

    final total = checkedInCount + reservedCount;
    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 100,
          title: '无数据',
          radius: 50,
          titleStyle: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ];
    }

    double checkedInPercentage = (checkedInCount / total) * 100;
    double reservedPercentage = (reservedCount / total) * 100;

    return [
      PieChartSectionData(
        color: primaryColor ?? Colors.grey,
        value: checkedInPercentage,
        title: '${checkedInPercentage.toStringAsFixed(1)}% ($checkedInCount)',
        radius: 50,
        titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.black),
        titlePositionPercentageOffset: 1.6,
      ),
      PieChartSectionData(
        color: secondaryColor ?? Colors.grey.shade400,
        value: reservedPercentage,
        title: '${reservedPercentage.toStringAsFixed(1)}% ($reservedCount)',
        radius: 50,
        titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.black),
        titlePositionPercentageOffset: 1.6,
      ),
    ];
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
