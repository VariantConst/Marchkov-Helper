import 'package:flutter/material.dart';
import '../../models/ride_info.dart';
import 'dart:math';

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

  void _showRideDetails(BuildContext context, DateTime date,
      List<RideInfo> rides, Offset tapPosition) {
    final theme = Theme.of(context);
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final size = overlay.size;

    // 计算最佳显示位置
    const double tooltipWidth = 280.0;
    final double tooltipHeight =
        56.0 + (rides.isEmpty ? 0 : min(rides.length, 3) * 72.0);

    // 计算初始位置，确保模态框显示在点击位置附近
    double dx = tapPosition.dx - (tooltipWidth / 2); // 居中显示
    double dy = tapPosition.dy + 8; // 默认显示在点击位置下方

    // 水平方向调整
    if (dx + tooltipWidth > size.width - 8) {
      dx = size.width - tooltipWidth - 8;
    }
    if (dx < 8) dx = 8;

    // 垂直方向调整
    if (dy + tooltipHeight > size.height - 8) {
      dy = tapPosition.dy - tooltipHeight - 8; // 如果下方放不下，就显示在上方
    }

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (_) => Navigator.of(context).pop(),
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: dx,
              top: dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: tooltipWidth,
                  constraints: BoxConstraints(
                    maxHeight: size.height * 0.3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                            bottom: rides.isEmpty
                                ? Radius.circular(12)
                                : Radius.zero,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${rides.length}次预约',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (rides.isNotEmpty)
                        Flexible(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: rides.map((ride) {
                                  final isViolation = ride.statusName == '已预约';
                                  return Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: theme
                                              .colorScheme.outlineVariant
                                              .withOpacity(0.5),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isViolation
                                                ? theme.colorScheme.error
                                                : theme.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ride.resourceName,
                                                style: theme
                                                    .textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                ride.appointmentTime
                                                    .split(' ')[1],
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isViolation
                                                ? theme
                                                    .colorScheme.errorContainer
                                                : theme.colorScheme
                                                    .primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isViolation ? '已违约' : '已签到',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: isViolation
                                                  ? theme.colorScheme
                                                      .onErrorContainer
                                                  : theme.colorScheme
                                                      .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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

    // 重新设计的图例
    Widget legend = Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('预约频率',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              )),
          SizedBox(width: 16),
          ...[0, 1, 2, 3, 4].map((count) => Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getColorForCount(count, theme.colorScheme),
                        borderRadius: BorderRadius.circular(4),
                        border: count == 0
                            ? Border.all(
                                color: theme.colorScheme.outlineVariant,
                                width: 1,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      count == 4 ? '4+' : count.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
          SizedBox(width: 8),
          Text('次/天',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算每个砖块的大小
        final availableWidth = constraints.maxWidth - 88;

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

        // 构建热力图主体
        Widget heatmapBody = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                            return GestureDetector(
                              onTapDown: (details) {
                                final rides = widget.rides.where((ride) {
                                  final rideDate = DateTime.parse(
                                      ride.appointmentTime.split(' ')[0]);
                                  return rideDate.year == date.year &&
                                      rideDate.month == date.month &&
                                      rideDate.day == date.day;
                                }).toList();

                                _showRideDetails(
                                  context,
                                  date,
                                  rides,
                                  details.globalPosition,
                                );
                              },
                              child: Container(
                                width: blockSize - 2,
                                height: blockSize - 2,
                                margin: EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  color: _getColorForCount(
                                      count, theme.colorScheme),
                                  borderRadius: BorderRadius.circular(
                                    blockSize > 24
                                        ? 4
                                        : blockSize > 20
                                            ? 3
                                            : 2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ))
                    .toList(),
              ),
            ),
          ],
        );

        return Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: heatmapBody,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
                top: 8,
              ),
              child: legend,
            ),
          ],
        );
      },
    );
  }
}
