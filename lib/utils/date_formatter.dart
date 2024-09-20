// lib/utils/date_formatter.dart
class DateFormatter {
  static String format(DateTime date) {
    // 实现日期格式化逻辑
    return "${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}";
  }
}
