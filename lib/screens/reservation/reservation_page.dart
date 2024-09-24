import 'package:flutter/material.dart';
import 'package:marchkov_helper/screens/reservation/bus_route_card.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import '../../services/dau_service.dart'; // 新增
import '../../services/version_service.dart'; // 添加此行

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _busList = [];
  List<dynamic> _filteredBusList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _reservedBuses = {};
  late DauService _dauService; // 新增
  bool _showTip = true; // 新增状态变量

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadReservationData();
    _loadTipPreference(); // 新增方法调用

    // 初始化 DauService 并发送日活统计
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final versionService = VersionService();
    _dauService = DauService(authProvider, versionService);
    _dauService.sendDailyActive();
  }

  Future<void> _loadReservationData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString('cachedDate');
    final todayString = DateTime.now().toIso8601String().split('T')[0];

    if (cachedDate == todayString) {
      final cachedBusDataString = prefs.getString('cachedBusData');
      if (cachedBusDataString != null) {
        final cachedBusData = jsonDecode(cachedBusDataString);

        final cachedReservedBusesString =
            prefs.getString('cachedReservedBuses');
        if (cachedReservedBusesString != null) {
          _reservedBuses =
              Map<String, dynamic>.from(jsonDecode(cachedReservedBusesString));
        }

        if (!mounted) return;
        setState(() {
          _busList = cachedBusData;
          _filterBusList();
          _isLoading = false;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
    }

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

      if (!mounted) return;
      setState(() {
        _busList = allBuses;
        _filterBusList();
        _isLoading = false;
      });

      await _cacheBusData();

      await _fetchAndCacheMyReservations();
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
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
      await _cacheReservedBuses();
    } catch (e) {
      print('加载已预约班车失败: $e');
    }
  }

  Future<void> _cacheReservedBuses() async {
    final prefs = await SharedPreferences.getInstance();
    final reservedBusesString = jsonEncode(_reservedBuses);
    await prefs.setString('cachedReservedBuses', reservedBusesString);
  }

  void _filterBusList() {
    setState(() {
      _filteredBusList = _busList.where((bus) {
        final busDate = DateTime.parse(bus['abscissa'].split(' ')[0]);
        final busDateTime =
            DateTime.parse("${bus['abscissa']} ${bus['yaxis']}");
        return busDate.year == _selectedDay?.year &&
            busDate.month == _selectedDay?.month &&
            busDate.day == _selectedDay?.day &&
            busDateTime.isAfter(DateTime.now());
      }).toList();
    });
  }

  // 新增方法: 加载提示显示偏好
  Future<void> _loadTipPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showTip = prefs.getBool('showReservationTip') ?? true;
    });
  }

  // 新增方法: 保存提示显示偏好
  Future<void> _saveTipPreference(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showReservationTip', show);
  }

  // 新增方法: 显示提示对话框
  void _showTipDialog() {
    if (!_showTip) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('使用提示'),
        content: Text('点击按钮变蓝即成功预约,再点一次即可取消。长按可以查看对应班车详情。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showTip = false;
              });
              _saveTipPreference(false);
            },
            child: Text('不再显示'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            child: Card(
              margin: EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 2.0,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: _buildCalendar(),
              ),
            ),
          ),
          // 在日历下方添加提示按钮
          if (_showTip)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _showTipDialog,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '查看使用提示',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _buildBusList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final lastSelectableDay = now.add(Duration(days: 5));

    return TableCalendar(
      firstDay: now,
      lastDay: now.add(Duration(days: 13)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        if (selectedDay.isAfter(now.subtract(Duration(days: 1))) &&
            selectedDay.isBefore(lastSelectableDay.add(Duration(days: 1)))) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _filterBusList();
          });
        }
      },
      calendarFormat: CalendarFormat.twoWeeks,
      availableCalendarFormats: {CalendarFormat.twoWeeks: '两周'},
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).primaryColor, width: 1),
        ),
        todayTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: Colors.white),
        defaultTextStyle: TextStyle(fontWeight: FontWeight.bold),
        outsideTextStyle: TextStyle(color: Colors.grey),
        disabledTextStyle:
            TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      enabledDayPredicate: (day) {
        return day.isAfter(now.subtract(Duration(days: 1))) &&
            day.isBefore(lastSelectableDay.add(Duration(days: 1)));
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final isSelectable = day.isAfter(now.subtract(Duration(days: 1))) &&
              day.isBefore(lastSelectableDay.add(Duration(days: 1)));
          final isWithinNext7Days =
              day.isAfter(now.subtract(Duration(days: 1))) &&
                  day.isBefore(now.add(Duration(days: 7)));

          return Container(
            margin: const EdgeInsets.all(4.0),
            alignment: Alignment.center,
            decoration: isSelectable && isWithinNext7Days
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue, width: 1),
                  )
                : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: isSelectable && isWithinNext7Days
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: isSelectable ? Colors.black : Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBusList() {
    return ListView(
      padding: EdgeInsets.only(top: 8),
      children: [
        _buildBusSection('去燕园', _getBusesByDirection('去燕园'), Colors.grey[200]!),
        _buildBusSection('去昌平', _getBusesByDirection('去昌平'), Colors.grey[200]!),
      ],
    );
  }

  Widget _buildBusSection(String title, List<dynamic> buses, Color cardColor) {
    buses.sort((a, b) => a['yaxis'].compareTo(b['yaxis'])); // 按发车时间排序

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0), // 添加左右padding
          child: _buildBusButtons(buses),
        ),
      ],
    );
  }

  Widget _buildBusButtons(List<dynamic> buses) {
    List<Widget> morningButtons = [];
    List<Widget> afternoonButtons = [];
    List<Widget> eveningButtons = [];

    for (var busData in buses) {
      bool isReserved = _isBusReserved(busData);
      String time = busData['yaxis'] ?? '';
      DateTime busTime = DateTime.parse(busData['abscissa'] + ' ' + time);

      Widget button = Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4.0),
          child: ElevatedButton(
            onPressed: () => _onBusCardTap(busData),
            onLongPress: () => _showBusDetails(busData), // 添加长按事件处理
            style: ElevatedButton.styleFrom(
              backgroundColor: isReserved ? Colors.blueAccent : Colors.white,
              foregroundColor: isReserved ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isReserved ? Colors.blueAccent : Colors.grey,
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.2),
            ),
            child: Text(
              time,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );

      if (busTime.hour < 12) {
        morningButtons.add(button);
      } else if (busTime.hour < 18) {
        afternoonButtons.add(button);
      } else {
        eveningButtons.add(button);
      }
    }

    return Column(
      children: [
        if (morningButtons.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: morningButtons,
          ),
        if (afternoonButtons.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: afternoonButtons,
          ),
        if (eveningButtons.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: eveningButtons,
          ),
      ],
    );
  }

  List<dynamic> _getBusesByDirection(String direction) {
    return _filteredBusList.where((bus) {
      final name = bus['route_name'] ?? '';
      if (direction == '去昌平') {
        return name.contains('燕') &&
            name.contains('新') &&
            name.indexOf('燕') < name.indexOf('新');
      } else {
        return name.contains('燕') &&
            name.contains('新') &&
            name.indexOf('新') < name.indexOf('燕');
      }
    }).toList();
  }

  bool _isBusReserved(Map<String, dynamic> busData) {
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';
    return _reservedBuses.containsKey(key);
  }

  void _onBusCardTap(Map<String, dynamic> busData) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String period = busData['time_id'].toString();
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';

    if (_reservedBuses.containsKey(key)) {
      try {
        String appointmentId = _reservedBuses[key]['id'].toString();
        String hallAppointmentDataId =
            _reservedBuses[key]['hall_appointment_data_id'].toString();
        await reservationService.cancelReservation(
            appointmentId, hallAppointmentDataId);

        if (!mounted) return;
        setState(() {
          _reservedBuses.remove(key);
        });

        await _cacheReservedBuses();
      } catch (e) {
        _showErrorDialog('取消预约失败', e.toString());
      }
    } else {
      try {
        await reservationService.makeReservation(resourceId, date, period);
        await _fetchAndCacheMyReservations();
      } catch (e) {
        _showErrorDialog('预约失败', e.toString());
      }
    }
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

  void _showBusDetails(Map<String, dynamic> busData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: BusRouteDetails(busData: busData),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
