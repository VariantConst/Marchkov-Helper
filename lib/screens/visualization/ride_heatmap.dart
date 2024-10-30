import 'package:flutter/material.dart';
import '../../models/ride_info.dart';

class RideHeatmap extends StatefulWidget {
  final List<RideInfo> rides;

  RideHeatmap({required this.rides});

  @override
  State<RideHeatmap> createState() => _RideHeatmapState();
}

class _RideHeatmapState extends State<RideHeatmap> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 在下一帧滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<DateTime, int> _groupRidesByDate() {
    Map<DateTime, int> groupedRides = {};
    for (var ride in widget.rides) {
      DateTime rideDate = DateTime.parse(ride.appointmentTime.split(' ')[0]);
      rideDate = DateTime(rideDate.year, rideDate.month, rideDate.day);
      groupedRides[rideDate] = (groupedRides[rideDate] ?? 0) + 1;
    }
    return groupedRides;
  }

  Color _getColorForCount(int count, ColorScheme colorScheme) {
    if (count == 0) return colorScheme.surfaceContainerHighest;

    final baseColor = colorScheme.primary;
    switch (count) {
      case 1:
        return baseColor.withOpacity(0.3);
      case 2:
        return baseColor.withOpacity(0.5);
      case 3:
        return baseColor.withOpacity(0.7);
      default:
        return baseColor; // >= 4
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedRides = _groupRidesByDate();

    // 获取最早和最晚的日期
    final dates = groupedRides.keys.toList()..sort();
    final firstDate = dates.isEmpty ? DateTime.now() : dates.first;
    final lastDate = DateTime.now();

    // 生成所有日期列表
    List<DateTime> allDates = [];
    DateTime currentDate = firstDate;
    while (currentDate.isBefore(lastDate) ||
        currentDate.isAtSameMomentAs(lastDate)) {
      allDates.add(currentDate);
      currentDate = currentDate.add(Duration(days: 1));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算每个砖块的大小
        final availableWidth = constraints.maxWidth - 80;

        // 根据总天数动态计算每行显示的砖块数量
        int blocksPerRow;
        double blockSize;

        final totalDays = allDates.length;
        if (totalDays <= 90) {
          // 3个月以内
          blocksPerRow = (availableWidth / 36).floor(); // 较大砖块
        } else if (totalDays <= 180) {
          // 半年以内
          blocksPerRow = (availableWidth / 30).floor(); // 中等砖块
        } else if (totalDays <= 365) {
          // 一年以内
          blocksPerRow = (availableWidth / 24).floor(); // 较小砖块
        } else {
          // 超过一年
          // 动态计算，确保总高度不会过高
          final desiredRows =
              (constraints.maxHeight * 0.7) ~/ 20; // 期望的行数，假设最小砖块高度为20
          blocksPerRow = (totalDays / desiredRows).ceil();
          // 确保每行至少能显示10个砖块
          blocksPerRow = blocksPerRow.clamp(10, (availableWidth / 16).floor());
        }

        blockSize = (availableWidth / blocksPerRow).floorToDouble();

        // 将日期分组到行
        List<List<DateTime>> rows = [];
        for (int i = 0; i < allDates.length; i += blocksPerRow) {
          final end = i + blocksPerRow;
          rows.add(allDates.sublist(
              i, end > allDates.length ? allDates.length : end));
        }

        // 计算每个月份区间
        List<MapEntry<String, double>> monthRanges = [];
        int currentMonth = -1;
        int currentYear = -1;
        int currentRowStart = 0;

        for (int i = 0; i < rows.length; i++) {
          final date = rows[i].first;
          if (date.month != currentMonth ||
              date.year != currentYear ||
              i == rows.length - 1) {
            if (currentMonth != -1) {
              final height =
                  (i - currentRowStart + (i == rows.length - 1 ? 1 : 0)) *
                      blockSize;
              monthRanges.add(MapEntry(
                '$currentYear.${currentMonth.toString().padLeft(2, '0')}',
                height,
              ));
            }
            currentMonth = date.month;
            currentYear = date.year;
            currentRowStart = i;
          }
        }

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图例说明
              Padding(
                padding: EdgeInsets.only(bottom: 16, left: 24),
                child: Row(
                  children: [
                    Text('乘车频率：',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    SizedBox(width: 8),
                    ...[0, 1, 2, 3, 4].map((count) => Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  _getColorForCount(count, theme.colorScheme),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        )),
                    Text(' (0-4+次/天)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              // 热力图主体
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 月份标签
                  Column(
                    children: monthRanges
                        .map((entry) => Container(
                              height: entry.value,
                              width: 44,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                entry.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  SizedBox(width: 4),
                  // 日期网格
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rows
                          .map((row) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: row.map((date) {
                                  final count = groupedRides[date] ?? 0;
                                  return Container(
                                    width: blockSize - 2,
                                    height: blockSize - 2,
                                    margin: EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      color: _getColorForCount(
                                          count, theme.colorScheme),
                                      borderRadius: BorderRadius.circular(
                                        blockSize > 24
                                            ? 4
                                            : // 大砖块
                                            blockSize > 20
                                                ? 3
                                                : // 中砖块
                                                2, // 小砖块
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
