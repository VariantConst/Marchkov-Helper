class Reservation {
  final int id;
  final int hallAppointmentDataId;
  final String appointmentTime;
  final String resourceName;

  Reservation({
    required this.id,
    required this.hallAppointmentDataId,
    required this.appointmentTime,
    required this.resourceName,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'],
      hallAppointmentDataId: json['hall_appointment_data_id'],
      appointmentTime: json['appointment_tim'].trim(),
      resourceName: json['resource_name'],
    );
  }
}
