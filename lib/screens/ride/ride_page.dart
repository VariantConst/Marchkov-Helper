import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ride_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class RidePage extends StatelessWidget {
  const RidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(rideProvider.isGoingToYanyuan ? '去燕园' : '去昌平'),
            IconButton(
              icon: Icon(Icons.swap_horiz),
              onPressed: () {
                rideProvider.toggleDirection();
              },
            ),
          ],
        ),
      ),
      body: rideProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : rideProvider.errorMessage.isNotEmpty
              ? Center(child: Text(rideProvider.errorMessage))
              : _buildQRCodeDisplay(rideProvider),
    );
  }

  Widget _buildQRCodeDisplay(RideProvider rideProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QrImageView(
            data: rideProvider.qrCode!,
            size: 200.0,
          ),
          SizedBox(height: 20),
          Text(
            rideProvider.departureTime,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          Text(
            rideProvider.routeName,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          Text(
            rideProvider.codeType,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              rideProvider
                  .loadRideData(); // 确保 RideProvider 中有 loadRideData() 方法
            },
            child: Text('刷新'),
          ),
        ],
      ),
    );
  }
}
