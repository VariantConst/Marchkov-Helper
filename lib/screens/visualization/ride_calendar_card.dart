import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
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

  @override
  void initState() {
    super.initState();
    _groupEvents(widget.rides);
    _selectedDay = _focusedDay; // 初始化 _selectedDay
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

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          TableCalendar<RideInfo>(
            firstDay: _getFirstDay(),
            lastDay: _getLastDay(),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarFormat: CalendarFormat.month,
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
                        color: Colors.blue,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8.0),
          // 使用 Expanded 包裹列表，确保其填充剩余空间
          Expanded(
            child: _buildRideList(),
          ),
        ],
      ),
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
