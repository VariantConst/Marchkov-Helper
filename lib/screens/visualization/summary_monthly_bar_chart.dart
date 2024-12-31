import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SummaryMonthlyBarChart extends StatelessWidget {
  final Map<int, int> monthlyRides;
  final int maxCount;

  const SummaryMonthlyBarChart({
    required this.monthlyRides,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 对月份-次数进行排序
    final sortedEntries = monthlyRides.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      height: 200.0,
      padding: EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipPadding: EdgeInsets.all(8),
              tooltipBorder: BorderSide.none,
              tooltipMargin: 8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${sortedEntries[group.x].value}次',
                  TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedEntries.length) {
                    return SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '${sortedEntries[index].key}月',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: false,
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(
            sortedEntries.length,
            (index) {
              final ridesCount = sortedEntries[index].value.toDouble();
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: ridesCount,
                    color: theme.colorScheme.primary,
                    width: 16,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(2),
                      bottom: Radius.circular(2),
                    ),
                    // 应用归一化系数
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      color: theme.colorScheme.primary
                          .withAlpha((0.1 * 255).toInt()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
