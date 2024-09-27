import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 添加导入

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
    final theme = Theme.of(context);

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
                  HapticFeedback.selectionClick(); // 确保 HapticFeedback 可用
                  onBusCardTap(busData);
                },
          onLongPress: () {
            HapticFeedback.heavyImpact(); // 确保 HapticFeedback 可用
            showBusDetails(busData);
          },
          style: ElevatedButton.styleFrom(
            // 移除重复的 backgroundColor 和 foregroundColor
            backgroundColor: isReserved
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            foregroundColor: isReserved
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isReserved
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: 1,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: 4,
            shadowColor: theme.shadowColor.withOpacity(0.2),
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
                            isReserved
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        actionText,
                        style: TextStyle(
                            fontSize: 12,
                            color: isReserved
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface),
                      ),
                    ]
                  : [
                      Text(
                        time,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isReserved
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface),
                      ),
                      SizedBox(height: 4),
                      Text(
                        routeName,
                        style: TextStyle(
                          fontSize: routeName.length > 10 ? 10 : 12,
                          fontWeight: FontWeight.normal,
                          color: isReserved
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
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
