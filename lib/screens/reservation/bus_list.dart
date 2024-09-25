import 'package:flutter/material.dart';
import 'bus_section.dart';

class BusList extends StatelessWidget {
  final List<dynamic> filteredBusList;
  final Function(Map<String, dynamic>) onBusCardTap;
  final Function(Map<String, dynamic>) showBusDetails;
  final Map<String, dynamic> reservedBuses;
  final Map<String, bool> buttonCooldowns;

  const BusList({
    Key? key,
    required this.filteredBusList,
    required this.onBusCardTap,
    required this.showBusDetails,
    required this.reservedBuses,
    required this.buttonCooldowns,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(top: 8),
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
