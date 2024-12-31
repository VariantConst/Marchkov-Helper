import 'package:flutter/material.dart';

class RideCardHeader extends StatelessWidget {
  final bool isNoBusAvailable;
  final String codeType;

  const RideCardHeader({
    super.key,
    required this.isNoBusAvailable,
    required this.codeType,
  });

  @override
  Widget build(BuildContext context) {
    Color startColor;
    Color endColor;
    Color textColor;
    String headerText;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (isNoBusAvailable) {
      startColor = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;
      endColor = isDarkMode ? Colors.grey[900]! : Colors.grey[100]!;
      textColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
      headerText = '无车可坐';
    } else {
      if (codeType == '乘车码') {
        startColor = theme.colorScheme.primary.withAlpha((0.2 * 255).toInt());
        endColor = theme.colorScheme.primary.withAlpha((0.05 * 255).toInt());
        textColor = theme.colorScheme.primary;
        headerText = '乘车码';
      } else if (codeType == '临时码') {
        startColor = theme.colorScheme.secondary.withAlpha((0.2 * 255).toInt());
        endColor = theme.colorScheme.secondary.withAlpha((0.05 * 255).toInt());
        textColor = theme.colorScheme.secondary;
        headerText = '临时码';
      } else {
        startColor = theme.colorScheme.tertiary.withAlpha((0.2 * 255).toInt());
        endColor = theme.colorScheme.tertiary.withAlpha((0.05 * 255).toInt());
        textColor = theme.colorScheme.tertiary;
        headerText = '待预约';
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text(
          headerText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
