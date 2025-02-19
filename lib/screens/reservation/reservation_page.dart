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
  Map<String, dynamic> _reservedBuses = {};
  late DauService _dauService;
  bool? _showTip;
  Map<String, String> _buttonCooldowns = {};
  bool _isBackgroundRefreshing = false;
  bool _showRetryButton = false;
  bool _isRetrying = false;
  DateTime? _lastRetryTime;
  String _loadingStep = '正在初始化...';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadReservationData();
    _startSlowLoadingTimer();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final versionService = VersionService();
    _dauService = DauService(authProvider, versionService);
    _dauService.sendDailyActive();
  }

  void _startSlowLoadingTimer() {
    Future.delayed(Duration(seconds: 2), () {
      if (mounted && _isLoading) {
        setState(() {
          _showRetryButton = true;
          _loadingStep = '加载缓慢，可能是校园网连接较弱';
        });
      }
    });
  }

  Future<void> _loadReservationData() async {
    if (mounted) {
      setState(() {
        _loadingStep = '正在检查缓存数据...';
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString('cachedDate');
    final todayString = DateTime.now().toIso8601String().split('T')[0];

    if (cachedDate == todayString) {
      if (mounted) {
        setState(() {
          _loadingStep = '正在加载缓存数据...';
        });
      }
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
          _isBackgroundRefreshing = true;
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
        _isBackgroundRefreshing = false;
        _loadingStep = '加载完成';
      });

      await _cacheBusData();
      await _cacheReservedBuses();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStep = '加载失败: ${e.toString()}';
        _isLoading = true;
        _showRetryButton = true;
        _isBackgroundRefreshing = false;
      });
    }
  }

  Future<void> _cacheBusData() async {
    final prefs = await SharedPreferences.getInstance();
    final busDataString = jsonEncode(_busList);
    final todayString = DateTime.now().toIso8601String().split('T')[0];
    print('busDataString, $busDataString');
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

  Future<void> _onBusCardTap(Map<String, dynamic> busData) async {
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String period = busData['time_id'].toString();
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';

    // 设置按钮却，并指定操作类型
    setState(() {
      _buttonCooldowns[key] =
          _reservedBuses.containsKey(key) ? 'cancelling' : 'reserving';
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
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _buttonCooldowns.remove(key);
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: BusRouteDetails(busData: busData),
      ),
    );
  }

  Future<void> _refreshBusData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reservationService = ReservationService(authProvider);

    // 设置加载状态
    setState(() {
      _isBackgroundRefreshing = true;
    });

    // 创建一个计时器，8秒后检查是否仍在加载
    Timer? timeoutTimer;
    timeoutTimer = Timer(Duration(seconds: 8), () {
      if (mounted && _isBackgroundRefreshing) {
        setState(() {
          _isBackgroundRefreshing = false;
          _showRetryButton = true;
          _loadingStep = '加载缓慢，可能是校园网连接较弱';
        });

        // 显示一个 SnackBar 提示用户
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载缓慢，可能是校园网连接较弱'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _retryWithLogin,
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });

    try {
      final today = DateTime.now();
      final dateStrings = [
        today.toIso8601String().split('T')[0],
        today.add(Duration(days: 6)).toIso8601String().split('T')[0],
      ];

      final allBuses = await reservationService.getAllBuses(dateStrings);
      final recentReservations =
          await reservationService.fetchRecentReservations();

      // 取消计时器
      timeoutTimer.cancel();

      if (!mounted) return;
      setState(() {
        _busList = allBuses;
        _updateReservedBusesWithRecentReservations(recentReservations);
        _filterBusList();
        _isBackgroundRefreshing = false;
        _showRetryButton = false;
      });

      await _cacheBusData();
      await _cacheReservedBuses();
    } catch (e) {
      // 取消计时器
      timeoutTimer.cancel();

      if (!mounted) return;
      setState(() {
        _isBackgroundRefreshing = false;
        _showRetryButton = true;
      });

      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载失败: ${e.toString()}'),
          action: SnackBarAction(
            label: '重试',
            onPressed: _retryWithLogin,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _retryWithLogin() async {
    final now = DateTime.now();
    if (_lastRetryTime != null &&
        now.difference(_lastRetryTime!) < Duration(seconds: 3)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请稍后再试'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _lastRetryTime = now;

    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
      _loadingStep = '正在刷新登录状态...';
    });

    try {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.silentlyRefreshCookie();

      if (!success) {
        throw Exception('刷新登录状态失败，请重新登录');
      }

      setState(() {
        _isLoading = true;
        _showRetryButton = false;
        _loadingStep = '正在重新加载数据...';
      });

      await _loadReservationData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStep = '重试失败: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重试失败: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: BorderSide(
                    color: theme.colorScheme.outline
                        .withAlpha((0.2 * 255).toInt()),
                  ),
                ),
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ReservationCalendar(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: (selectedDay, focusedDay) {
                      final now = DateTime.now();
                      final lastSelectableDay = now.add(Duration(days: 5));
                      if (selectedDay
                              .isAfter(now.subtract(Duration(days: 1))) &&
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
          ),
          if (_showTip != null && _showTip!)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '长按班车可查看详细信息',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshBusData,
              color: theme.colorScheme.primary,
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isRetrying)
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            _loadingStep,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_showRetryButton && !_isRetrying) ...[
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _retryWithLogin,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(120, 36),
                              ),
                              child: Text('重试'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : BusList(
                      filteredBusList: _filteredBusList,
                      onBusCardTap: _onBusCardTap,
                      showBusDetails: _showBusDetails,
                      reservedBuses: _reservedBuses,
                      buttonCooldowns: _buttonCooldowns,
                      isRefreshing: _isBackgroundRefreshing,
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
