import 'address.dart';
import 'time_slot.dart';

class BusRoute {
  final int id;
  final int lockModel;
  final String name;
  final String logo;
  final Address jsonAddress;
  final int capacity;
  final List<String> serveId;
  final String createTime;
  final int reservationTotal;
  final Map<String, List<TimeSlot>> table;

  BusRoute({
    required this.id,
    required this.lockModel,
    required this.name,
    required this.logo,
    required this.jsonAddress,
    required this.capacity,
    required this.serveId,
    required this.createTime,
    required this.reservationTotal,
    required this.table,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    // 处理可能的类型不匹配
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return BusRoute(
      id: parseInt(json['id']),
      lockModel: parseInt(json['lock_model']),
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
      jsonAddress: Address.fromJson(json['json_address'] ?? {}),
      capacity: parseInt(json['capacity']),
      serveId:
          List<String>.from(json['serve_id']?.map((x) => x.toString()) ?? []),
      createTime: json['create_time'] ?? '',
      reservationTotal: parseInt(json['reservation_total']),
      table: (json['table'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(
          key,
          List<TimeSlot>.from(
              (value as List<dynamic>).map((x) => TimeSlot.fromJson(x))),
        ),
      ),
    );
  }
}
