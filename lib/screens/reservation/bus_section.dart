import 'package:flutter/material.dart';
import 'bus_button.dart';

class BusSection extends StatelessWidget {
  final String title;
  final List<dynamic> buses;
  final Function(Map<String, dynamic>) onBusCardTap;
  final Function(Map<String, dynamic>) showBusDetails;
  final Map<String, dynamic> reservedBuses;
  final Map<String, String> buttonCooldowns;

  const BusSection({
    super.key,
    required this.title,
    required this.buses,
    required this.onBusCardTap,
    required this.showBusDetails,
    required this.reservedBuses,
    required this.buttonCooldowns,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    buses.sort((a, b) => a['yaxis'].compareTo(b['yaxis']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildBusButtons(),
        ),
      ],
    );
  }

  Widget _buildBusButtons() {
    List<Widget> morningButtons = [];
    List<Widget> afternoonButtons = [];
    List<Widget> eveningButtons = [];

    for (var busData in buses) {
      String time = busData['yaxis'] ?? '';
      DateTime busTime = DateTime.parse('${busData['abscissa']} $time');

      Widget button = BusButton(
        busData: busData,
        onBusCardTap: onBusCardTap,
        showBusDetails: showBusDetails,
        reservedBuses: reservedBuses,
        buttonCooldowns: buttonCooldowns,
      );

      if (busTime.hour < 12) {
        morningButtons.add(button);
      } else if (busTime.hour < 18) {
        afternoonButtons.add(button);
      } else {
        eveningButtons.add(button);
      }
    }

    return Column(
      children: [
        if (morningButtons.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: morningButtons,
          ),
        if (afternoonButtons.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: afternoonButtons,
          ),
        if (eveningButtons.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: eveningButtons,
          ),
      ],
    );
  }
}
