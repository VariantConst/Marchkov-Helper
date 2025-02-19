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
    final theme = Theme.of(context);
    final now = DateTime.now();
    final lastSelectableDay = now.add(Duration(days: 6));

    bool isDateSelectable(DateTime day) {
      return !day.isBefore(now.subtract(Duration(days: 1))) &&
          !day.isAfter(lastSelectableDay);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 自定义标题部分
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '选择日期',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '可预约未来7天',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        TableCalendar(
          firstDay: now,
          lastDay: now.add(Duration(days: 13)),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            if (isDateSelectable(selectedDay)) {
              onDaySelected(selectedDay, focusedDay);
            } else if (selectedDay.isAfter(lastSelectableDay)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onInverseSurface,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text('前面的日期以后再来探索吧！'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: theme.colorScheme.inverseSurface,
                  duration: Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: EdgeInsets.all(16),
                ),
              );
            }
          },
          headerVisible: false,
          daysOfWeekHeight: 32,
          rowHeight: 40,
          calendarFormat: CalendarFormat.twoWeeks,
          availableCalendarFormats: const {
            CalendarFormat.twoWeeks: '两周',
          },
          calendarStyle: CalendarStyle(
            cellMargin: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            cellPadding: EdgeInsets.zero,
            todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            defaultDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.surfaceContainerHighest,
                width: 1.5,
              ),
            ),
            defaultTextStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ) ??
                TextStyle(),
            weekendTextStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ) ??
                TextStyle(),
            disabledDecoration: BoxDecoration(
              shape: BoxShape.circle,
            ),
            disabledTextStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
              fontWeight: FontWeight.w400,
            ),
            todayTextStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ) ??
                TextStyle(),
            selectedTextStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ) ??
                TextStyle(),
            outsideTextStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
          headerStyle: HeaderStyle(
            titleTextStyle: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0.5,
            ),
            formatButtonVisible: false,
            leftChevronVisible: false,
            rightChevronVisible: false,
            titleCentered: true,
            headerPadding: EdgeInsets.symmetric(vertical: 12),
            headerMargin: EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.1),
            ),
            weekdayStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ) ??
                TextStyle(),
            weekendStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ) ??
                TextStyle(),
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
                          color: theme.colorScheme.surfaceContainerHighest,
                          width: 1.5,
                        ),
                      )
                    : null,
                textColor: isDateSelectable(day)
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.38),
              );
            },
            todayBuilder: (context, day, focusedDay) {
              return _buildDayContainer(
                context,
                day,
                isDateSelectable(day),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                textColor: theme.colorScheme.primary,
              );
            },
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
          ),
        ),
      ],
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
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: decoration,
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontWeight: isSelectable ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
