import 'package:flutter/material.dart';
import '../models/bus_route.dart';
import '../repositories/reservation_repository.dart';
import '../services/auth_service.dart';
import '../utils/date_formatter.dart';

class ReservationProvider with ChangeNotifier {
  final ReservationRepository _reservationRepository;
  List<BusRoute> _busRoutes = [];
  bool _isLoading = false;
  String? _error;

  ReservationProvider(AuthService authService)
      : _reservationRepository = ReservationRepository(authService);

  List<BusRoute> get busRoutes => _busRoutes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> login(String username, String password) async {
    try {
      await _reservationRepository.login(username, password);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadBusRoutes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final futures = List.generate(7, (index) {
        final date = now.add(Duration(days: index));
        return _reservationRepository.getBusRoutes(
            1, DateFormatter.format(date));
      });

      final results = await Future.wait(futures);
      _busRoutes = results.expand((element) => element).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
