import '../models/bus_route.dart';
import '../services/reservation_service.dart';
import '../services/auth_service.dart';

class ReservationRepository {
  final ReservationService _reservationService;

  ReservationRepository(AuthService authService)
      : _reservationService = ReservationService(authService);

  Future<void> login(String username, String password) {
    return _reservationService.login(username, password);
  }

  Future<List<BusRoute>> getBusRoutes(int hallId, String time) {
    return _reservationService.fetchBusRoutes(hallId, time);
  }
}
