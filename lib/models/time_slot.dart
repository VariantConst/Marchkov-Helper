class TimeSlot {
  final int timeId;
  final int subId;
  final String abscissa;
  final String yaxis;
  final RowData row;
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
      abscissa: json['abscissa'] ?? '',
      yaxis: json['yaxis'] ?? '',
      row: RowData.fromJson(json['row']),
      isSub: json['is_sub'],
      lockModel: json['lock_model'],
      localTime: json['local_time'] ?? '',
      date: json['date'] ?? '',
    );
  }
}

class RowData {
  final int status;
  final int total;
  final int margin;
  final List<dynamic> info;
  final int price;
  final int isSub;
  final int closeTime;
  final List<dynamic> data;

  RowData({
    required this.status,
    required this.total,
    required this.margin,
    required this.info,
    required this.price,
    required this.isSub,
    required this.closeTime,
    required this.data,
  });

  factory RowData.fromJson(Map<String, dynamic> json) {
    return RowData(
      status: json['status'],
      total: json['total'],
      margin: json['margin'],
      info: json['info'] ?? [],
      price: json['price'],
      isSub: json['is_sub'],
      closeTime: json['close_time'],
      data: json['data'] ?? [],
    );
  }
}
