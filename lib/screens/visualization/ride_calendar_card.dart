import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // 添加此行
import '../../models/ride_info.dart';

class RideCalendarCard extends StatefulWidget {
  final List<RideInfo> rides;

  RideCalendarCard({required this.rides});

  @override
  RideCalendarCardState createState() => RideCalendarCardState();
}

class RideCalendarCardState extends State<RideCalendarCard> {
  late Map<String, List<RideInfo>> _groupedRides;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _groupEvents(widget.rides);
    _selectedDay = _focusedDay; // 初始化 _selectedDay
  }

  void _groupEvents(List<RideInfo> rides) {
    _groupedRides = {};
    for (var ride in rides) {
      String rideDateKey =
          ride.appointmentTime.split(' ')[0]; // 提取 'yyyy-MM-dd'
      if (_groupedRides[rideDateKey] == null) _groupedRides[rideDateKey] = [];
      _groupedRides[rideDateKey]!.add(ride);
    }
  }

  List<RideInfo> _getEventsForDay(DateTime date) {
    String key = DateFormat('yyyy-MM-dd').format(date); // 转换为 'yyyy-MM-dd' 格式
    return _groupedRides[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar<RideInfo>(
          firstDay: _getFirstDay(),
          lastDay: _getLastDay(),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: _calendarFormat,
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: _buildRideList(),
        ),
      ],
    );
  }

  DateTime _getFirstDay() {
    if (widget.rides.isEmpty) {
      return DateTime.now().subtract(Duration(days: 30));
    } else {
      return widget.rides.map((ride) {
        return DateTime.parse(ride.appointmentTime.split(' ')[0]);
      }).reduce((a, b) => a.isBefore(b) ? a : b);
    }
  }

  DateTime _getLastDay() {
    return DateTime.now();
  }

  Widget _buildRideList() {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
    if (selectedEvents.isEmpty) {
      return Center(
        child: Text('这一天没有乘车记录'),
      );
    } else {
      return ListView.builder(
        itemCount: selectedEvents.length,
        itemBuilder: (context, index) {
          RideInfo ride = selectedEvents[index];
          return ListTile(
            title: Text('乘车时间: ${ride.appointmentTime}'),
            subtitle: Text('状态: ${ride.statusName}'),
          );
        },
      );
    }
  }
}
