import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 添加导入
import 'dart:math' show pi;

class BusButton extends StatefulWidget {
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
  State<BusButton> createState() => BusButtonState();
}

class BusButtonState extends State<BusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isBusReserved(
      Map<String, dynamic> busData, Map<String, dynamic> reservedBuses) {
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String time = busData['yaxis'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';
    return reservedBuses.containsKey(key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busData = widget.busData;
    bool isReserved = _isBusReserved(busData, widget.reservedBuses);
    String time = busData['yaxis'] ?? '';
    String resourceId = busData['bus_id'].toString();
    String date = busData['abscissa'];
    String appointmentTime = '$date $time';
    String key = '$resourceId$appointmentTime';
    bool isCooling = widget.buttonCooldowns[key] != null;
    String actionText = isCooling
        ? (widget.buttonCooldowns[key] == 'reserving' ? '预约中' : '取消中')
        : (isReserved ? '取消预约' : '预约');

    // 边框颜色与原来的进度指示器保持一致
    Color borderColor =
        isReserved ? theme.colorScheme.onPrimary : theme.colorScheme.primary;

    Widget buttonChild = Center(
      child: Text(
        isCooling ? actionText : time,
        style: isCooling
            ? theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isReserved
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              )
            : theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isReserved
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );

    Widget filledButton = FilledButton(
      onPressed: isCooling ? null : () => widget.onBusCardTap(busData),
      onLongPress: () {
        HapticFeedback.heavyImpact();
        widget.showBusDetails(busData);
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: isReserved ? 2 : 0,
      ),
      child: SizedBox(
        height: 36,
        child: buttonChild,
      ),
    );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4.0),
        child: Stack(
          children: [
            filledButton,
            if (isCooling)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: GlowingBorderPainter(
                        progress: _controller.value,
                        glowColor: borderColor,
                        borderRadius: 12,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GlowingBorderPainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final double borderRadius;

  GlowingBorderPainter({
    required this.progress,
    required this.glowColor,
    this.borderRadius = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // 创建更精致的渐变效果
    final gradientPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          glowColor.withValues(alpha: 0),
          glowColor.withValues(alpha: 0.1),
          glowColor.withValues(alpha: 0.3),
          glowColor.withValues(alpha: 0.5),
          glowColor.withValues(alpha: 0.3),
          glowColor.withValues(alpha: 0.1),
          glowColor.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.2, 0.3, 0.5, 0.7, 0.8, 1.0],
        transform: GradientRotation(2 * pi * progress),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 绘制主边框
    final borderPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 先绘制底部边框
    canvas.drawRRect(rrect, borderPaint);

    // 再绘制动态渐变
    canvas.drawRRect(rrect, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant GlowingBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor;
  }
}
