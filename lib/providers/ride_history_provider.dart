import 'package:flutter/material.dart';
import '../models/ride_info.dart';
import '../services/ride_history_service.dart';
import '../providers/auth_provider.dart';

class RideHistoryProvider with ChangeNotifier {
  final RideHistoryService _rideHistoryService;

  List<RideInfo> _rides = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  RideHistoryProvider(AuthProvider authProvider)
      : _rideHistoryService = RideHistoryService(authProvider);

  List<RideInfo> get rides => _rides;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  Future<void> loadRideHistory() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rides = await _rideHistoryService.getRideHistory();
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
