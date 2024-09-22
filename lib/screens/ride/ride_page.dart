import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import 'package:geolocator/geolocator.dart'; // 添加此行
import 'package:shared_preferences/shared_preferences.dart'; // 添加此行
import 'dart:convert'; // 添加此行
import 'package:qr_flutter/qr_flutter.dart'; // 添加此行

class RidePage extends StatefulWidget {
  const RidePage({super.key});

  @override
  RidePageState createState() => RidePageState();
}

class RidePageState extends State<RidePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _qrCode;
  bool _isInitialLoading = true; // 初次加载的加载状态
  bool _isRefreshing = false; // 下拉刷新状态
  bool _isToggleLoading = false; // 切换方向的加载状态
  String _errorMessage = '';
  String _departureTime = '';
  String _routeName = '';
  String _codeType = '';

  bool _isGoingToYanyuan = true; // 给定初始值

  @override
  void initState() {
    super.initState();
    // 仅在初始时设定向，不在刷新时改变方向
    _setDirectionBasedOnTime(DateTime.now());
    _initialize(); // 异步初始化
  }

  Future<void> _initialize() async {
    bool locationAvailable = await _determinePosition();
    if (locationAvailable) {
      await _setDirectionBasedOnLocation();
    }
    await _loadRideData(isInitialLoad: true); // 传入参数，表示初次加载
  }

  Future<bool> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 检查位置服务是否启用
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 位置服务未启用
      return false;
    }

    // 检查应用是否有权限访问位置
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 用户拒绝了位置权限
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 无法获取位置权限
      return false;
    }

    return true;
  }

  Future<void> _setDirectionBasedOnLocation() async {
    Position position = await Geolocator.getCurrentPosition();

    // 定义燕园和新校区的坐标
    const yanyuanLatitude = 39.989905;
    const yanyuanLongitude = 116.311271;
    const xinxiaoqLatitude = 40.177702;
    const xinxiaoqLongitude = 116.164600;

    bool isGoingToYanyuan;
    double distanceToYanyuan = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      yanyuanLatitude,
      yanyuanLongitude,
    );

    double distanceToXinxiaoq = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      xinxiaoqLatitude,
      xinxiaoqLongitude,
    );

    if (distanceToYanyuan < distanceToXinxiaoq) {
      // 用户在燕园，去新校区
      isGoingToYanyuan = false;
    } else {
      // 用户在新校区，去燕园
      isGoingToYanyuan = true;
    }

    // 在 setState 中更新变量
    setState(() {
      _isGoingToYanyuan = isGoingToYanyuan;
    });
  }

  void _setDirectionBasedOnTime(DateTime now) {
    _isGoingToYanyuan = now.hour < 12;
  }

  Future<void> _loadRideData({bool isInitialLoad = false}) async {
    if (isInitialLoad) {
      setState(() {
        _isInitialLoading = true; // 初次加载时设置为 true
        _errorMessage = ''; // 清空错误信息
      });
    } else if (_isRefreshing) {
      // 在下拉刷新时，不改变任何加载状态
    } else if (_isToggleLoading) {
      // 在切换方向，不改变任何加载状态
    }

    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);
    final reservationService =
        ReservationService(Provider.of(context, listen: false));

    try {
      await reservationProvider.loadCurrentReservations();
      final validReservations = reservationProvider.currentReservations
          .where(_isWithinTimeRange)
          .where(
              (reservation) => _isInSelectedDirection(reservation.resourceName))
          .toList();

      if (validReservations.isNotEmpty) {
        if (validReservations.length == 1) {
          await _fetchQRCode(reservationProvider, validReservations[0]);
        } else {
          final selectedReservation = _selectReservation(validReservations);
          await _fetchQRCode(reservationProvider, selectedReservation);
        }
      } else {
        // 获取临时码
        final tempCode = await _fetchTempCode(reservationService);
        if (tempCode != null) {
          setState(() {
            _qrCode = tempCode['code'];
            _departureTime = tempCode['departureTime']!;
            _routeName = tempCode['routeName']!;
            _codeType = '临时码';
          });
        } else {
          setState(() {
            _errorMessage = '这会去${_isGoingToYanyuan ? '燕园' : '昌平'}没有班车可坐😅';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载数据时出错: $e';
      });
    } finally {
      // 确保在所有情况下都重置加载状态
      if (isInitialLoad) {
        setState(() {
          _isInitialLoading = false;
        });
      } else if (_isRefreshing) {
        setState(() {
          _isRefreshing = false;
        });
      } else if (_isToggleLoading) {
        setState(() {
          _isToggleLoading = false;
        });
      }
    }
  }

  Future<void> _fetchQRCode(
      ReservationProvider provider, Reservation reservation) async {
    try {
      await provider.fetchQRCode(
        reservation.id.toString(),
        reservation.hallAppointmentDataId.toString(),
      );

      // 获取实际发车时间
      final actualDepartureTime = await _getActualDepartureTime(reservation);

      setState(() {
        _qrCode = provider.qrCode;
        _departureTime = actualDepartureTime; // 使用实际发车时间
        _routeName = reservation.resourceName;
        _codeType = '乘车码';
      });
    } catch (e) {
      setState(() {
        _errorMessage = '获取二维码时出错: $e';
      });
    }
  }

  // 新增方法：获取实际发车时间
  Future<String> _getActualDepartureTime(Reservation reservation) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedBusDataString = prefs.getString('cachedBusData');
    if (cachedBusDataString != null) {
      final buses = jsonDecode(cachedBusDataString);
      final matchingBus = buses.firstWhere(
        (bus) =>
            bus['route_name'] == reservation.resourceName &&
            '${bus['abscissa']} ${bus['yaxis']}' == reservation.appointmentTime,
        orElse: () => null,
      );
      if (matchingBus != null) {
        return matchingBus['yaxis'];
      }
    }
    // 如果没有找到匹配的 bus 数据，返回原始的 appointmentTime
    return reservation.appointmentTime.split(' ')[1];
  }

  Future<Map<String, String>?> _fetchTempCode(
      ReservationService service) async {
    // 新增代码：获取当前日期字符串
    final now = DateTime.now();
    final todayString = now.toIso8601String().split('T')[0];

    List<dynamic> buses;

    // 尝试从缓存中加载 busData
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString('cachedDate');

    if (cachedDate == todayString) {
      // 如果缓存的日期是今天，使用缓存的 busData
      final cachedBusDataString = prefs.getString('cachedBusData');
      if (cachedBusDataString != null) {
        buses = jsonDecode(cachedBusDataString);
      } else {
        // 如果缓存为空，调用接口获取 busData
        buses = await service.getAllBuses([todayString]);
      }
    } else {
      // 如果缓存的日期不是今天，调用接口获取 busData
      buses = await service.getAllBuses([todayString]);
      // 更新缓存
      await prefs.setString('cachedBusData', jsonEncode(buses));
      await prefs.setString('cachedDate', todayString);
    }

    final validBuses = buses
        .where((bus) => _isWithinTimeRange(Reservation(
              id: 0,
              hallAppointmentDataId: 0,
              appointmentTime: '${bus['abscissa']} ${bus['yaxis']}',
              resourceName: bus['route_name'],
            )))
        .where((bus) => _isInSelectedDirection(bus['route_name']))
        .toList();

    print("validBuses: $validBuses");
    if (validBuses.isNotEmpty) {
      final bus = validBuses.first;
      final resourceId = bus['bus_id'].toString();
      final startTime = '${bus['abscissa']} ${bus['yaxis']}';
      print("resourceId: $resourceId");
      print("startTime: $startTime");
      final code = await service.getTempQRCode(resourceId, startTime);
      print("code: $code");
      return {
        'code': code,
        'departureTime': bus['yaxis'], // 这里已经是正确的发车时间
        'routeName': bus['route_name'],
      };
    }
    return null;
  }

  Reservation _selectReservation(List<Reservation> reservations) {
    final now = DateTime.now();
    final isGoingToYanyuan = now.hour < 12; // 假设中午12点前去燕园，之后回昌平
    return reservations.firstWhere(
      (r) => r.resourceName.contains(isGoingToYanyuan ? '燕园' : '昌平'),
      orElse: () => reservations.first,
    );
  }

  bool _isWithinTimeRange(Reservation reservation) {
    final now = DateTime.now();
    final appointmentTime = DateTime.parse(reservation.appointmentTime);
    final diffInMinutes = appointmentTime.difference(now).inMinutes;
    return appointmentTime.day == now.day &&
        diffInMinutes >= -10 &&
        diffInMinutes <= 30;
  }

  bool _isInSelectedDirection(String routeName) {
    final indexYan = routeName.indexOf('燕');
    final indexXin = routeName.indexOf('新');
    if (indexYan == -1 || indexXin == -1) return false;
    if (_isGoingToYanyuan) {
      return indexXin < indexYan;
    } else {
      return indexYan < indexXin;
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _isRefreshing = true; // 开始刷新
      _errorMessage = ''; // 清空错误信息
    });
    await _loadRideData(); // 不传入参数，使用默认值 isInitialLoad = false
  }

  void _toggleDirection() async {
    setState(() {
      _isToggleLoading = true; // 开始切换方向，按钮显示加载状态
      _isGoingToYanyuan = !_isGoingToYanyuan; // 切换方向
      _errorMessage = ''; // 清空错误信息
    });
    await _loadRideData(); // 不传入参数，使用默认值
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 获取底部安全区域的高度
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // 估计底部导航栏的高度（通常是56）
    const bottomNavBarHeight = 56.0;

    return Scaffold(
      body: _isInitialLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: SafeArea(
                bottom: false, // 不考虑底部安全区域
                child: Center(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 40,
                      bottom: 40 +
                          bottomNavBarHeight +
                          bottomPadding, // 考虑底部导航栏和安全区域
                    ),
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard() {
    bool isNoBusAvailable =
        _errorMessage == '这会去${_isGoingToYanyuan ? '燕园' : '昌平'}没有班车可坐😅';

    return Card(
      elevation: 6, // 降低阴影高度
      shadowColor: Colors.black.withOpacity(0.1), // 使用半透明的黑色作为阴影颜色
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isNoBusAvailable) _buildCardHeader(),
          Padding(
            padding: EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isNoBusAvailable)
                  Text(_errorMessage, style: TextStyle(fontSize: 16))
                else if (_qrCode != null && _qrCode!.isNotEmpty)
                  ..._buildQRCodeContent()
                else
                  Text('暂无二维码', style: TextStyle(fontSize: 16)),
                SizedBox(height: 20),
                _buildReverseButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.2), Colors.blue.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text(
          _codeType,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQRCodeContent() {
    return [
      Text(
        _routeName,
        style: TextStyle(
          fontSize: _routeName.length > 10 ? 16 : 20,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 12),
      Text(
        _departureTime,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      SizedBox(height: 25),
      Container(
        width: 200,
        height: 200,
        color: Colors.white,
        child: QrImageView(
          data: _qrCode!,
          size: 200.0,
        ),
      ),
    ];
  }

  Widget _buildReverseButton() {
    return ElevatedButton(
      onPressed: _isToggleLoading ? null : _toggleDirection,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isToggleLoading
            ? Colors.grey.shade200
            : Colors.blue.withOpacity(0.08),
        foregroundColor: _isToggleLoading ? Colors.grey : Colors.blue,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isToggleLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          else ...[
            Icon(Icons.swap_horiz, size: 20),
            SizedBox(width: 8),
            Text('乘坐反向班车',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
