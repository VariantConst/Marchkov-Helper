class RideInfo {
  final int id;
  final String statusName;
  final String resourceName;
  final String appointmentTime;
  final String? appointmentSignTime;

  RideInfo({
    required this.id,
    required this.statusName,
    required this.resourceName,
    required this.appointmentTime,
    this.appointmentSignTime,
  });

  factory RideInfo.fromJson(Map<String, dynamic> json) {
    return RideInfo(
      id: json['id'] as int,
      statusName: json['status_name'] as String,
      resourceName: json['resource_name'] as String,
      appointmentTime: (json['appointment_tim'] as String).trim(),
      appointmentSignTime: json['appointment_sign_time'] != null
          ? (json['appointment_sign_time'] as String).trim()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status_name': statusName,
      'resource_name': resourceName,
      'appointment_tim': appointmentTime,
      'appointment_sign_time': appointmentSignTime,
    };
  }
}

class CachedRideHistory {
  final DateTime lastFetchDate;
  final List<RideInfo> rides;

  CachedRideHistory({required this.lastFetchDate, required this.rides});

  factory CachedRideHistory.fromJson(Map<String, dynamic> json) {
    return CachedRideHistory(
      lastFetchDate: DateTime.parse(json['lastFetchDate']),
      rides: (json['rides'] as List)
          .map((rideJson) => RideInfo.fromJson(rideJson))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastFetchDate': lastFetchDate.toIso8601String(),
      'rides': rides.map((ride) => ride.toJson()).toList(),
    };
  }
}
