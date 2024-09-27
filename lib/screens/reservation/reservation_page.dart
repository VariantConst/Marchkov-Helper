import 'package:flutter/material.dart';
import 'package:marchkov_helper/screens/reservation/bus_route_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../services/reservation_service.dart';
import '../../services/dau_service.dart';
import '../../services/version_service.dart';
import 'dart:async';
import 'reservation_calendar.dart';
import 'bus_list.dart';
import 'tip_dialog.dart';
import 'package:flutter/services.dart';

class ReservationPage extends StatefulWidget {
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _busList = [];
  List<dynamic> _filteredBusList = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _reservedBuses = {};
  late DauService _dauService;
  bool? _showTip;
  Map<String, bool> _buttonCooldowns = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadReservationData();
    _loadTipPreference();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final versionService = VersionService();
    _dauService = DauService(authProvider, versionService);
    _dauService.sendDailyActive();
  }

  Future<void> _loadReservationData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString('cachedDate');
    final todayString = DateTime.now().toIso8601String().split('T')[0];

    if (cachedDate == todayString) {
      final cachedBusDataString = prefs.getString('cachedBusData');
      if (cachedBusDataString != null) {
        final cachedBusData = jsonDecode(cachedBusDataString);

        final cachedReservedBusesString =
            prefs.getString('cachedReservedBuses');
        if (cachedReservedBusesString != null) {
          _reservedBuses =
              Map<String, dynamic>.from(jsonDecode(cachedReservedBusesString));
        }

        if (!mounted) return;
        setState(() {
          _busList = cachedBusData;
          _filterBusList();
          _isLoading = false;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
    }

    // ignore: use_build_context_synchronously
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final today = DateTime.now();
      final dateStrings = [
        today.toIso8601String().split('T')[0],
        today.add(Duration(days: 6)).toIso8601String().split('T')[0],
      ];

      final allBuses = await reservationService.getAllBuses(dateStrings);
      final recentReservations =
          await reservationService.fetchRecentReservations();

      if (!mounted) return;
      setState(() {
        _busList = allBuses;
        _updateReservedBusesWithRecentReservations(recentReservations);
        _filterBusList();
        _isLoading = false;
      });

      await _cacheBusData();
      await _cacheReservedBuses();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cacheBusData() async {
    final prefs = await SharedPreferences.getInstance();
    final busDataString = jsonEncode(_busList);
    final todayString = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString('cachedBusData', busDataString);
    await prefs.setString('cachedDate', todayString);
  }

  Future<void> _cacheReservedBuses() async {
    final prefs = await SharedPreferences.getInstance();
    final reservedBusesString = jsonEncode(_reservedBuses);
    await prefs.setString('cachedReservedBuses', reservedBusesString);
  }

  void _filterBusList() {
    setState(() {
      _filteredBusList = _busList.where((bus) {
        final busDate = DateTime.parse(bus['abscissa'].split(' ')[0]);
        final busDateTime =
            DateTime.parse("${bus['abscissa']} ${bus['yaxis']}");
        return busDate.year == _selectedDay?.year &&
            busDate.month == _selectedDay?.month &&
            busDate.day == _selectedDay?.day &&
            busDateTime.isAfter(DateTime.now());
      }).toList();
    });
  }

  Future<void> _loadTipPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showTip = prefs.getBool('showReservationTip') ?? true;
    });
  }

  Future<void> _saveTipPreference(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showReservationTip', show);
  }

  void _showTipDialog() {
    if (!_showTip!) return;

    showDialog(
      context: context,
      builder: (context) => TipDialog(
        onDismiss: () => Navigator.of(context).pop(),
        onDoNotShowAgain: () {
          Navigator.of(context).pop();
          setState(() {
            _showTip = false;
          });
          _saveTipPreference(false);
        },
      ),
    );
  }

  void _updateReservedBusesWithRecentReservations(List<dynamic> reservations) {
    final now = DateTime.now();
    _reservedBuses.clear();
    for (var reservation in reservations) {
      if (reservation['status'] == 7) {
        String resourceId = reservation['resource_id'].toString();
        String appointmentTime = reservation['appointment_tim'].trim();
        DateTime reservationDateTime = DateTime.parse(appointmentTime);

        if (reservationDateTime.isAfter(now) ||
            (reservationDateTime.day == now.day &&
                reservationDateTime.isAfter(now))) {
          String key = '$resourceId$appointmentTime';
          _reservedBuses[key] = {
            'id': reservation['id'],
            'hall_appointment_data_id': reservation['periodList'][0]['id'],
          };
        }
      }
    }
  }

  void _onBusCardTap(Map<String, dynamic> busData) async {
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String period = busData['time_id'].toString();
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';

    // 设置按钮冷却
    setState(() {
      _buttonCooldowns[key] = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      if (_reservedBuses.containsKey(key)) {
        String appointmentId = _reservedBuses[key]['id'].toString();
        String hallAppointmentDataId =
            _reservedBuses[key]['hall_appointment_data_id'].toString();
        await reservationService.cancelReservation(
            appointmentId, hallAppointmentDataId);

        if (!mounted) return;
        setState(() {
          _reservedBuses.remove(key);
          _filterBusList();
        });

        await _cacheReservedBuses();
        HapticFeedback.lightImpact();
      } else {
        final reservationResult =
            await reservationService.makeReservation(resourceId, date, period);
        if (!mounted) return;
        setState(() {
          _reservedBuses[key] = {
            'id': reservationResult['id'],
            'hall_appointment_data_id':
                reservationResult['hall_appointment_data_id'],
          };
          _filterBusList();
        });
        await _cacheReservedBuses();
        await _refreshReservationStatus();
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      _showErrorDialog('操作失败', e.toString());
    } finally {
      // 3秒后解除冷却
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _buttonCooldowns[key] = false;
          });
        }
      });
    }
  }

  // 新增方法：刷新预约状态
  Future<void> _refreshReservationStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final recentReservations =
          await reservationService.fetchRecentReservations();
      if (!mounted) return;
      setState(() {
        _updateReservedBusesWithRecentReservations(recentReservations);
        _filterBusList();
      });
      await _cacheReservedBuses();
    } catch (e) {
      print('刷新预约状态失败: $e');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showBusDetails(Map<String, dynamic> busData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: BusRouteDetails(busData: busData),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _refreshBusData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    try {
      final today = DateTime.now();
      final dateStrings = [
        today.toIso8601String().split('T')[0],
        today.add(Duration(days: 6)).toIso8601String().split('T')[0],
      ];

      final allBuses = await reservationService.getAllBuses(dateStrings);
      final recentReservations =
          await reservationService.fetchRecentReservations();

      if (!mounted) return;
      setState(() {
        _busList = allBuses;
        _updateReservedBusesWithRecentReservations(recentReservations);
        _filterBusList();
      });

      await _cacheBusData();
      await _cacheReservedBuses();
    } catch (e) {
      print('刷新班车数据失败: $e');
      // 可以选择在这里显示一个短暂的错误提示
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            child: Card(
              margin: EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 2.0,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: ReservationCalendar(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    final now = DateTime.now();
                    final lastSelectableDay = now.add(Duration(days: 5));
                    if (selectedDay.isAfter(now.subtract(Duration(days: 1))) &&
                        selectedDay.isBefore(
                            lastSelectableDay.add(Duration(days: 1)))) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                        _filterBusList();
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          if (_showTip == null)
            SizedBox.shrink()
          else if (_showTip!)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _showTipDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '查看使用提示',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshBusData,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage))
                      : BusList(
                          filteredBusList: _filteredBusList,
                          onBusCardTap: _onBusCardTap,
                          showBusDetails: _showBusDetails,
                          reservedBuses: _reservedBuses,
                          buttonCooldowns: _buttonCooldowns,
                        ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
