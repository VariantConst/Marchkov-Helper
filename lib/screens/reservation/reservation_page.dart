import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import 'bus_route_card.dart';

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
  bool _showPastBuses = false; // 新增

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadReservationData();
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
      print('载已预约班车失败: $e');
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
        return busDate.year == _selectedDay?.year &&
            busDate.month == _selectedDay?.month &&
            busDate.day == _selectedDay?.day;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('班车时刻表'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildCalendar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _buildBusList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final lastSelectableDay = now.add(Duration(days: 5));

    return TableCalendar(
      firstDay: now,
      lastDay: now.add(Duration(days: 13)), // 显示两周
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
      calendarFormat: CalendarFormat.twoWeeks, // 固定为两周视图
      availableCalendarFormats: {CalendarFormat.twoWeeks: '两周'}, // 只允许两周视图
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
      children: [
        _buildBusSection('去昌平', _getBusesByDirection('去昌平'), Colors.grey[200]!),
        _buildBusSection('去燕园', _getBusesByDirection('去燕园'), Colors.grey[200]!),
      ],
    );
  }

  Widget _buildBusSection(String title, List<dynamic> buses, Color cardColor) {
    buses.sort((a, b) => a['yaxis'].compareTo(b['yaxis'])); // 按发车时间排序

    final pastBuses = buses.where((bus) => _isBusInPast(bus)).toList();
    final upcomingBuses = buses.where((bus) => !_isBusInPast(bus)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.directions_bus, size: 32),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ...upcomingBuses.map((busData) {
          bool isReserved = _isBusReserved(busData);
          bool isPast = false;

          // 如果是今天的班车，检查是否过期
          if (_isToday(busData['abscissa'])) {
            isPast = _isBusInPast(busData);
          }

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
            child: BusRouteCard(
              busData: busData,
              isReserved: isReserved,
              isPast: isPast,
              onTap: isPast ? null : () => _onBusCardTap(busData),
              onLongPress: () => _onBusCardLongPress(busData),
              cardColor: isReserved
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.grey[200]!,
            ),
          );
        }).toList(),
        if (pastBuses.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showPastBuses = !_showPastBuses;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showPastBuses ? '隐藏已过期班车' : '显示已过期班车',
                    style: TextStyle(color: Colors.blue),
                  ),
                  Icon(
                    _showPastBuses ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        if (_showPastBuses)
          ...pastBuses.map((busData) {
            bool isReserved = _isBusReserved(busData);
            bool isPast = true;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
              child: BusRouteCard(
                busData: busData,
                isReserved: isReserved,
                isPast: isPast,
                onTap: null,
                onLongPress: () => _onBusCardLongPress(busData),
                cardColor: Colors.grey[300]!,
              ),
            );
          }).toList(),
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

  bool _isToday(String dateStr) {
    DateTime busDate = DateTime.parse(dateStr);
    DateTime now = DateTime.now();
    return busDate.year == now.year &&
        busDate.month == now.month &&
        busDate.day == now.day;
  }

  bool _isBusInPast(Map<String, dynamic> busData) {
    String dateStr = busData['abscissa'];
    String timeStr = busData['yaxis'];
    DateTime busDateTime = DateTime.parse("$dateStr $timeStr");
    return busDateTime.isBefore(DateTime.now());
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

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '主页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt),
          label: '我的预约',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '设置',
        ),
      ],
      currentIndex: 1,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        // 处理导航逻辑
      },
    );
  }
}
