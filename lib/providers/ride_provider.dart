import 'package:flutter/material.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import '../providers/reservation_provider.dart';

class RideProvider with ChangeNotifier {
  String? _qrCode;
  bool _isLoading = true;
  String _errorMessage = '';
  String _departureTime = '';
  String _routeName = '';
  String _codeType = '';

  // 添加 getter 方法
  String? get qrCode => _qrCode;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get departureTime => _departureTime;
  String get routeName => _routeName;
  String get codeType => _codeType;
  bool get isGoingToYanyuan => _isGoingToYanyuan;

  late bool _isGoingToYanyuan;

  final ReservationProvider _reservationProvider;
  final ReservationService _reservationService;

  RideProvider(this._reservationProvider, this._reservationService) {
    _setDirectionBasedOnTime(DateTime.now()); // 同步初始化
    _initialize();
  }

  Future<void> _initialize() async {
    bool locationAvailable = await _determinePosition();
    if (locationAvailable) {
      await _setDirectionBasedOnLocation();
    } else {
      _setDirectionBasedOnTime(DateTime.now());
    }
    _loadRideData();
  }

  Future<bool> _determinePosition() async {
    // ... 原有代码 ...
    return false; // 或根据逻辑返回 true 或 false
  }

  Future<void> _setDirectionBasedOnLocation() async {
    // ... 原有代码 ...
  }

  void _setDirectionBasedOnTime(DateTime now) {
    _isGoingToYanyuan = now.hour < 12; // 根据当前时间设置默认方向
    notifyListeners();
  }

  void toggleDirection() {
    _isGoingToYanyuan = !_isGoingToYanyuan;
    _errorMessage = ''; // 清空错误信息
    notifyListeners();
    _loadRideData();
  }

  Future<void> _loadRideData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _reservationProvider.loadCurrentReservations();
      final validReservations = _reservationProvider.currentReservations
          .where(_isWithinTimeRange)
          .where(
              (reservation) => _isInSelectedDirection(reservation.resourceName))
          .toList();

      if (validReservations.isNotEmpty) {
        if (validReservations.length == 1) {
          await _fetchQRCode(validReservations[0]);
        } else {
          final selectedReservation = _selectReservation(validReservations);
          await _fetchQRCode(selectedReservation);
        }
      } else {
        // 获取临时码
        final tempCode = await _fetchTempCode(_reservationService);
        if (tempCode != null) {
          _qrCode = tempCode['code'];
          _departureTime = tempCode['departureTime']!;
          _routeName = tempCode['routeName']!;
          _codeType = '临时码';
          _isLoading = false;
        } else {
          _errorMessage = '这会没有班车可坐😅';
          _isLoading = false;
        }
      }
    } catch (e) {
      _errorMessage = '加载数据时出错: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> _fetchQRCode(Reservation reservation) async {
    try {
      await _reservationProvider.fetchQRCode(
        reservation.id.toString(),
        reservation.hallAppointmentDataId.toString(),
      );
      _qrCode = _reservationProvider.qrCode;
      _departureTime = reservation.appointmentTime;
      _routeName = reservation.resourceName;
      _codeType = '乘车码';
      _isLoading = false;
    } catch (e) {
      _errorMessage = '获取二维码时出错: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<Map<String, String>?> _fetchTempCode(
      ReservationService service) async {
    // ... 原有代码 ...
    return null; // 或返回实际的 Map<String, String>
  }

  Reservation _selectReservation(List<Reservation> reservations) {
    // ... 原有代码 ...
    return reservations.first; // 确保返回一个 Reservation 对象
  }

  bool _isWithinTimeRange(Reservation reservation) {
    // ... 原有代码 ...
    return true; // 或根据实际条件返回 true 或 false
  }

  bool _isInSelectedDirection(String routeName) {
    // ... 原有代码 ...
    return true; // 或根据实际条件返回 true 或 false
  }

  // 添加一个 public 方法 loadRideData()
  void loadRideData() {
    _loadRideData();
  }
}
