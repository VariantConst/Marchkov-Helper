import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimeRange { threeMonths, sixMonths, oneYear, all }

class VisualizationSettingsProvider with ChangeNotifier {
  TimeRange _selectedTimeRange = TimeRange.all;
  static const String _timeRangeKey = 'selected_time_range';

  TimeRange get selectedTimeRange => _selectedTimeRange;

  VisualizationSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRange = prefs.getString(_timeRangeKey);
    if (savedRange != null) {
      _selectedTimeRange = TimeRange.values.firstWhere(
        (e) => e.toString() == savedRange,
        orElse: () => TimeRange.all,
      );
      notifyListeners();
    }
  }

  Future<void> setTimeRange(TimeRange range) async {
    if (_selectedTimeRange != range) {
      _selectedTimeRange = range;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_timeRangeKey, range.toString());
      notifyListeners();
    }
  }
}
