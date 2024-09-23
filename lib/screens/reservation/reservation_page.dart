import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import 'bus_route_card.dart';
import 'package:intl/intl.dart';

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  List<dynamic> _busList = []; // 原始班车列表
  List<dynamic> _filteredBusList = []; // 过滤后的班车列表
  bool _isLoading = true;
  String _errorMessage = '';
  late DateTime _selectedDate;
  late List<DateTime> _weekDates;
  late PageController _calendarController;
  late PageController _mainPageController;
  int _currentPage = 0; // 添加这行来定义 _currentPage
  Map<String, dynamic> _reservedBuses = {}; // 记录已预约的班车

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekDates = _getWeekDates();
    _calendarController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.2,
    );
    _mainPageController = PageController(initialPage: _currentPage);
    _loadReservationData(); // 只需调用一次
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _mainPageController.dispose();
    super.dispose();
  }

  List<DateTime> _getWeekDates() {
    DateTime now = DateTime.now();
    return List.generate(7, (index) => now.add(Duration(days: index)));
  }

  void _filterBusList() {
    setState(() {
      _filteredBusList = _busList.where((bus) {
        final busDate = DateTime.parse(bus['abscissa'].split(' ')[0]);
        return busDate.year == _selectedDate.year &&
            busDate.month == _selectedDate.month &&
            busDate.day == _selectedDate.day;
      }).toList();
    });
  }

  Future<void> _loadReservationData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString('cachedDate');
    final todayString = DateTime.now().toIso8601String().split('T')[0];

    if (cachedDate == todayString) {
      // 今天已有缓存，使用缓存的数据
      final cachedBusDataString = prefs.getString('cachedBusData');
      if (cachedBusDataString != null) {
        final cachedBusData = jsonDecode(cachedBusDataString);

        // 尝试从缓存中加载已预约班车列表
        final cachedReservedBusesString =
            prefs.getString('cachedReservedBuses');
        if (cachedReservedBusesString != null) {
          _reservedBuses =
              Map<String, dynamic>.from(jsonDecode(cachedReservedBusesString));
        }

        if (!mounted) return; // 检查组件是否仍然挂载
        setState(() {
          _busList = cachedBusData;
          _filterBusList();
          _isLoading = false;
        });
      }
    } else {
      // 没有今天的缓存，显示加载指示器
      if (!mounted) return; // 检查组件是否仍然挂载
      setState(() {
        _isLoading = true;
      });
    }

    // 提前获取 authProvider，避免在异步操作后使用 context
    // ignore: use_build_context_synchronously
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final today = DateTime.now();
      final dateStrings = [
        today.toIso8601String().split('T')[0],
        today.add(Duration(days: 6)).toIso8601String().split('T')[0],
      ];

      final allBuses = await reservationService.getAllBuses(dateStrings);

      if (!mounted) return; // 检查组件是否仍然挂载
      setState(() {
        _busList = allBuses;
        _filterBusList();
        _isLoading = false;
      });

      // 更新缓存
      await _cacheBusData();

      // 获取最新已预约班车列表并更新缓存
      await _fetchAndCacheMyReservations();
    } catch (e) {
      if (!mounted) return; // 检查组件是否仍然挂载
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cacheBusData() async {
    final prefs = await SharedPreferences.getInstance();
    final busDataString = jsonEncode(_busList);
    final todayString = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('cachedBusData', busDataString);
    await prefs.setString('cachedDate', todayString);
  }

  Future<void> _fetchAndCacheMyReservations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final reservations = await reservationService.fetchMyReservations();
      if (!mounted) return; // 检查组件是否仍然挂载
      setState(() {
        _reservedBuses.clear();
        for (var reservation in reservations) {
          String resourceId = reservation['resource_id'].toString();
          String appointmentTime = reservation['appointment_tim'].trim();
          String key = '$resourceId$appointmentTime';
          _reservedBuses[key] = {
            'id': reservation['id'],
            'hall_appointment_data_id': reservation['hall_appointment_data_id'],
          };
        }
      });
      // 更新缓存
      await _cacheReservedBuses();
    } catch (e) {
      print('加载已预约班车失败: $e');
    }
  }

  // 添加于缓存已预约班车列表的函数
  Future<void> _cacheReservedBuses() async {
    final prefs = await SharedPreferences.getInstance();
    final reservedBusesString = jsonEncode(_reservedBuses);
    await prefs.setString('cachedReservedBuses', reservedBusesString);
  }

  void _onBusCardTap(Map<String, dynamic> busData) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa']; // 日期
    String period = busData['time_id'].toString();
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';

    if (_reservedBuses.containsKey(key)) {
      // 已预约，执行取消预约
      try {
        String appointmentId = _reservedBuses[key]['id'].toString();
        String hallAppointmentDataId =
            _reservedBuses[key]['hall_appointment_data_id'].toString();
        await reservationService.cancelReservation(
            appointmentId, hallAppointmentDataId);

        if (!mounted) return; // 检查组件是否仍然挂载
        setState(() {
          // 移除高亮状态，删除相关属性
          _reservedBuses.remove(key);
        });

        // 更新缓存
        await _cacheReservedBuses();
      } catch (e) {
        _showErrorDialog('取消预约失败', e.toString());
      }
    } else {
      // 未预约，执行预约
      try {
        await reservationService.makeReservation(resourceId, date, period);
        await _fetchAndCacheMyReservations();
      } catch (e) {
        _showErrorDialog('预约失败', e.toString());
      }
    }
  }

  void _onBusCardLongPress(Map<String, dynamic> busData) {
    _showBusDetails(busData);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  // 添加一个数来断班车是否今天
  bool _isToday(String dateStr) {
    DateTime busDate = DateTime.parse(dateStr);
    DateTime now = DateTime.now();
    return busDate.year == now.year &&
        busDate.month == now.month &&
        busDate.day == now.day;
  }

  // 添加一个函数来判断班车是否已经过期
  bool _isBusInPast(Map<String, dynamic> busData) {
    String dateStr = busData['abscissa']; // 日期
    String timeStr = busData['yaxis']; // 时间
    DateTime busDateTime = DateTime.parse("$dateStr $timeStr");
    return busDateTime.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendar(), // 将日历移到外部
            Expanded(
              child: PageView.builder(
                controller: _mainPageController,
                onPageChanged: (int page) {
                  if (!mounted) return; // 检查组件是否仍然挂载
                  setState(() {
                    _currentPage = page;
                    _selectedDate = _weekDates[page];
                    _filterBusList();
                  });
                  _calendarController.animateToPage(
                    page,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                itemCount: _weekDates.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 已移除 _buildCalendar()
                        SizedBox(height: 20),
                        Expanded(
                          child: _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : _errorMessage.isNotEmpty
                                  ? Center(child: Text(_errorMessage))
                                  : _filteredBusList.isEmpty
                                      ? Center(child: Text('暂无班车信息'))
                                      : _buildBusList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return SizedBox(
      height: 100,
      child: PageView.builder(
        controller: _calendarController,
        onPageChanged: (int page) {
          _mainPageController.animateToPage(
            page,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        itemCount: _weekDates.length,
        itemBuilder: (context, index) {
          final date = _weekDates[index];
          final isSelected = index == _currentPage;
          final pageOffset = (index - _currentPage).abs();
          final scale = 1 - (pageOffset * 0.1).clamp(0.0, 0.3);
          final opacity = 1 - (pageOffset * 0.3).clamp(0.0, 0.7);

          return GestureDetector(
            onTap: () {
              _calendarController.animateToPage(
                index,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: isSelected ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusList() {
    // 按方向分类
    final toChangping = _filteredBusList.where((bus) {
      final name = bus['route_name'] ?? '';
      final indexYan = name.indexOf('燕');
      final indexXin = name.indexOf('新');
      return indexYan != -1 && indexXin != -1 && indexYan < indexXin;
    }).toList();

    final toYanyuan = _filteredBusList.where((bus) {
      final name = bus['route_name'] ?? '';
      final indexYan = name.indexOf('燕');
      final indexXin = name.indexOf('新');
      return indexYan != -1 && indexXin != -1 && indexXin < indexYan;
    }).toList();

    // 新增：按照发车时间段分类
    // 去昌平方向
    final morningBusesChangping = toChangping.where(_isMorningBus).toList();
    final noonBusesChangping = toChangping.where(_isNoonBus).toList();
    final eveningBusesChangping = toChangping.where(_isEveningBus).toList();

    // 去燕园方向
    final morningBusesYanyuan = toYanyuan.where(_isMorningBus).toList();
    final noonBusesYanyuan = toYanyuan.where(_isNoonBus).toList();
    final eveningBusesYanyuan = toYanyuan.where(_isEveningBus).toList();

    return RefreshIndicator(
      onRefresh: _onRefresh, // 添加刷新回调函数
      child: ListView(
        children: [
          // 去昌平方向
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '去昌平',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          // 早班车
          _buildBusSection(
            Icons.brightness_5, // 使用 brightness_5 图标
            morningBusesChangping,
            Colors.blue[100]!,
          ),
          // 午班车
          _buildBusSection(
            Icons.wb_sunny,
            noonBusesChangping,
            Colors.blue[100]!,
          ),
          // 晚班车
          _buildBusSection(
            Icons.nights_stay,
            eveningBusesChangping,
            Colors.blue[100]!,
          ),
          SizedBox(height: 20),
          // 去燕园方向
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '去燕园',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          // 早班车
          _buildBusSection(
            Icons.brightness_5, // 使用 brightness_5 图标
            morningBusesYanyuan,
            Colors.green[100]!,
          ),
          // 午班车
          _buildBusSection(
            Icons.wb_sunny,
            noonBusesYanyuan,
            Colors.green[100]!,
          ),
          // 晚班车
          _buildBusSection(
            Icons.nights_stay,
            eveningBusesYanyuan,
            Colors.green[100]!,
          ),
        ],
      ),
    );
  }

  // 新增：根据发车时间判断班车属于早、中、晚班车
  bool _isMorningBus(bus) {
    final timeStr = bus['yaxis'];
    final hour = int.parse(timeStr.split(':')[0]);
    return hour >= 5 && hour < 12;
  }

  bool _isNoonBus(bus) {
    final timeStr = bus['yaxis'];
    final hour = int.parse(timeStr.split(':')[0]);
    return hour >= 12 && hour < 17;
  }

  bool _isEveningBus(bus) {
    final timeStr = bus['yaxis'];
    final hour = int.parse(timeStr.split(':')[0]);
    return hour >= 17 && hour <= 23;
  }

  // 修改了方法名称，使其更符合语义
  Widget _buildBusSection(
      IconData iconData, List<dynamic> buses, Color cardColor) {
    buses.sort((a, b) => a['yaxis'].compareTo(b['yaxis'])); // 按发车时间排序

    final displayedBuses = buses.take(4).toList(); // 只取前4个班车

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // 修改为居中对齐
        children: [
          Icon(iconData, size: 32),
          SizedBox(width: 8),
          Expanded(
            child: Row(
              children: displayedBuses.map((busData) {
                bool isReserved = _isBusReserved(busData);
                bool isPast = false;

                // 如果是今天的班车，检查是否过期
                if (_isToday(busData['abscissa'])) {
                  isPast = _isBusInPast(busData);
                }

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: BusRouteCard(
                      busData: busData,
                      isReserved: isReserved,
                      isPast: isPast,
                      onTap: isPast ? null : () => _onBusCardTap(busData),
                      onLongPress: () => _onBusCardLongPress(busData),
                      cardColor: isReserved
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1)
                          : Colors.grey[200]!,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 添加一个刷新函数
  Future<void> _onRefresh() async {
    await _loadReservationData(); // 调用数据加载函数刷新数据
  }

  bool _isBusReserved(Map<String, dynamic> busData) {
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';
    return _reservedBuses.containsKey(key);
  }

  void _showBusDetails(Map<String, dynamic> busData) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: BusRouteDetails(busData: busData),
        );
      },
    );
  }
}
