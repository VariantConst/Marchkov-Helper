import 'package:flutter/material.dart';
import '../models/bus_route.dart';
import '../repositories/reservation_repository.dart';
import '../providers/auth_provider.dart';
import '../utils/date_formatter.dart';
import '../models/reservation.dart';

class ReservationProvider with ChangeNotifier {
  final ReservationRepository _reservationRepository;
  List<BusRoute> _busRoutes = [];
  bool _isLoading = false;
  String? _error;

  List<Reservation> _currentReservations = [];
  String? _qrCode; // 保存二维码

  bool _isLoadingReservations = false;
  bool _isLoadingQRCode = false;

  ReservationProvider(AuthProvider authProvider)
      : _reservationRepository = ReservationRepository(authProvider);

  List<BusRoute> get busRoutes => _busRoutes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Reservation> get currentReservations => _currentReservations;
  String? get qrCode => _qrCode;
  bool get isLoadingReservations => _isLoadingReservations;
  bool get isLoadingQRCode => _isLoadingQRCode;

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
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // 获取当前预约列表
  Future<void> loadCurrentReservations() async {
    _isLoadingReservations = true;
    _error = null;
    notifyListeners();

    try {
      final reservationsData =
          await _reservationRepository.fetchMyReservations();
      _currentReservations =
          reservationsData.map((data) => Reservation.fromJson(data)).toList();
      _isLoadingReservations = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoadingReservations = false;
      notifyListeners();
    }
  }

  // 获取二维��
  Future<void> fetchQRCode(String id, String hallAppointmentDataId) async {
    _isLoadingQRCode = true;
    _error = null;
    notifyListeners();

    try {
      _qrCode = await _reservationRepository.getReservationQRCode(
          id, hallAppointmentDataId);
      _isLoadingQRCode = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoadingQRCode = false;
      notifyListeners();
    }
  }
}
