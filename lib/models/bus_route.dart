class BusRoute {
  final int id;
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
    return BusRoute(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
      jsonAddress: Address.fromJson(json['json_address']),
      capacity: json['capacity'],
      serveId: List<String>.from(json['serve_id']),
      createTime: json['create_time'],
      reservationTotal: json['reservation_total'],
      table: (json['table'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          List<TimeSlot>.from(value.map((x) => TimeSlot.fromJson(x))),
        ),
      ),
    );
  }
}

class Address {
  final String campusName;
  final String buildName;
  final String detailedAddress;

  Address({
    required this.campusName,
    required this.buildName,
    required this.detailedAddress,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      campusName: json['campus_name'],
      buildName: json['build_name'],
      detailedAddress: json['detailed_address'],
    );
  }
}

class TimeSlot {
  final int timeId;
  final int subId;
  final String abscissa;
  final String yaxis;
  final Row row;
  final int isSub;
  final int lockModel;
  final String localTime;
  final String date;

  TimeSlot({
    required this.timeId,
    required this.subId,
    required this.abscissa,
    required this.yaxis,
    required this.row,
    required this.isSub,
    required this.lockModel,
    required this.localTime,
    required this.date,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      timeId: json['time_id'],
      subId: json['sub_id'],
      abscissa: json['abscissa'],
      yaxis: json['yaxis'],
      row: Row.fromJson(json['row']),
      isSub: json['is_sub'],
      lockModel: json['lock_model'],
      localTime: json['local_time'],
      date: json['date'],
    );
  }
}

class Row {
  final int status;
  final int total;
  final int margin;
  final List<dynamic> info;
  final int price;
  final int isSub;
  final int closeTime;
  final List<dynamic> data;

  Row({
    required this.status,
    required this.total,
    required this.margin,
    required this.info,
    required this.price,
    required this.isSub,
    required this.closeTime,
    required this.data,
  });

  factory Row.fromJson(Map<String, dynamic> json) {
    return Row(
      status: json['status'],
      total: json['total'],
      margin: json['margin'],
      info: List<dynamic>.from(json['info']),
      price: json['price'],
      isSub: json['is_sub'],
      closeTime: json['close_time'],
      data: List<dynamic>.from(json['data']),
    );
  }
}
