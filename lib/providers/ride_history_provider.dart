import 'package:flutter/material.dart';
import '../models/ride_info.dart';
import '../services/ride_history_service.dart';
import '../providers/auth_provider.dart';

class RideHistoryProvider with ChangeNotifier {
  final RideHistoryService _rideHistoryService;

  List<RideInfo> _rides = [];
  bool _isLoading = false;
  String? _error;

  RideHistoryProvider(AuthProvider authProvider)
      : _rideHistoryService = RideHistoryService(authProvider);

  List<RideInfo> get rides => _rides;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRideHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rides = await _rideHistoryService.getRideHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
