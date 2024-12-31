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
    final lastSelectableDay = now.add(Duration(days: 6)); // 只显示7天（今天+6天）

    bool isDateSelectable(DateTime day) {
      return !day.isBefore(now.subtract(Duration(days: 1))) &&
          !day.isAfter(lastSelectableDay);
    }

    return TableCalendar(
      firstDay: now,
      lastDay: now.add(Duration(days: 13)), // 保持两周的显示
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        if (isDateSelectable(selectedDay)) {
          onDaySelected(selectedDay, focusedDay);
        } else if (selectedDay.isAfter(lastSelectableDay)) {
          // 显示短暂提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('前面的日期以后再来探索吧！'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      calendarFormat: CalendarFormat.twoWeeks, // 强制使用两周格式
      availableCalendarFormats: const {
        CalendarFormat.twoWeeks: '两周',
      }, // 只允许两周格式
      calendarStyle: CalendarStyle(
        cellMargin: EdgeInsets.zero, // 添加这行
        cellPadding: EdgeInsets.zero, // 添加这行
        todayDecoration: BoxDecoration(
          color: theme.colorScheme.primary
              .withAlpha((0.5 * 255).toInt()), // 使用主题颜色
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary, // 使用主题颜色
          shape: BoxShape.circle,
        ),
        // 添加尺寸约束，使默认圆圈与选中圆圈大小一致
        defaultDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: theme.colorScheme.primary.withAlpha((0.5 * 255).toInt())),
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
          return _buildDayContainer(
            context,
            day,
            isDateSelectable(day),
            decoration: isDateSelectable(day)
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary
                          .withAlpha((0.5 * 255).toInt()),
                      width: 1,
                    ),
                  )
                : null,
            textColor: isDateSelectable(day)
                ? theme.textTheme.bodyMedium?.color
                : theme.disabledColor,
          );
        },
        // 添加 todayBuilder，确保今天的日期样式一致
        todayBuilder: (context, day, focusedDay) {
          return _buildDayContainer(
            context,
            day,
            isDateSelectable(day),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha((0.5 * 255).toInt()),
              shape: BoxShape.circle,
            ),
            textColor: theme.colorScheme.onPrimary,
          );
        },
        // 添加 selectedBuilder，确保选中日期的样式一致
        selectedBuilder: (context, day, focusedDay) {
          return _buildDayContainer(
            context,
            day,
            isDateSelectable(day),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            textColor: theme.colorScheme.onPrimary,
          );
        },
        // 如果有需要，还可以添加 weekendBuilder 等其他构建器
      ),
    );
  }

  Widget _buildDayContainer(
    BuildContext context,
    DateTime day,
    bool isSelectable, {
    BoxDecoration? decoration,
    required Color? textColor,
  }) {
    return Center(
      child: Container(
        width: 32, // 设置一个较小的固定宽度
        height: 32, // 设置一个较小的固定高度
        decoration: decoration,
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontWeight: isSelectable ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
