import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RideButton extends StatelessWidget {
  final bool isReservation;
  final bool isToggleLoading;
  final VoidCallback onPressed;
  final Color buttonColor;
  final Color textColor;

  const RideButton({
    super.key,
    required this.isReservation,
    required this.isToggleLoading,
    required this.onPressed,
    required this.buttonColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 56,
      child: ElevatedButton(
        onPressed: isToggleLoading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isToggleLoading ? Colors.grey.shade200 : buttonColor,
          foregroundColor: isToggleLoading ? Colors.grey : textColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isToggleLoading
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                ),
              )
            : Text(
                isReservation ? '取消预约' : '预约',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
