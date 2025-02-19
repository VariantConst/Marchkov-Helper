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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: title.length > 4 ? 16 : 20,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildBusButtons(context),
        ),
      ],
    );
  }

  Widget _buildBusButtons(BuildContext context) {
    final theme = Theme.of(context);
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

    if (morningButtons.isEmpty &&
        afternoonButtons.isEmpty &&
        eveningButtons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '当日该班次已无车可坐',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (morningButtons.isNotEmpty) ...[
          _buildTimeSection(context, '上午', morningButtons),
          const SizedBox(height: 16),
        ],
        if (afternoonButtons.isNotEmpty) ...[
          _buildTimeSection(context, '下午', afternoonButtons),
          const SizedBox(height: 16),
        ],
        if (eveningButtons.isNotEmpty)
          _buildTimeSection(context, '晚上', eveningButtons),
      ],
    );
  }

  Widget _buildTimeSection(
      BuildContext context, String timeLabel, List<Widget> buttons) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            timeLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: buttons,
        ),
      ],
    );
  }
}
