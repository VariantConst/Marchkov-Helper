import 'package:flutter/material.dart';

class SummaryMonthlyBarChart extends StatelessWidget {
  final Map<int, int> monthlyRides;
  final int maxCount;

  const SummaryMonthlyBarChart({
    required this.monthlyRides,
    required this.maxCount,
  });

  String _getMonthAbbr(int month) {
    const monthAbbrs = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return monthAbbrs[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      height: 200.0,
      padding: EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          final month = index + 1;
          final count = monthlyRides[month] ?? 0;
          final opacity = maxCount > 0 ? (count / maxCount) * 0.8 + 0.1 : 0.1;

          return Container(
            decoration: BoxDecoration(
              color: primaryColor.withAlpha((opacity * 255).toInt()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // 数字和月份缩写居中布局
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        count.toString(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 1), // 极小的间距
                      Text(
                        _getMonthAbbr(month),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 8, // 更小的字号
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
