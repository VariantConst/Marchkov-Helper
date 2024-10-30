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
                          theme.colorScheme.primary.withOpacity(0),
                          theme.colorScheme.primary.withOpacity(0.5),
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.5),
                          theme.colorScheme.primary.withOpacity(0),
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary.withOpacity(0.3),
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
    return filteredBusList.where((bus) {
      final name = bus['route_name'] ?? '';
      if (direction == '去昌平') {
        return name.contains('燕') &&
            name.contains('新') &&
            name.indexOf('燕') < name.indexOf('新');
      } else {
        return name.contains('燕') &&
            name.contains('新') &&
            name.indexOf('新') < name.indexOf('燕');
      }
    }).toList();
  }
}
