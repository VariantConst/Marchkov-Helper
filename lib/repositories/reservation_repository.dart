import '../models/bus_route.dart';
import '../services/reservation_service.dart';
import '../providers/auth_provider.dart';

class ReservationRepository {
  final ReservationService _reservationService;

  ReservationRepository(AuthProvider authProvider)
      : _reservationService = ReservationService(authProvider);

  Future<List<BusRoute>> getBusRoutes(int hallId, String time) {
    return _reservationService.fetchBusRoutes(hallId, time);
  }

  Future<List<dynamic>> fetchMyReservations() {
    return _reservationService.fetchMyReservations();
  }

  Future<String> getReservationQRCode(
      String id, String hallAppointmentDataId) async {
    try {
      return await _reservationService.getReservationQRCode(
          id, hallAppointmentDataId);
    } catch (e) {
      print('获取二维码时出错: $e');
      rethrow;
    }
  }
}
