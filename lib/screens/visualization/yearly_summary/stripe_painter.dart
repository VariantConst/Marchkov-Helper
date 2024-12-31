import 'package:flutter/material.dart';

class StripePainter extends CustomPainter {
  final Color color;
  final double stripeWidth;
  final double gapWidth;

  StripePainter({
    required this.color,
    required this.stripeWidth,
    required this.gapWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stripeWidth
      ..strokeCap = StrokeCap.round;

    final spacing = stripeWidth + gapWidth;
    final count = (size.width + size.height) ~/ spacing;

    for (var i = -count; i < count * 2; i++) {
      final x = i * spacing - size.height;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StripePainter oldDelegate) =>
      color != oldDelegate.color ||
      stripeWidth != oldDelegate.stripeWidth ||
      gapWidth != oldDelegate.gapWidth;
}
