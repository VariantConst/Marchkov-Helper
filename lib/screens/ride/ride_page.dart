// lib/screens/ride/ride_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReservations());
  }

  void _loadReservations() async {
    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);
    await reservationProvider.loadCurrentReservations();

    if (!mounted) return;

    final reservations = reservationProvider.currentReservations
        .where(_isWithinTimeRange)
        .toList();

    if (reservations.length == 1) {
      setState(() {
        _singleReservation = reservations.first;
      });
      _fetchQRCode();
    }
  }

  void _fetchQRCode() async {
    if (_isQRCodeFetched || _singleReservation == null) return;

    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);

    await reservationProvider.fetchQRCode(
      _singleReservation!.id.toString(),
      _singleReservation!.hallAppointmentDataId.toString(),
    );

    if (!mounted) return;

    setState(() {
      _isQRCodeFetched = true;
    });
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
            } else if (reservations.length == 1) {
              if (reservationProvider.isLoadingQRCode || !_isQRCodeFetched) {
                return Center(child: CircularProgressIndicator());
              } else if (reservationProvider.qrCode != null) {
                return _buildQRCodeDisplay(reservationProvider.qrCode!);
              } else {
                return Center(child: Text('无法获取二维码'));
              }
            } else {
              // 有多个预约，显示列表
              return ListView.builder(
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  final reservation = reservations[index];
                  return Card(
                    child: ListTile(
                      title: Text(reservation.resourceName),
                      subtitle: Text('发车时间：${reservation.appointmentTime}'),
                      onTap: () async {
                        await reservationProvider.fetchQRCode(
                          reservation.id.toString(),
                          reservation.hallAppointmentDataId.toString(),
                        );

                        if (!mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QRCodeDisplayPage(
                              qrCode: reservationProvider.qrCode!,
                              reservations: reservations,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
          }
        },
      ),
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

  Widget _buildQRCodeDisplay(String qrCode) {
    return Center(
      child: Text('二维码：$qrCode'),
      // 您可以使用 QR 码库将字符串生成真正的二维码图片
    );
  }
}

class QRCodeDisplayPage extends StatefulWidget {
  final String qrCode;
  final List<Reservation> reservations;
  final int initialIndex;

  QRCodeDisplayPage({
    required this.qrCode,
    required this.reservations,
    required this.initialIndex,
  });

  @override
  QRCodeDisplayPageState createState() => QRCodeDisplayPageState();
}

class QRCodeDisplayPageState extends State<QRCodeDisplayPage> {
  late int _currentIndex;
  late String _currentQRCode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentQRCode = widget.qrCode;
  }

  void _loadQRCode(int index) async {
    setState(() {
      _isLoading = true;
    });

    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);
    final reservation = widget.reservations[index];
    await reservationProvider.fetchQRCode(
      reservation.id.toString(),
      reservation.hallAppointmentDataId.toString(),
    );

    if (!mounted) return;

    setState(() {
      _currentQRCode = reservationProvider.qrCode!;
      _currentIndex = index;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('二维码'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('二维码：$_currentQRCode'),
                  // 您可以使用 QR 码库将字符串生成真正的二维码图片
                  SizedBox(height: 20),
                  Text(
                    '预约：${widget.reservations[_currentIndex].resourceName}',
                  ),
                  Text(
                    '发车时间：${widget.reservations[_currentIndex].appointmentTime}',
                  ),
                  SizedBox(height: 20),
                  _buildNavigationButtons(),
                ],
              ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed:
              _currentIndex > 0 ? () => _loadQRCode(_currentIndex - 1) : null,
          child: Text('上一个'),
        ),
        SizedBox(width: 20),
        ElevatedButton(
          onPressed: _currentIndex < widget.reservations.length - 1
              ? () => _loadQRCode(_currentIndex + 1)
              : null,
          child: Text('下一个'),
        ),
      ],
    );
  }
}
