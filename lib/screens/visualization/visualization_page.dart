import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_history_provider.dart';
import '../../models/ride_info.dart';
import 'ride_calendar_card.dart';
// 添加以下导入
import 'departure_time_bar_chart.dart';
import 'check_in_time_histogram.dart'; // 恢复导入
import 'checked_in_reserved_pie_chart.dart'; // 添加导入

// 将 TimeRange 枚举移动到类外部
enum TimeRange { threeMonths, sixMonths, oneYear, all }

class VisualizationSettingsPage extends StatefulWidget {
  @override
  State<VisualizationSettingsPage> createState() =>
      _VisualizationSettingsPageState();
}

class _VisualizationSettingsPageState extends State<VisualizationSettingsPage> {
  TimeRange _selectedTimeRange = TimeRange.all;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RideHistoryProvider>(context, listen: false)
          .loadRideHistory();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 添加选择的时间范围变量，默认值为全部
  // 根据选定的时间范围过滤乘
  List<RideInfo> _filterRides(List<RideInfo> rides) {
    final now = DateTime.now();
    late DateTime startDate;

    switch (_selectedTimeRange) {
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
        return rides; // 不过滤，返回全部数据
    }

    // 过滤掉不在选定时间范围内的乘车记录
    return rides.where((ride) {
      DateTime rideDate = DateTime.parse(ride.appointmentTime);
      return rideDate.isAfter(startDate) && rideDate.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rideHistoryProvider = Provider.of<RideHistoryProvider>(context);
    final rides = _filterRides(rideHistoryProvider.rides);

    return Scaffold(
      appBar: AppBar(
        title: Text('乘车历史'),
        actions: [
          PopupMenuButton<TimeRange>(
            icon: Icon(Icons.filter_list),
            onSelected: (TimeRange newValue) {
              setState(() {
                _selectedTimeRange = newValue;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<TimeRange>>[
              PopupMenuItem<TimeRange>(
                value: TimeRange.threeMonths,
                child: Text('过去3个月'),
              ),
              PopupMenuItem<TimeRange>(
                value: TimeRange.sixMonths,
                child: Text('过去半年'),
              ),
              PopupMenuItem<TimeRange>(
                value: TimeRange.oneYear,
                child: Text('过去一年'),
              ),
              PopupMenuItem<TimeRange>(
                value: TimeRange.all,
                child: Text('全部'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildPage('乘车日历', RideCalendarCard(rides: rides)),
                _buildPage('各时段出发班次统计', DepartureTimeBarChart(rides: rides)),
                _buildPage('签到时间差（分钟）分布', CheckInTimeHistogram(rides: rides)),
                _buildPage(
                    '已签到与已预约比例', CheckedInReservedPieChart(rides: rides)),
              ],
            ),
          ),
          _buildPageIndicator(),
          SizedBox(height: 20), // 添加这行来增加底部间距
        ],
      ),
    );
  }

  Widget _buildPage(String title, Widget content) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface), // 使用 onSurface 代替 onBackground
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: EdgeInsets.only(bottom: 16), // 修改这里，增加底部内边距
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(4, (index) {
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 12,
              height: 12,
              margin: EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          );
        }),
      ),
    );
  }
}
