import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/reservation_service.dart';

class RidePage extends StatefulWidget {
  const RidePage({super.key});

  @override
  RidePageState createState() => RidePageState();
}

class RidePageState extends State<RidePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _qrCode;
  bool _isLoading = true;
  String _errorMessage = '';
  String _departureTime = '';
  String _routeName = '';
  String _codeType = '';

  late bool _isGoingToYanyuan; // 新增变量

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _isGoingToYanyuan = now.hour < 12; // 根据当前时间设置默认方向
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRideData());
  }

  void _toggleDirection() {
    setState(() {
      _isGoingToYanyuan = !_isGoingToYanyuan;
      _errorMessage = ''; // 清空错误信息
    });
    _loadRideData();
  }

  Future<void> _loadRideData() async {
    setState(() {
      _isLoading = true; // 在这里设置为 true
      _errorMessage = ''; // 清空错误信息
    });
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
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = '这会没有班车可坐😅';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载数据时出错: $e';
        _isLoading = false;
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
      setState(() {
        _qrCode = provider.qrCode;
        _departureTime = reservation.appointmentTime;
        _routeName = reservation.resourceName;
        _codeType = '乘车码';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '获取二维码时出错: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<String, String>?> _fetchTempCode(
      ReservationService service) async {
    final now = DateTime.now();
    final buses =
        await service.getAllBuses([now.toIso8601String().split('T')[0]]);
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
        'departureTime': bus['yaxis'],
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isGoingToYanyuan ? '去燕园' : '去昌平'),
            IconButton(
              icon: Icon(Icons.swap_horiz),
              onPressed: _toggleDirection,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _buildQRCodeDisplay(),
    );
  }

  Widget _buildQRCodeDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QrImageView(
            data: _qrCode!,
            size: 200.0,
          ),
          SizedBox(height: 20),
          Text(
            _departureTime,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          Text(
            _routeName,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          Text(
            _codeType,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadRideData,
            child: Text('刷新'),
          ),
        ],
      ),
    );
  }
}
