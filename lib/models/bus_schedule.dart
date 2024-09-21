import 'bus_route.dart';

class BusSchedule {
  final BusRoute busRoute;
  final String date;
  final String time;
  final int margin;
  final int total;

  BusSchedule({
    required this.busRoute,
    required this.date,
    required this.time,
    required this.margin,
    required this.total,
  });
}
