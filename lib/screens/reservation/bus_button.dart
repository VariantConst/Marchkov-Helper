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

    String actionText = isCooling
        ? (buttonCooldowns[key] == 'reserving' ? '预约中' : '取消中')
        : (isReserved ? '取消预约' : '预约');

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4.0),
        child: FilledButton(
          onPressed: isCooling ? null : () => onBusCardTap(busData),
          onLongPress: () {
            HapticFeedback.heavyImpact();
            showBusDetails(busData);
          },
          style: FilledButton.styleFrom(
            backgroundColor: isReserved
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: isReserved
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            elevation: isReserved ? 2 : 0,
          ),
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: isCooling
                  ? [
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isReserved
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]
                  : [
                      Text(
                        time,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isReserved
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        routeName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isReserved
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
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
