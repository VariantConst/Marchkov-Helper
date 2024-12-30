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

    final sortedEntries = monthlyRides.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final interval = _calcInterval(maxCount);

    return Container(
      height: 160,
      padding: EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxCount <= 0 ? 1 : (maxCount * 2).toDouble(),
          minY: 0,
          titlesData: FlTitlesData(
            show: true,
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedEntries.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          barGroups: List.generate(
            sortedEntries.length,
            (index) => BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: sortedEntries[index].value.toDouble(),
                  color: theme.colorScheme.primary,
                  width: 16,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(2),
                    bottom: Radius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _calcInterval(int maxCount) {
    if (maxCount < 1) {
      return 1;
    }

    double step = 5;
    while ((maxCount / step) > 5) {
      step += 5;
    }
    return step;
  }
}
