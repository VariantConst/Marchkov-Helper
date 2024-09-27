import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BusButton extends StatelessWidget {
  final Map<String, dynamic> busData;
  final Function(Map<String, dynamic>) onBusCardTap;
  final Function(Map<String, dynamic>) showBusDetails;
  final Map<String, dynamic> reservedBuses;
  final Map<String, String> buttonCooldowns;

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
    bool isCooling = buttonCooldowns[key] != null;
    String routeName = busData['route_name'] ?? '';

    // 3. 根据 buttonCooldowns[key] 确定 actionText
    String actionText;
    if (isCooling) {
      String? action = buttonCooldowns[key];
      if (action == 'reserving') {
        actionText = '预约中';
      } else if (action == 'cancelling') {
        actionText = '取消中';
      } else {
        actionText = isReserved ? '取消预约' : '预约';
      }
    } else {
      actionText = isReserved ? '取消预约' : '预约';
    }

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
          child: SizedBox(
            height: 48, // 固定按钮高度
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isCooling
                  ? [
                      // 保持按钮大小不变，加载中显示
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isReserved ? Colors.white : Colors.blueAccent,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        actionText,
                        style: TextStyle(fontSize: 12),
                      ),
                    ]
                  : [
                      Text(
                        time,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
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
