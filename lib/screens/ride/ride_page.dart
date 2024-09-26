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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadNearbyBuses();
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildBusLabels(),
            Expanded(
              child: _selectedBusIndex == -1
                  ? Center(child: Text('请选择一个班车'))
                  : _buildCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusLabels() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _nearbyBuses.length,
        itemBuilder: (context, index) {
          final bus = _nearbyBuses[index];
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('${bus['yaxis']} ${bus['route_name']}'),
              selected: _selectedBusIndex == index,
              onSelected: (selected) {
                if (selected) {
                  _selectBus(index);
                }
              },
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
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCardHeader(isNoBusAvailable),
            Padding(
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
      Text(
        _routeName,
        style: TextStyle(
          fontSize: _routeName.length > 10 ? 16 : 20,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: 12),
      Text(
        _departureTime,
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      SizedBox(height: 25),
      Container(
        width: 220,
        height: 220,
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
                  size: 180.0,
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
      width: 220,
      height: 48,
      child: ElevatedButton(
        onPressed: _isToggleLoading ? null : _toggleDirection,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isToggleLoading ? Colors.grey.shade200 : buttonColor,
          foregroundColor: _isToggleLoading ? Colors.grey : textColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isToggleLoading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz, size: 20),
                  SizedBox(width: 8),
                  Text('乘坐反向班车',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  void _toggleDirection() async {
    setState(() {
      _isToggleLoading = true;
      _isGoingToYanyuan = !_isGoingToYanyuan;
      _errorMessage = '';
    });
    await _loadNearbyBuses();
    setState(() {
      _isToggleLoading = false;
    });
  }
}
