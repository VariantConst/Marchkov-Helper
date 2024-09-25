import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';

class ReservationCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;

  const ReservationCalendar({
    Key? key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastSelectableDay = now.add(Duration(days: 5));

    return TableCalendar(
      firstDay: now,
      lastDay: now.add(Duration(days: 13)),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        // 添加震动反馈
        HapticFeedback.selectionClick();
        onDaySelected(selectedDay, focusedDay);
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
}
