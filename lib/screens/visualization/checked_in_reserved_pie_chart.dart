import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/ride_info.dart';
import 'dart:math' show max;

class CheckedInReservedPieChart extends StatefulWidget {
  final List<RideInfo> rides;

  CheckedInReservedPieChart({required this.rides});

  @override
  State<CheckedInReservedPieChart> createState() =>
      _CheckedInReservedPieChartState();
}

class _CheckedInReservedPieChartState extends State<CheckedInReservedPieChart> {
  Map<String, dynamic>? _chartData;
  int? _touchedIndex;
  Map<DateTime, List<RideInfo>>? _dailyRides;
  List<FlSpot>? _violationRateSpots;
  double? _maxViolationRate;

  @override
  void initState() {
    super.initState();
    _processRideData();
  }

  void _processRideData() {
    if (widget.rides.isEmpty) {
      _dailyRides = {};
      _violationRateSpots = [];
      _maxViolationRate = 0;
      return;
    }

    // 按日期分组rides
    _dailyRides = {};
    for (var ride in widget.rides) {
      final date = DateTime.parse(ride.appointmentTime.split(' ')[0]);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      _dailyRides![normalizedDate] ??= [];
      _dailyRides![normalizedDate]!.add(ride);
    }

    // 计算每日违约率
    final List<MapEntry<DateTime, double>> dailyRates = [];
    _dailyRides!.forEach((date, rides) {
      final violations = rides.where((r) => r.statusName == '已预约').length;
      final rate = rides.isEmpty ? 0.0 : violations / rides.length.toDouble();
      dailyRates.add(MapEntry(date, rate));
    });

    // 按日期排序
    dailyRates.sort((a, b) => a.key.compareTo(b.key));

    // 计算30天移动平均
    _violationRateSpots = [];
    for (int i = 0; i < dailyRates.length; i++) {
      final startIdx = i >= 29 ? i - 29 : 0;
      final window = dailyRates.sublist(startIdx, i + 1);
      final avgRate =
          window.map((e) => e.value).reduce((a, b) => a + b) / window.length;

      // 将日期转换为x轴上的位置（使用距今天数）
      final daysFromStart =
          dailyRates[i].key.difference(dailyRates.first.key).inDays.toDouble();
      _violationRateSpots!.add(FlSpot(daysFromStart, avgRate));
    }

    _maxViolationRate = _violationRateSpots!.map((spot) => spot.y).reduce(max);
    if (_maxViolationRate == 0) _maxViolationRate = 1.0;
  }

  void _showLineTooltip(BuildContext context, LineTouchResponse touchResponse) {
    if (!touchResponse.lineBarSpots!.isNotEmpty) {
      return;
    }

    final spot = touchResponse.lineBarSpots!.first;
    final firstDate = _dailyRides!.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    firstDate.add(Duration(days: spot.x.toInt()));
  }

  Widget _buildLineChart(BuildContext context) {
    if (_violationRateSpots == null || _violationRateSpots!.isEmpty) {
      return SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final lastLabelPosition = (_violationRateSpots!.last.x / 30).floor() * 30;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 16, 12, 16),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (response == null || response.lineBarSpots == null) {
                return;
              }
              if (event is FlTapUpEvent || event is FlPanUpdateEvent) {
                _showLineTooltip(context, response);
              }
            },
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tooltipMargin: 4,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  return LineTooltipItem(
                    '${(touchedSpot.y * 100).toStringAsFixed(1)}%',
                    theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList();
              },
            ),
            getTouchedSpotIndicator:
                (LineChartBarData barData, List<int> indicators) {
              return indicators.map((int index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: theme.colorScheme.secondary
                        .withAlpha((0.2 * 255).toInt()),
                    strokeWidth: 2,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: theme.colorScheme.secondary,
                      strokeWidth: 2,
                      strokeColor: theme.colorScheme.surface,
                    ),
                  ),
                );
              }).toList();
            },
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 0.2,
            verticalInterval: 30,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.colorScheme.outlineVariant
                    .withAlpha((0.3 * 255).toInt()),
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: theme.colorScheme.outlineVariant
                    .withAlpha((0.3 * 255).toInt()),
                strokeWidth: 1,
                dashArray: [4, 4],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 30,
                getTitlesWidget: (value, meta) {
                  if (value > lastLabelPosition) return const SizedBox.shrink();

                  if (_violationRateSpots!.isEmpty) return const Text('');
                  final firstDate =
                      _dailyRides!.keys.reduce((a, b) => a.isBefore(b) ? a : b);
                  final date = firstDate.add(Duration(days: value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${date.month}月',
                      style: theme.textTheme.bodySmall?.copyWith(
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
                interval: 0.2,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value * 100).toInt()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant
                    .withAlpha((0.5 * 255).toInt()),
                width: 1,
              ),
              left: BorderSide(
                color: theme.colorScheme.outlineVariant
                    .withAlpha((0.5 * 255).toInt()),
                width: 1,
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: _violationRateSpots!,
              isCurved: false,
              color: theme.colorScheme.secondary,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color:
                    theme.colorScheme.secondary.withAlpha((0.1 * 255).toInt()),
              ),
            ),
          ],
          minY: 0,
          maxY: (_maxViolationRate! * 1.2).clamp(0.0, 1.0),
          minX: 0,
          maxX: _violationRateSpots!.last.x,
        ),
      ),
    );
  }

  Widget _buildLineChartHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        '30天移动平均违约率',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, int index, Offset tapPosition) {
    if (index < 0 || index >= (_chartData?['sections']?.length ?? 0)) {
      return;
    }

    final theme = Theme.of(context);
    final data = _chartData!['sections'][index];

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
                        data['title'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${data['count']}次',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: data['color'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${data['percentage'].toStringAsFixed(1)}%',
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
    _chartData ??= _preparePieData(context);
    final theme = Theme.of(context);

    if (_chartData == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 饼图标题
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            '违约率饼图',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // 上半部分（饼图）- 占比增加到0.4
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            children: [
              // 饼图
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: PieChart(
                    PieChartData(
                      sections: _chartData!['sections']
                          .asMap()
                          .entries
                          .map<PieChartSectionData>((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final isTouched = index == _touchedIndex;
                        final radius = isTouched ? 60.0 : 50.0;

                        return PieChartSectionData(
                          color: data['color'],
                          value: data['percentage'],
                          title: '',
                          radius: radius,
                          titlePositionPercentageOffset: 1.6,
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (event.runtimeType == FlTapUpEvent) {
                            final touchedSection =
                                pieTouchResponse?.touchedSection;
                            if (touchedSection == null) {
                              setState(() {
                                _touchedIndex = null;
                              });
                              return;
                            }

                            final sectionIndex =
                                touchedSection.touchedSectionIndex;
                            final RenderBox box =
                                context.findRenderObject() as RenderBox;
                            final Offset localPosition =
                                (event as FlTapUpEvent).localPosition;
                            final Offset globalPosition =
                                box.localToGlobal(localPosition);

                            setState(() {
                              _touchedIndex = sectionIndex;
                            });

                            _showDetails(
                              context,
                              sectionIndex,
                              globalPosition,
                            );
                          } else {
                            setState(() {
                              _touchedIndex = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // 图例移到底部
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
                      color: theme.colorScheme.primary,
                      label: '已签到',
                    ),
                    SizedBox(width: 24),
                    _buildLegendItem(
                      context,
                      color: theme.colorScheme.secondary,
                      label: '已违约',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
        // 下半部分（折线图）
        _buildLineChartHeader(context),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: _buildLineChart(context),
          ),
        ),
      ],
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

  Map<String, dynamic> _preparePieData(BuildContext context) {
    final theme = Theme.of(context);

    int checkedInCount =
        widget.rides.where((ride) => ride.statusName == '已签到').length;
    int reservedCount =
        widget.rides.where((ride) => ride.statusName == '已预约').length;

    final total = checkedInCount + reservedCount;
    if (total == 0) {
      return {
        'sections': [
          {
            'color': theme.colorScheme.surfaceContainerHighest,
            'percentage': 100.0,
            'title': '无数据',
            'count': 0
          }
        ]
      };
    }

    double checkedInPercentage = (checkedInCount / total) * 100;
    double reservedPercentage = (reservedCount / total) * 100;

    return {
      'sections': [
        {
          'color': theme.colorScheme.primary,
          'percentage': checkedInPercentage,
          'title': '已签到',
          'count': checkedInCount
        },
        {
          'color': theme.colorScheme.secondary,
          'percentage': reservedPercentage,
          'title': '已违约',
          'count': reservedCount
        },
      ]
    };
  }

  @override
  void didUpdateWidget(CheckedInReservedPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rides != oldWidget.rides) {
      _processRideData();
      setState(() {
        _chartData = _preparePieData(context);
      });
    }
  }
}
