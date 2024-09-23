import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/ride_info.dart';

class CheckedInReservedPieChart extends StatelessWidget {
  final List<RideInfo> rides;

  CheckedInReservedPieChart({required this.rides});

  @override
  Widget build(BuildContext context) {
    final data = _preparePieData();

    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 居中对齐
              children: [
                Flexible(
                  child: PieChart(
                    PieChartData(
                      sections: data,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                SizedBox(height: 16), // 饼图和图例之间的间距
                // 图例紧接着饼图下方
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LegendItem(color: Colors.blue, text: '已签到'),
                    SizedBox(width: 16),
                    LegendItem(color: Colors.orange, text: '已预约'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _preparePieData() {
    // 修改以下两行，使用 statusName 字段
    int checkedInCount = rides.where((ride) => ride.statusName == '已签到').length;
    int reservedCount = rides.where((ride) => ride.statusName == '已预约').length;

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

    // 修改 _preparePieData 方法中的 PieChartSectionData，添加具体数量并将文字移到饼外部
    return [
      PieChartSectionData(
        color: Colors.blue,
        value: checkedInPercentage,
        title:
            '${checkedInPercentage.toStringAsFixed(1)}% ($checkedInCount)', // 保留数量
        radius: 50,
        titleStyle: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
        titlePositionPercentageOffset: 1.6, // 将标题位置进一步偏移到饼图外部
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: reservedPercentage,
        title:
            '${reservedPercentage.toStringAsFixed(1)}% ($reservedCount)', // 保留数量
        radius: 50,
        titleStyle: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
        titlePositionPercentageOffset: 1.6, // 将标题位置进一步偏移到饼图外部
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
