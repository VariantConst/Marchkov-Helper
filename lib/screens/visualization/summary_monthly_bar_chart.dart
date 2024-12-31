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

    // 计算间隔和最大值
    final interval = _calcInterval(maxCount); // 使用简化后的间隔逻辑
    final baseMaxY = (maxCount / interval).ceil() * interval;
    final effectiveMaxY = baseMaxY * 1.1; // 预留 10% 空间

    return Container(
      height: 180.0,
      padding: EdgeInsets.fromLTRB(8, 24, 16, 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: effectiveMaxY,
          minY: 0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedEntries.length) {
                    return SizedBox.shrink();
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
                  // 只显示不超过原始 baseMaxY 的整数刻度
                  if (value % 1 != 0 || value > baseMaxY) {
                    return SizedBox.shrink();
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
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            // 只显示到 baseMaxY 的网格线
            checkToShowHorizontalLine: (value) => value <= baseMaxY,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant
                  .withAlpha(77), // 0.3 * 255 ≈ 77
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // 简易的间隔计算：让 Y 轴分成大约 4 段
  // 例如 maxCount=38 => step=10 => 刻度=[0,10,20,30,40]
  double _calcInterval(int maxCount) {
    if (maxCount <= 5) return 1;
    return (maxCount / 4.0).ceilToDouble();
  }
}
