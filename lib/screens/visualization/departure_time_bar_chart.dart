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
  Map<int, List<RideInfo>> _toYanyuanRides = {};
  Map<int, List<RideInfo>> _toChangpingRides = {};

  void _showTimeDetails(BuildContext context, int hour, Offset tapPosition) {
    final theme = Theme.of(context);
    final toYanyuan = _toYanyuanRides[hour] ?? [];
    final toChangping = _toChangpingRides[hour] ?? [];

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final size = overlay.size;

    const double tooltipWidth = 280.0;
    const double tooltipHeight = 120.0;

    double dx = tapPosition.dx - (tooltipWidth / 2);
    double dy = tapPosition.dy - tooltipHeight - 8;

    if (dx + tooltipWidth > size.width - 8) {
      dx = size.width - tooltipWidth - 8;
    }
    if (dx < 8) dx = 8;

    if (dy < 8) {
      dy = tapPosition.dy + 8;
    }

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
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
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${hour.toString().padLeft(2, '0')}:00 - ${(hour + 1).toString().padLeft(2, '0')}:00',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _buildDirectionStat(
                              context,
                              '去燕园',
                              toYanyuan.length,
                              theme.colorScheme.secondary,
                            ),
                            SizedBox(width: 16),
                            _buildDirectionStat(
                              context,
                              '去昌平',
                              toChangping.length,
                              theme.colorScheme.primary,
                            ),
                          ],
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

  Widget _buildDirectionStat(
      BuildContext context, String direction, int count, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              direction,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 4),
            Text(
              count.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '次预约',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.center,
                    maxY: adjustedMaxY,
                    minY: adjustedMinY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (_, __, ___, ____) => null,
                      ),
                      touchCallback: (FlTouchEvent event, response) {
                        if (event.runtimeType == FlTapUpEvent &&
                            response?.spot != null) {
                          final hour = response!.spot!.touchedBarGroup.x;
                          final RenderBox box =
                              context.findRenderObject() as RenderBox;
                          final Offset localPosition =
                              (event as FlTapUpEvent).localPosition;
                          final Offset globalPosition =
                              box.localToGlobal(localPosition);

                          _showTimeDetails(
                            context,
                            hour.toInt(),
                            globalPosition,
                          );
                        }
                      },
                    ),
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
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: interval,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data?['barGroups'],
                    extraLinesData: ExtraLinesData(horizontalLines: [
                      HorizontalLine(y: 0, color: Colors.black, strokeWidth: 1),
                    ]),
                  ),
                ),
              ),
            ),
            // 图例部分使用新的设计
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(
                    context,
                    color: Theme.of(context).colorScheme.primary,
                    label: '去昌平',
                  ),
                  SizedBox(width: 24),
                  _buildLegendItem(
                    context,
                    color: Theme.of(context).colorScheme.secondary,
                    label: '去燕园',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _prepareChartData(BuildContext context) {
    _toYanyuanRides.clear();
    _toChangpingRides.clear();

    for (var ride in widget.rides) {
      DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
      int hour = appointmentTime.hour;

      String resourceName = ride.resourceName;
      int indexYan = resourceName.indexOf('燕');
      int indexXin = resourceName.indexOf('新');

      if (indexYan == -1 || indexXin == -1) continue;

      if (indexXin < indexYan) {
        _toYanyuanRides.putIfAbsent(hour, () => []).add(ride);
      } else if (indexYan < indexXin) {
        _toChangpingRides.putIfAbsent(hour, () => []).add(ride);
      }
    }

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    double minY = 0;

    for (int i = 6; i <= 23; i++) {
      int toYanyuanCount = _toYanyuanRides[i]?.length ?? 0;
      int toChangpingCount = _toChangpingRides[i]?.length ?? 0;

      if (toChangpingCount > maxY) maxY = toChangpingCount.toDouble();
      if (-toYanyuanCount < minY) minY = -toYanyuanCount.toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          groupVertically: true,
          barRods: [
            BarChartRodData(
              fromY: 0,
              toY: toChangpingCount.toDouble(),
              color: Theme.of(context).colorScheme.primary,
              width: 12,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              fromY: 0,
              toY: -toYanyuanCount.toDouble(),
              color: Theme.of(context).colorScheme.secondary,
              width: 12,
              borderRadius: BorderRadius.only(
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
