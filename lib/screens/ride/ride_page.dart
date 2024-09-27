import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';

class RidePage extends StatefulWidget {
  const RidePage({super.key});

  @override
  RidePageState createState() => RidePageState();
}

class RidePageState extends State<RidePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _qrCode;
  bool _isToggleLoading = false;
  String _errorMessage = '';
  String _departureTime = '';
  String _routeName = '';
  String _codeType = '';

  bool _isGoingToYanyuan = true;

  List<Map<String, dynamic>> _nearbyBuses = [];
  int _selectedBusIndex = -1;

  // 添加预约相关变量
  String? _appointmentId;
  String? _hallAppointmentDataId;

  // 添加 PageController 属性
  late PageController _pageController;

  // 添加一个加载状态变量
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();

    // 初始化 PageController，设置初始页面和视口Fraction
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.6,
    );
  }

  @override
  void dispose() {
    // 释放 PageController 资源
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadNearbyBuses();

    if (_nearbyBuses.isNotEmpty) {
      setState(() {
        _selectedBusIndex = 0;
      });
      await _selectBus(0); // 选择第一个可用的班车
    } else {
      setState(() {
        _errorMessage = '无车可坐';
      });
    }

    // 数据加载完成，更新加载状态
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadNearbyBuses() async {
    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));
    final now = DateTime.now();
    final todayString = now.toIso8601String().split('T')[0];

    try {
      final allBuses = await reservationService.getAllBuses([todayString]);
      _nearbyBuses = allBuses
          .where((bus) {
            final busTime =
                DateTime.parse('${bus['abscissa']} ${bus['yaxis']}');
            final diff = busTime.difference(now).inMinutes;
            return diff >= -10 && diff <= 30;
          })
          .toList()
          .cast<Map<String, dynamic>>();

      setState(() {});
    } catch (e) {
      print('加载附近班车失败: $e');
    }
  }

  Future<void> _selectBus(int index) async {
    setState(() {
      _selectedBusIndex = index;
      _errorMessage = '';
    });

    final bus = _nearbyBuses[index];
    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);
    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));

    try {
      await reservationProvider.loadCurrentReservations();
      Reservation? matchingReservation;

      try {
        matchingReservation =
            reservationProvider.currentReservations.firstWhere(
          (reservation) =>
              reservation.resourceName == bus['route_name'] &&
              reservation.appointmentTime ==
                  '${bus['abscissa']} ${bus['yaxis']}',
        );
      } catch (e) {
        matchingReservation = null; // 如果没有找到匹配的预约，设置为 null
      }

      if (matchingReservation != null) {
        await _fetchQRCode(reservationProvider, matchingReservation);
      } else {
        final tempCode = await _fetchTempCode(reservationService, bus);
        if (tempCode != null) {
          setState(() {
            _qrCode = tempCode['code'];
            _departureTime = tempCode['departureTime']!;
            _routeName = tempCode['routeName']!;
            _codeType = '临时码';
          });
        } else {
          setState(() {
            _errorMessage = '无法获取乘车码';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载数据时出错: $e';
      });
    }
  }

  Future<void> _fetchQRCode(
      ReservationProvider provider, Reservation reservation) async {
    try {
      await provider.fetchQRCode(
        reservation.id.toString(),
        reservation.hallAppointmentDataId.toString(),
      );

      final actualDepartureTime = await _getActualDepartureTime(reservation);

      setState(() {
        _qrCode = provider.qrCode;
        _departureTime = actualDepartureTime;
        _routeName = reservation.resourceName;
        _codeType = '乘车码';
        _appointmentId = reservation.id.toString(); // 存储预约ID
        _hallAppointmentDataId =
            reservation.hallAppointmentDataId.toString(); // 存储大厅预约数据ID
      });
    } catch (e) {
      setState(() {
        _errorMessage = '获取二维码时出错: $e';
      });
    }
  }

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
    return reservation.appointmentTime.split(' ')[1];
  }

  Future<Map<String, String>?> _fetchTempCode(
      ReservationService service, Map<String, dynamic> bus) async {
    final resourceId = bus['bus_id'].toString();
    final startTime = '${bus['abscissa']} ${bus['yaxis']}';
    final code = await service.getTempQRCode(resourceId, startTime);
    return {
      'code': code,
      'departureTime': bus['yaxis'],
      'routeName': bus['route_name'],
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _nearbyBuses.isEmpty
                  ? Center(child: Text('无车可坐')) // 当没有班车时显示提示信息
                  : _selectedBusIndex == -1
                      ? Center(child: Text('请选择一个班车'))
                      : _buildCard(),
            ),
            SizedBox(
              height: 120,
              child: _nearbyBuses.isEmpty
                  ? SizedBox.shrink() // 当没有班车时不显示底部选择器
                  : _buildBusPicker(),
            ),
          ],
        ),
      ),
    );
  }

  // 新的滚动选择器方法
  Widget _buildBusPicker() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: PageView.builder(
        controller: _pageController,
        itemCount: _nearbyBuses.length,
        onPageChanged: (index) {
          setState(() {
            _selectBus(index);
          });
        },
        itemBuilder: (context, index) {
          final bus = _nearbyBuses[index];
          bool isSelected = index == _selectedBusIndex;

          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
              }
              return Center(
                child: SizedBox(
                  height: Curves.easeOut.transform(value) * 100,
                  width: Curves.easeOut.transform(value) * 180,
                  child: child,
                ),
              );
            },
            child: Card(
              elevation: isSelected ? 4 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isSelected ? Colors.blue.shade50 : Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      bus['yaxis'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? Colors.blue.shade700 : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      bus['route_name'],
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isSelected ? Colors.blue.shade600 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard() {
    bool isNoBusAvailable =
        _errorMessage == '这会去${_isGoingToYanyuan ? '燕园' : '昌平'}没有班车可坐😅';

    Color cardColor;
    Color textColor;
    Color borderColor;
    Color buttonColor;

    if (isNoBusAvailable) {
      cardColor = Colors.grey[200]!;
      textColor = Colors.grey[700]!;
      borderColor = Colors.grey[400]!;
      buttonColor = Colors.grey[300]!;
    } else if (_codeType == '临时码') {
      cardColor = Colors.white;
      textColor = Colors.orange[700]!;
      borderColor = Colors.orange[200]!.withOpacity(0.5);
      buttonColor = Colors.orange[100]!.withOpacity(0.5);
    } else {
      cardColor = Colors.white;
      textColor = Colors.blue;
      borderColor = Colors.blue.withOpacity(0.2);
      buttonColor = Theme.of(context).colorScheme.primary.withOpacity(0.1);
    }

    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      child: SizedBox(
        width: MediaQuery.of(context).size.width - 40,
        height: 540,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCardHeader(isNoBusAvailable),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isNoBusAvailable)
                      Column(
                        children: [
                          Text('😅', style: TextStyle(fontSize: 100)),
                          SizedBox(height: 20),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '去'),
                                TextSpan(
                                  text: _isGoingToYanyuan ? '燕园' : '昌平',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '方向'),
                              ],
                            ),
                            style: TextStyle(fontSize: 32, color: textColor),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 10),
                          Text(
                            '这会没有班车可坐，急了？',
                            style: TextStyle(fontSize: 16, color: textColor),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 10),
                          Text(
                            '只有过去10分钟到未来30分钟内\n发车的班车乘车码才会在这里显示。',
                            style: TextStyle(fontSize: 10, color: textColor),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 55),
                        ],
                      )
                    else if (_qrCode != null && _qrCode!.isNotEmpty)
                      ..._buildQRCodeContent(textColor, borderColor)
                    else
                      Text('暂无二维码',
                          style: TextStyle(fontSize: 16, color: textColor)),
                    SizedBox(height: 20),
                    _buildReverseButton(buttonColor, textColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(bool isNoBusAvailable) {
    Color startColor;
    Color endColor;
    Color textColor;
    String headerText;

    if (isNoBusAvailable) {
      startColor = Colors.grey[300]!;
      endColor = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
      headerText = '无车可坐';
    } else if (_codeType == '临时码') {
      startColor = Colors.orange[100]!.withOpacity(0.5);
      endColor = Colors.orange[50]!.withOpacity(0.3);
      textColor = Colors.orange[700]!;
      headerText = _codeType;
    } else {
      startColor = Colors.blue.withOpacity(0.2);
      endColor = Colors.blue.withOpacity(0.05);
      textColor = Colors.blue;
      headerText = _codeType;
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text(
          headerText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQRCodeContent(Color textColor, Color borderColor) {
    return [
      SizedBox(
        height: 40,
        child: Center(
          child: Text(
            _routeName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      SizedBox(height: 16),
      Text(
        _departureTime,
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      SizedBox(height: 30),
      Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Center(
          child: _qrCode != null
              ? QrImageView(
                  data: _qrCode!,
                  version: 13,
                  size: 200.0,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    color: Colors.grey[700],
                    eyeShape: QrEyeShape.square,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    color: Colors.grey[700],
                    dataModuleShape: QrDataModuleShape.square,
                  ),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                )
              : Text('无效的二维码'),
        ),
      ),
    ];
  }

  Widget _buildReverseButton(Color buttonColor, Color textColor) {
    return SizedBox(
      width: 240,
      height: 56,
      child: ElevatedButton(
        onPressed: _isToggleLoading
            ? null
            : (_codeType == '临时码' ? _makeReservation : _cancelReservation),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isToggleLoading ? Colors.grey.shade200 : buttonColor,
          foregroundColor: _isToggleLoading ? Colors.grey : textColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isToggleLoading
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                ),
              )
            : Text(
                _codeType == '临时码' ? '预约' : '取消预约',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _makeReservation() async {
    if (_selectedBusIndex == -1) {
      setState(() {
        _errorMessage = '请选择一个班车进行预约';
      });
      return;
    }

    setState(() {
      _isToggleLoading = true;
      _errorMessage = '';
    });

    final bus = _nearbyBuses[_selectedBusIndex];
    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));
    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);

    try {
      await reservationService.makeReservation(
        bus['bus_id'].toString(),
        bus['abscissa'],
        bus['time_id'].toString(),
      );

      // 获取最新的预约列表
      await reservationProvider.loadCurrentReservations();

      // 尝试匹配刚刚预约的班车
      Reservation? matchingReservation;
      try {
        matchingReservation =
            reservationProvider.currentReservations.firstWhere(
          (reservation) =>
              reservation.resourceName == bus['route_name'] &&
              reservation.appointmentTime ==
                  '${bus['abscissa']} ${bus['yaxis']}',
        );
      } catch (e) {
        matchingReservation = null;
      }

      if (matchingReservation != null) {
        // 获取乘车码
        await _fetchQRCode(reservationProvider, matchingReservation);
      } else {
        setState(() {
          _errorMessage = '无法找到匹配的预约信息';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '预约失败: $e';
      });
    } finally {
      setState(() {
        _isToggleLoading = false;
      });
    }
  }

  Future<void> _cancelReservation() async {
    if (_appointmentId == null || _hallAppointmentDataId == null) {
      setState(() {
        _errorMessage = '无有效的预约信息';
      });
      return;
    }

    setState(() {
      _isToggleLoading = true;
      _errorMessage = '';
    });

    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));

    try {
      await reservationService.cancelReservation(
        _appointmentId!,
        _hallAppointmentDataId!,
      );

      // 获取临时码
      final bus = _nearbyBuses[_selectedBusIndex];
      final tempCode = await _fetchTempCode(reservationService, bus);
      if (tempCode != null) {
        setState(() {
          _qrCode = tempCode['code'];
          _departureTime = tempCode['departureTime']!;
          _routeName = tempCode['routeName']!;
          _codeType = '临时码';
          _appointmentId = null;
          _hallAppointmentDataId = null;
        });
      } else {
        setState(() {
          _errorMessage = '无法获取临时码';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '取消预约失败: $e';
      });
    } finally {
      setState(() {
        _isToggleLoading = false;
      });
    }
  }
}
