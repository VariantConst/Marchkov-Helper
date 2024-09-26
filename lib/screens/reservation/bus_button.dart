import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BusButton extends StatelessWidget {
  final Map<String, dynamic> busData;
  final Function(Map<String, dynamic>) onBusCardTap;
  final Function(Map<String, dynamic>) showBusDetails;
  final Map<String, dynamic> reservedBuses;
  final Map<String, bool> buttonCooldowns;

  const BusButton({
    super.key,
    required this.busData,
    required this.onBusCardTap,
    required this.showBusDetails,
    required this.reservedBuses,
    required this.buttonCooldowns,
  });

  @override
  Widget build(BuildContext context) {
    bool isReserved = _isBusReserved();
    String time = busData['yaxis'] ?? '';
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4.0),
        child: ElevatedButton(
          onPressed: () {
            // 添加震动反馈
            HapticFeedback.selectionClick();
            onBusCardTap(busData);
          },
          onLongPress: () {
            // 添加震动反馈
            HapticFeedback.heavyImpact();
            showBusDetails(busData);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isReserved
                ? Colors.blueAccent
                : (buttonCooldowns[key] == true
                    ? Colors.grey[300]
                    : Colors.white),
            foregroundColor: isReserved
                ? Colors.white
                : (buttonCooldowns[key] == true ? Colors.grey : Colors.black),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isReserved ? Colors.blueAccent : Colors.grey,
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
          ),
          child: Text(
            time,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  bool _isBusReserved() {
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';

    return reservedBuses.containsKey(key);
  }
}
