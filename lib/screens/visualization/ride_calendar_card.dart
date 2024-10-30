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

  @override
  void didUpdateWidget(RideCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rides != oldWidget.rides) {
      _groupEvents(widget.rides);
      setState(() {});
    }
  }

  void _groupEvents(List<RideInfo> rides) {
    _groupedRides = {};
    for (var ride in rides) {
      DateTime rideDate = DateTime.parse(ride.appointmentTime.split(' ')[0]);
      // 将时间部分设置为零点
      rideDate = DateTime(rideDate.year, rideDate.month, rideDate.day);
      if (_groupedRides[rideDate] == null) _groupedRides[rideDate] = [];
      _groupedRides[rideDate]!.add(ride);
    }
  }

  List<RideInfo> _getEventsForDay(DateTime date) {
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    return _groupedRides[normalizedDate] ?? [];
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
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: TableCalendar<RideInfo>(
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
            headerStyle: HeaderStyle(
              titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              formatButtonVisible: false,
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: theme.colorScheme.primary,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.primary,
              ),
              titleCentered: true,
              headerPadding: EdgeInsets.symmetric(horizontal: 16.0),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              weekendStyle: TextStyle(
                color: theme.colorScheme.primary.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: TextStyle(color: textColor),
              weekendTextStyle: TextStyle(color: theme.colorScheme.primary),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
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
              defaultBuilder: (context, date, _) {
                if (_getEventsForDay(date).isNotEmpty) {
                  return Container(
                    margin: const EdgeInsets.all(6.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(color: textColor),
                    ),
                  );
                }
                return null;
              },
              selectedBuilder: (context, date, _) {
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              todayBuilder: (context, date, _) {
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              markerBuilder: (context, date, events) => SizedBox.shrink(),
            ),
          ),
        ),
        Divider(height: 1),
        Expanded(
          child: _buildRideList(),
        ),
      ],
    );
  }

  Widget _buildRideList() {
    final theme = Theme.of(context);
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

    if (selectedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            SizedBox(height: 16),
            Text(
              '这一天没有乘车记录',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 8,
      ),
      itemCount: selectedEvents.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        RideInfo ride = selectedEvents[index];
        String status = ride.statusName;
        bool isViolation = status == '已预约';
        String statusText = isViolation ? '已违约' : '已签到';

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：时间和状态
                Row(
                  children: [
                    Text(
                      ride.appointmentTime,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isViolation
                            ? theme.colorScheme.errorContainer
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isViolation
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                // 第二行：路线名
                SizedBox(height: 4),
                Text(
                  ride.resourceName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
