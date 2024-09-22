// lib/screens/ride/ride_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RidePage extends StatefulWidget {
  const RidePage({super.key});

  @override
  RidePageState createState() => RidePageState();
}

class RidePageState extends State<RidePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 保持页面状态

  Reservation? _singleReservation;
  bool _isQRCodeFetched = false;
  int _currentReservationIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReservations());
  }

  void _loadReservations() async {
    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);
    try {
      await reservationProvider.loadCurrentReservations();

      if (!mounted) return;

      final reservations = reservationProvider.currentReservations
          .where(_isWithinTimeRange)
          .toList();

      if (reservations.isNotEmpty) {
        setState(() {
          _currentReservationIndex = 0;
        });
        _fetchQRCodeForCurrentReservation(reservationProvider, reservations);
      }
    } catch (e) {
      print('加载预约时出错: $e');
      // 可以在这里显示一个错误提示
    }
  }

  void _fetchQRCodeForCurrentReservation(
      ReservationProvider reservationProvider, List<Reservation> reservations) {
    if (reservations.isEmpty) {
      print('没有可用的预约');
      return;
    }
    final currentReservation = reservations[_currentReservationIndex];
    try {
      reservationProvider.fetchQRCode(
        currentReservation.id.toString(),
        currentReservation.hallAppointmentDataId.toString(),
      );
    } catch (e) {
      print('获取二维码时出错: $e');
      // 可以在这里显示一个错误提示
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 需要

    return Scaffold(
      appBar: AppBar(
        title: const Text('乘车'),
      ),
      body: Consumer<ReservationProvider>(
        builder: (context, reservationProvider, child) {
          if (reservationProvider.isLoadingReservations) {
            return Center(child: CircularProgressIndicator());
          } else if (reservationProvider.error != null) {
            return Center(child: Text('错误：${reservationProvider.error}'));
          } else {
            final reservations = reservationProvider.currentReservations
                .where(_isWithinTimeRange)
                .toList();

            if (reservations.isEmpty) {
              return Center(child: Text('暂时没有可用预约'));
            } else {
              return _buildReservationDisplay(
                  reservationProvider, reservations);
            }
          }
        },
      ),
    );
  }

  Widget _buildReservationDisplay(
      ReservationProvider reservationProvider, List<Reservation> reservations) {
    if (reservationProvider.isLoadingQRCode) {
      return Center(child: CircularProgressIndicator());
    } else if (reservationProvider.qrCode != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QrImageView(
            data: reservationProvider.qrCode!,
            version: QrVersions.auto,
            size: 200.0,
          ),
          SizedBox(height: 20),
          Text(
            '预约：${reservations[_currentReservationIndex].resourceName}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            '发车时间：${reservations[_currentReservationIndex].appointmentTime}',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          if (reservations.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _currentReservationIndex > 0
                      ? () => _switchReservation(
                          reservationProvider, reservations, -1)
                      : null,
                  child: Text('上一个'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _currentReservationIndex < reservations.length - 1
                      ? () => _switchReservation(
                          reservationProvider, reservations, 1)
                      : null,
                  child: Text('下一个'),
                ),
              ],
            ),
        ],
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('无法获取二维码'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fetchQRCodeForCurrentReservation(
                  reservationProvider, reservations),
              child: Text('重试'),
            ),
          ],
        ),
      );
    }
  }

  void _switchReservation(ReservationProvider reservationProvider,
      List<Reservation> reservations, int direction) {
    setState(() {
      _currentReservationIndex = (_currentReservationIndex + direction)
          .clamp(0, reservations.length - 1);
    });
    _fetchQRCodeForCurrentReservation(reservationProvider, reservations);
  }

  bool _isWithinTimeRange(Reservation reservation) {
    final now = DateTime.now();
    final appointmentTime = DateTime.parse(reservation.appointmentTime);
    final diffInMinutes = appointmentTime.difference(now).inMinutes;

    return appointmentTime.day == now.day &&
        diffInMinutes >= -10 &&
        diffInMinutes <= 30;
  }
}
