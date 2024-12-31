import 'dart:math';
import 'package:flutter/material.dart';
import 'stripe_painter.dart';

class RandomPercentageWidget extends StatefulWidget {
  final GlobalKey<RandomPercentageWidgetState>? randomKey;

  const RandomPercentageWidget({
    super.key,
    this.randomKey,
  });

  @override
  State<RandomPercentageWidget> createState() => RandomPercentageWidgetState();
}

class RandomPercentageWidgetState extends State<RandomPercentageWidget> {
  int? randomPercentage;

  void generateRandomPercentage() {
    setState(() {
      randomPercentage = 50 + Random().nextInt(51);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          generateRandomPercentage();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 2,
          ),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 200),
            child: randomPercentage == null
                ? SizedBox(
                    key: ValueKey('initial'),
                    width: 60,
                    height: 40,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: StripePainter(
                                color: theme.colorScheme.primary
                                    .withAlpha((0.2 * 255).toInt()),
                                stripeWidth: 4,
                                gapWidth: 4,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'randint\n(50,100)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    key: ValueKey('percentage'),
                    '$randomPercentage%',
                    style: TextStyle(
                      fontSize: 20,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
