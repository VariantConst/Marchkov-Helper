import 'package:flutter/material.dart';
import 'bus_section.dart';

class BusList extends StatelessWidget {
  final List<dynamic> filteredBusList;
  final Function(Map<String, dynamic>) onBusCardTap;
  final Function(Map<String, dynamic>) showBusDetails;
  final Map<String, dynamic> reservedBuses;
  final Map<String, String> buttonCooldowns;
  final bool isRefreshing;

  const BusList({
    super.key,
    required this.filteredBusList,
    required this.onBusCardTap,
    required this.showBusDetails,
    required this.reservedBuses,
    required this.buttonCooldowns,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(top: 24),
          children: [
            BusSection(
              title: '去燕园',
              buses: _getBusesByDirection('去燕园'),
              onBusCardTap: onBusCardTap,
              showBusDetails: showBusDetails,
              reservedBuses: reservedBuses,
              buttonCooldowns: buttonCooldowns,
            ),
            BusSection(
              title: '去昌平',
              buses: _getBusesByDirection('去昌平'),
              onBusCardTap: onBusCardTap,
              showBusDetails: showBusDetails,
              reservedBuses: reservedBuses,
              buttonCooldowns: buttonCooldowns,
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: isRefreshing
                ? Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          theme.colorScheme.primary
                              .withAlpha((0 * 255).toInt()),
                          theme.colorScheme.primary
                              .withAlpha((0.5 * 255).toInt()),
                          theme.colorScheme.primary
                              .withAlpha((1 * 255).toInt()),
                          theme.colorScheme.primary
                              .withAlpha((0.5 * 255).toInt()),
                          theme.colorScheme.primary
                              .withAlpha((0 * 255).toInt()),
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary
                              .withAlpha((0.3 * 255).toInt()),
                        ),
                        minHeight: 2,
                      ),
                    ),
                  )
                : SizedBox(height: 2),
          ),
        ),
      ],
    );
  }

  List<dynamic> _getBusesByDirection(String direction) {
    // 定义去昌平方向的路线（即：燕园校区在前，新燕园校区在后）
    final routesToChangping = <String>{
      "燕园校区→新燕园校区",
      "燕园校区→新燕园校区→200号校区",
      "燕园校区→肖家河→西二旗→新燕园校区→200号校区",
    };

    // 定义去燕园方向的路线（即：新燕园校区在前，燕园校区在后）
    final routesToYanyuan = <String>{
      "新燕园校区→燕园校区",
      "200号校区→新燕园校区→燕园校区",
      "200号校区→新燕园校区→西二旗→肖家河→燕园校区",
    };

    return filteredBusList.where((bus) {
      final routeName = bus['route_name'] ?? '';
      if (direction == '去昌平') {
        return routesToChangping.contains(routeName);
      } else if (direction == '去燕园') {
        return routesToYanyuan.contains(routeName);
      }
      return false;
    }).toList();
  }
}
