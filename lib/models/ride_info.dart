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
      id: json['id'],
      statusName: json['status_name'],
      resourceName: json['resource_name'],
      appointmentTime: json['appointment_time']?.trim() ?? '',
      appointmentSignTime: json['appointment_sign_time']?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status_name': statusName,
      'resource_name': resourceName,
      'appointment_time': appointmentTime,
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
