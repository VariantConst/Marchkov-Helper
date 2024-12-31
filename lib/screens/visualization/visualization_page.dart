import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_history_provider.dart';
import '../../models/ride_info.dart';
import 'ride_calendar_card.dart';
import 'departure_time_bar_chart.dart';
import 'check_in_time_histogram.dart';
import 'checked_in_reserved_pie_chart.dart';
import 'ride_heatmap.dart';
import '../../providers/visualization_settings_provider.dart';
import 'annual_summary_card.dart';

class VisualizationSettingsPage extends StatefulWidget {
  @override
  State<VisualizationSettingsPage> createState() =>
      _VisualizationSettingsPageState();
}

class _VisualizationSettingsPageState extends State<VisualizationSettingsPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  late AnimationController _filterController;
  late Animation<double> _filterRotation;
  bool _isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _filterController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _filterRotation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _filterController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<RideHistoryProvider>(context, listen: false)
          .loadRideHistory();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Map<TimeRange, Map<String, dynamic>> get timeRangeInfo => {
        TimeRange.threeMonths: {
          'icon': Icons.calendar_today,
          'label': '过去3个月',
          'shortLabel': '3个月',
        },
        TimeRange.sixMonths: {
          'icon': Icons.date_range_outlined,
          'label': '过去半年',
          'shortLabel': '半年',
        },
        TimeRange.oneYear: {
          'icon': Icons.calendar_month,
          'label': '过去一年',
          'shortLabel': '一年',
        },
        TimeRange.all: {
          'icon': Icons.all_inclusive,
          'label': '全部时间',
          'shortLabel': '全部',
        },
      };

  List<RideInfo> _filterRides(List<RideInfo> rides) {
    final selectedTimeRange =
        Provider.of<VisualizationSettingsProvider>(context).selectedTimeRange;
    final now = DateTime.now();
    late DateTime startDate;

    switch (selectedTimeRange) {
      case TimeRange.threeMonths:
        startDate = now.subtract(Duration(days: 90));
        break;
      case TimeRange.sixMonths:
        startDate = now.subtract(Duration(days: 180));
        break;
      case TimeRange.oneYear:
        startDate = now.subtract(Duration(days: 365));
        break;
      case TimeRange.all:
        return rides;
    }

    return rides.where((ride) {
      DateTime rideDate = DateTime.parse(ride.appointmentTime);
      return rideDate.isAfter(startDate) && rideDate.isBefore(now);
    }).toList();
  }

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
      if (_isFilterExpanded) {
        _filterController.forward();
      } else {
        _filterController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rideHistoryProvider = Provider.of<RideHistoryProvider>(context);

    if (rideHistoryProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('预约历史', style: theme.textTheme.titleLarge),
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (rideHistoryProvider.error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('预约历史', style: theme.textTheme.titleLarge),
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              SizedBox(height: 16),
              Text('加载失败，请重试'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  rideHistoryProvider.loadRideHistory();
                },
                child: Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    final rides = _filterRides(rideHistoryProvider.rides);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '预约历史',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        actions: [
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleFilter,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 36,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withAlpha((0.8 * 255).toInt()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeRangeInfo[context
                              .watch<VisualizationSettingsProvider>()
                              .selectedTimeRange]!['shortLabel'],
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 4),
                        RotationTransition(
                          turns: _filterRotation,
                          child: Icon(
                            Icons.expand_more,
                            size: 20,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant
                      .withAlpha((0.5 * 255).toInt()),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 0; i < 6; i++)
                    _buildTabButton(
                      context: context,
                      index: i,
                      isSelected: _currentPage == i,
                      icon: [
                        Icons.summarize_outlined,
                        Icons.calendar_month_outlined,
                        Icons.grid_4x4_outlined,
                        Icons.pie_chart_outline,
                        Icons.bar_chart_outlined,
                        Icons.schedule_outlined,
                      ][i],
                      title: [
                        '年度总结',
                        '预约日历',
                        '预约热力图',
                        '违约统计',
                        '各时段出发班次统计',
                        '签到时间差分布',
                      ][i],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildChartSection(
                key: ValueKey('summary_${rideHistoryProvider.rides.length}'),
                icon: Icons.summarize_outlined,
                title: '年度总结',
                content: AnnualSummaryCard(rides: rideHistoryProvider.rides),
              ),
              _buildChartSection(
                key: ValueKey('calendar_${rides.length}'),
                icon: Icons.calendar_month_outlined,
                title: '预约日历',
                content: RideCalendarCard(rides: rides),
              ),
              _buildChartSection(
                key: ValueKey('heatmap_${rides.length}'),
                icon: Icons.grid_4x4_outlined,
                title: '预约热力图',
                content: RideHeatmap(rides: rides),
              ),
              _buildChartSection(
                icon: Icons.pie_chart_outline,
                title: '违约统计',
                content: CheckedInReservedPieChart(rides: rides),
              ),
              _buildChartSection(
                key: ValueKey('bar_${rides.length}'),
                icon: Icons.bar_chart_outlined,
                title: '各时段出发班次统计',
                content: DepartureTimeBarChart(rides: rides),
              ),
              _buildChartSection(
                icon: Icons.schedule_outlined,
                title: '签到时间差（分钟）分布',
                content: CheckInTimeHistogram(rides: rides),
              ),
            ],
          ),
          if (_isFilterExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFilter,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          if (_isFilterExpanded)
            Positioned(
              top: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Card(
                  margin: EdgeInsets.only(top: 8, right: 8),
                  elevation: 8,
                  shadowColor:
                      theme.colorScheme.shadow.withAlpha((0.2 * 255).toInt()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outlineVariant
                                      .withAlpha((0.5 * 255).toInt()),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '时间范围',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: TimeRange.values
                                  .map((range) => _buildFilterOption(range))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(TimeRange range) {
    final theme = Theme.of(context);
    final info = timeRangeInfo[range]!;
    final visualizationSettings =
        Provider.of<VisualizationSettingsProvider>(context);
    final isSelected = visualizationSettings.selectedTimeRange == range;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          visualizationSettings.setTimeRange(range);
          Future.delayed(Duration(milliseconds: 200), () {
            _toggleFilter();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest
                          .withAlpha((0.5 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  info['icon'] as IconData,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  info['label'] as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w500 : null,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection({
    Key? key,
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.fromLTRB(16, 24, 16, 16),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest
          .withAlpha((0.3 * 255).toInt()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required int index,
    required bool isSelected,
    required IconData icon,
    required String title,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                      .withAlpha((0.8 * 255).toInt())
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (isSelected) ...[
                  SizedBox(width: 8),
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
