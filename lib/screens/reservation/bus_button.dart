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
    bool isCooling = buttonCooldowns[key] == true;
    String routeName = busData['route_name'] ?? '';

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4.0),
        child: ElevatedButton(
          onPressed: isCooling
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onBusCardTap(busData);
                },
          onLongPress: () {
            HapticFeedback.heavyImpact();
            showBusDetails(busData);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isReserved ? Colors.blueAccent : Colors.white,
            foregroundColor: isReserved ? Colors.white : Colors.black,
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
          child: isCooling
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isReserved ? Colors.white : Colors.blueAccent,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      time,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      routeName,
                      style: TextStyle(
                        fontSize: routeName.length > 10 ? 10 : 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
