import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
// 移除未使用的导入
// import 'package:intl/intl.dart';
import '../../models/ride_info.dart';

class RideCalendarCard extends StatefulWidget {
  final List<RideInfo> rides;

  RideCalendarCard({required this.rides});

  @override
  RideCalendarCardState createState() => RideCalendarCardState();
}

class RideCalendarCardState extends State<RideCalendarCard> {
  late Map<DateTime, List<RideInfo>> _groupedRides;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  late DateTime _firstDay;
  late DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    _groupEvents(widget.rides);
    _selectedDay = _focusedDay;
    _firstDay = _getFirstDay();
    _lastDay = _getLastDay();
  }

  void _groupEvents(List<RideInfo> rides) {
    _groupedRides = {};
    for (var ride in rides) {
      DateTime rideDate = DateTime.parse(ride.appointmentTime.split(' ')[0]);
      if (_groupedRides[rideDate] == null) _groupedRides[rideDate] = [];
      _groupedRides[rideDate]!.add(ride);
    }
  }

  List<RideInfo> _getEventsForDay(DateTime date) {
    return _groupedRides[date] ?? [];
  }

  DateTime _getFirstDay() {
    if (widget.rides.isEmpty) {
      return DateTime.now().subtract(Duration(days: 30));
    } else {
      var dates = widget.rides.map((ride) {
        return DateTime.parse(ride.appointmentTime.split(' ')[0]);
      });
      return dates.reduce((a, b) => a.isBefore(b) ? a : b);
    }
  }

  DateTime _getLastDay() {
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar<RideInfo>(
          firstDay: _firstDay,
          lastDay: _lastDay,
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: _calendarFormat,
          availableCalendarFormats: const {
            CalendarFormat.month: 'Month',
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isNotEmpty) {
                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                    ),
                  ),
                );
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: _buildRideList(),
        ),
      ],
    );
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
