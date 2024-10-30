import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/ride_info.dart';

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
                        color: theme.colorScheme.shadow.withOpacity(0.08),
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
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
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
                      final touchedSection = pieTouchResponse?.touchedSection;
                      if (touchedSection == null) {
                        setState(() {
                          _touchedIndex = null;
                        });
                        return;
                      }

                      final sectionIndex = touchedSection.touchedSectionIndex;
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
            'percentage': 100,
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
      setState(() {
        _chartData = _preparePieData(context);
      });
    }
  }
}
