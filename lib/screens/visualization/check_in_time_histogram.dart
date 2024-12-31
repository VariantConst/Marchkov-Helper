import 'package:flutter/material.dart';
import '../../models/ride_info.dart';
import 'package:fl_chart/fl_chart.dart';

class CheckInTimeHistogram extends StatefulWidget {
  final List<RideInfo> rides;

  CheckInTimeHistogram({required this.rides});

  @override
  State<CheckInTimeHistogram> createState() => _CheckInTimeHistogramState();
}

class _CheckInTimeHistogramState extends State<CheckInTimeHistogram> {
  Map<String, dynamic>? _chartData;
  Map<int, List<RideInfo>> _timeRangeRides = {};

  void _showTimeDetails(BuildContext context, int minutes, Offset tapPosition) {
    final theme = Theme.of(context);
    final rides = _timeRangeRides[minutes] ?? [];

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final size = overlay.size;

    const double tooltipWidth = 120.0;
    const double tooltipHeight = 80.0;

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
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow
                            .withAlpha((0.08 * 255).toInt()),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        minutes < 0 ? '提前' : '迟到',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${minutes.abs()}分钟',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: minutes < 0
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${rides.length}次',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
    _chartData ??= _prepareHistogramData(context);
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    if (_chartData == null) {
      return Center(child: CircularProgressIndicator());
    }

    final data = _chartData!;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.center,
                    maxY: data['maxY'],
                    minY: 0,
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
                          final minutes = response!.spot!.touchedBarGroup.x;
                          final RenderBox box =
                              context.findRenderObject() as RenderBox;
                          final Offset localPosition =
                              (event as FlTapUpEvent).localPosition;
                          final Offset globalPosition =
                              box.localToGlobal(localPosition);

                          _showTimeDetails(
                            context,
                            minutes.toInt(),
                            globalPosition,
                          );
                        }
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: data['interval'],
                          getTitlesWidget: (value, meta) {
                            if (value % data['interval'] != 0 ||
                                value >= data['maxY']) {
                              return SizedBox.shrink();
                            }
                            return Text(
                              value.toInt().toString(),
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
                          interval: 2,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final minutes = value.toInt();
                            if (minutes % 2 == 0) {
                              return Container(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  '${minutes > 0 ? '+' : ''}$minutes',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return SizedBox.shrink();
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
                      horizontalInterval: data['interval'],
                      verticalInterval: 2,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data['barGroups'],
                  ),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(
                    context,
                    color: theme.colorScheme.secondary,
                    label: '提前签到',
                  ),
                  SizedBox(width: 24),
                  _buildLegendItem(
                    context,
                    color: theme.colorScheme.primary,
                    label: '迟到签到',
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

  Map<String, dynamic> _prepareHistogramData(BuildContext context) {
    _timeRangeRides.clear();

    for (var ride in widget.rides) {
      if (ride.statusName == '已签到' && ride.appointmentSignTime != null) {
        try {
          DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
          DateTime signTime = DateTime.parse(ride.appointmentSignTime!);
          int difference = signTime.difference(appointmentTime).inMinutes;
          int clampedDiff = difference.clamp(-10, 10);
          _timeRangeRides.putIfAbsent(clampedDiff, () => []).add(ride);
        } catch (e) {
          continue;
        }
      }
    }

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = -10; i <= 10; i++) {
      final count = _timeRangeRides[i]?.length ?? 0;
      if (count > maxY) maxY = count.toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: i < 0
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
              width: 12,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    maxY = maxY + 1;
    double interval = (maxY / 5).ceilToDouble();
    if (interval < 1) interval = 1;

    return {
      'barGroups': barGroups,
      'maxY': maxY,
      'interval': interval,
    };
  }

  @override
  void didUpdateWidget(CheckInTimeHistogram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rides != oldWidget.rides) {
      setState(() {
        _chartData = _prepareHistogramData(context);
      });
    }
  }
}
