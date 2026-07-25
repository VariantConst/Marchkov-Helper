import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marchkov_helper/screens/ride/ride_card.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildRideCard() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 700,
        child: RideCard(
          cardState: {
            'routeName': '测试路线',
            'departureTime': '23:59',
            'codeType': '乘车码',
            'qrCode': 'test-qr-code',
            'errorMessage': '',
          },
          isGoingToYanyuan: true,
          onMakeReservation: () {},
          onCancelReservation: () {},
          isToggleLoading: false,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QR tap explains how to enable the official-style page',
      (tester) async {
    SharedPreferences.setMockInitialValues({'safariStyleEnabled': false});
    await tester.pumpWidget(_buildRideCard());

    await tester.tap(find.byType(QrImageView));
    await tester.pumpAndSettle();

    expect(find.textContaining('开启仿官方页面'), findsOneWidget);
  });

  testWidgets('QR tap opens the official-style page when enabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({'safariStyleEnabled': true});
    await tester.pumpWidget(_buildRideCard());

    await tester.tap(find.byType(QrImageView));
    await tester.pumpAndSettle();

    expect(find.text('预约签到'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('wproc.pku.edu.cn'),
      ),
      findsOneWidget,
    );
  });
}
