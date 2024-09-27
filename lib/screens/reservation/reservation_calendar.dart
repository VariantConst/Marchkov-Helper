import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
// 删除不必要的导入
// import 'package:flutter/services.dart';

class ReservationCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;

  const ReservationCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // 获取当前主题
    final now = DateTime.now();
    final lastSelectableDay = now.add(Duration(days: 13)); // 固定显示两周

    return TableCalendar(
      firstDay: now,
      lastDay: lastSelectableDay,
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: onDaySelected,
      calendarFormat: CalendarFormat.twoWeeks, // 强制使用两周格式
      availableCalendarFormats: const {
        CalendarFormat.twoWeeks: '两周',
      }, // 只允许两周格式
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.5), // 使用主题颜色
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary, // 使用主题颜色
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: theme.colorScheme.onPrimary, // 使用主题文本颜色
        ),
        selectedTextStyle: TextStyle(
          color: theme.colorScheme.onPrimary, // 使用主题文本颜色
        ),
        // 添加默认日期的装饰
        defaultDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
        ),
        // 设置默认日期文本样式
        defaultTextStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
        ),
        // 设置周末日期文本样式
        weekendTextStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
        ),
        // 设置不可选日期的样式
        disabledDecoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
        disabledTextStyle: TextStyle(
          color: theme.disabledColor,
        ),
      ),
      headerStyle: HeaderStyle(
        titleTextStyle: theme.textTheme.titleMedium!, // 使用主题文本样式并添加非空断言
        formatButtonVisible: false, // 隐藏格式切换按钮
        leftChevronVisible: false, // 隐藏左箭头
        rightChevronVisible: false, // 隐藏右箭头
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          bool isSelectable = day.isAfter(now.subtract(Duration(days: 1))) &&
              day.isBefore(lastSelectableDay.add(Duration(days: 1)));

          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelectable
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: isSelectable ? FontWeight.bold : FontWeight.normal,
                color: isSelectable
                    ? theme.textTheme.bodyMedium?.color
                    : theme.disabledColor, // 使用主题文本颜色
              ),
            ),
          );
        },
      ),
    );
  }
}
