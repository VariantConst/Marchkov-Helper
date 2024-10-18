import 'package:flutter/foundation.dart';
import '../models/bus_route.dart';
import '../repositories/reservation_repository.dart';
import '../providers/auth_provider.dart';
import '../utils/date_formatter.dart';
import '../models/reservation.dart';

class ReservationProvider with ChangeNotifier {
  final ReservationRepository _reservationRepository;
  // ignore: unused_field
  final AuthProvider _authProvider;
  List<BusRoute> _busRoutes = [];
  bool _isLoading = false;
  String? _error;
  bool _isLoadingReservations = false;
  bool _isLoadingQRCode = false;

  List<Reservation> _currentReservations = [];
  String? _qrCode; // 保存二维码

  ReservationProvider(this._authProvider)
      : _reservationRepository = ReservationRepository(_authProvider);

  List<BusRoute> get busRoutes => _busRoutes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoadingReservations => _isLoadingReservations;
  bool get isLoadingQRCode => _isLoadingQRCode;

  List<Reservation> get currentReservations => _currentReservations;
  String? get qrCode => _qrCode;

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
      final reservations = await _reservationRepository.fetchMyReservations();
      _currentReservations =
          reservations.map((r) => Reservation.fromJson(r)).toList();
      _isLoadingReservations = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoadingReservations = false;
      notifyListeners();
    }
  }

  // 获取二维码
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
      print('获取二维码时出错: $e');
      _error = e.toString();
      _isLoadingQRCode = false;
      notifyListeners();
    }
  }
}
