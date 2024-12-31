import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SummaryViolationPieChart extends StatelessWidget {
  final int totalRides;
  final int violationCount;

  const SummaryViolationPieChart({
    required this.totalRides,
    required this.violationCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedInCount = totalRides - violationCount;
    final violationRate =
        (violationCount / totalRides * 100).toStringAsFixed(1);
    final checkedInRate =
        ((checkedInCount) / totalRides * 100).toStringAsFixed(1);

    return SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    color: theme.colorScheme.primary,
                    value: checkedInCount.toDouble(),
                    title: '',
                    radius: 25,
                  ),
                  PieChartSectionData(
                    color: theme.colorScheme.secondary,
                    value: violationCount.toDouble(),
                    title: '',
                    radius: 25,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(
                context,
                color: theme.colorScheme.primary,
                label: '准时签到',
                rate: '$checkedInRate%',
              ),
              SizedBox(height: 8),
              _buildLegendItem(
                context,
                color: theme.colorScheme.secondary,
                label: '未能签到',
                rate: '$violationRate%',
              ),
            ],
          ),
          SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
    required String rate,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              rate,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
