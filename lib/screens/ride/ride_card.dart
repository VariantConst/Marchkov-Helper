import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'ride_card_header.dart';
import 'ride_button.dart';

class RideCard extends StatelessWidget {
  final Map<String, dynamic> cardState;
  final bool isGoingToYanyuan;
  final VoidCallback onMakeReservation;
  final VoidCallback onCancelReservation;
  final bool isToggleLoading;

  const RideCard({
    super.key,
    required this.cardState,
    required this.isGoingToYanyuan,
    required this.onMakeReservation,
    required this.onCancelReservation,
    required this.isToggleLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isNoBusAvailable = cardState['errorMessage'] ==
        '这会去${isGoingToYanyuan ? '燕园' : '昌平'}没有班车可坐😅';

    final departureTimeStr = cardState['departureTime'];
    final nowStr = DateFormat('HH:mm').format(DateTime.now());
    final isPastDeparture = departureTimeStr.compareTo(nowStr) <= 0;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    Color textColor;
    Color borderColor;
    Color buttonColor;
    Color backgroundColor;

    if (isNoBusAvailable) {
      textColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
      borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
      buttonColor = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;
      backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.grey[100]!;
    } else if (cardState['codeType'] == '临时码') {
      textColor = theme.colorScheme.secondary;
      borderColor = theme.colorScheme.secondary.withOpacity(0.3);
      buttonColor = theme.colorScheme.secondary.withOpacity(0.1);
      backgroundColor = theme.colorScheme.secondary.withOpacity(0.05);
    } else {
      textColor = theme.colorScheme.primary;
      borderColor = theme.colorScheme.primary.withOpacity(0.3);
      buttonColor = theme.colorScheme.primary.withOpacity(0.1);
      backgroundColor = theme.colorScheme.primary.withOpacity(0.05);
    }

    return Card(
      elevation: 6,
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RideCardHeader(
            isNoBusAvailable: isNoBusAvailable,
            codeType: cardState['codeType'],
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isNoBusAvailable)
                    _buildNoBusAvailableContent(
                        context, textColor, isGoingToYanyuan)
                  else
                    _buildBusContent(
                        context, cardState, textColor, borderColor, isDarkMode),
                  SizedBox(height: 20),
                  if (!isPastDeparture)
                    RideButton(
                      isReservation: cardState['codeType'] == '乘车码',
                      isToggleLoading: isToggleLoading,
                      onPressed: cardState['codeType'] == '乘车码'
                          ? onCancelReservation
                          : onMakeReservation,
                      buttonColor: buttonColor,
                      textColor: textColor,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBusAvailableContent(
      BuildContext context, Color textColor, bool isGoingToYanyuan) {
    return Column(
      children: [
        Text('😅', style: TextStyle(fontSize: 80)),
        SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '去'),
              TextSpan(
                text: isGoingToYanyuan ? '燕园' : '昌平',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: '方向'),
            ],
          ),
          style: TextStyle(fontSize: 24, color: textColor),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          '这会没有班车可坐，急了？',
          style: TextStyle(fontSize: 14, color: textColor),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          '只有过去30分钟到未来30分钟内\n发车的班车乘车码才会在这里显示。',
          style: TextStyle(fontSize: 12, color: textColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBusContent(BuildContext context, Map<String, dynamic> cardState,
      Color textColor, Color borderColor, bool isDarkMode) {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: Center(
            child: Text(
              cardState['routeName'],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          cardState['departureTime'],
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 20),
        if (cardState['codeType'] == '乘车码' || cardState['codeType'] == '临时码')
          GestureDetector(
            onTap: () {
              if (cardState['qrCode'] != null) {
                _showFullScreenQRCode(context, cardState['qrCode']);
              }
            },
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[400]! : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Center(
                child: cardState['qrCode'] != null
                    ? QrImageView(
                        data: cardState['qrCode'],
                        version: 13,
                        size: 200.0,
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            isDarkMode ? Colors.grey[400]! : Colors.white,
                        eyeStyle: QrEyeStyle(
                          color: isDarkMode ? Colors.black : Colors.grey[700]!,
                          eyeShape: QrEyeShape.square,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          color: isDarkMode ? Colors.black : Colors.grey[700]!,
                          dataModuleShape: QrDataModuleShape.square,
                        ),
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      )
                    : Text('无效的二维码'),
              ),
            ),
          )
        else if (cardState['codeType'] == '待预约')
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: Text(
                '待预约',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFullScreenQRCode(BuildContext context, String qrCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SafariStyleQRCodePage(
          qrCode: qrCode,
          routeName: cardState['routeName'],
          departureTime: cardState['departureTime'],
        ),
      ),
    );
  }
}

class SafariStyleQRCodePage extends StatelessWidget {
  final String qrCode;
  final String routeName;
  final String departureTime;

  const SafariStyleQRCodePage({
    super.key,
    required this.qrCode,
    required this.routeName,
    required this.departureTime,
  });

  @override
  Widget build(BuildContext context) {
    final pekingRed = Color.fromRGBO(140, 0, 0, 1.0);

    // 获取当前日期
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    // 组合完整的预约时段
    final fullDepartureTime = '$formattedDate $departureTime';

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 20),
          Text(
            '预约签到',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: pekingRed,
            ),
          ),
          Divider(color: pekingRed),
          Text(
            '【$routeName】',
            style: TextStyle(fontSize: 16),
          ),
          Text(
            '预约时段：$fullDepartureTime',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: QrImageView(
              data: qrCode,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: pekingRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text('关闭'),
          ),
          Spacer(), // 添加 Spacer 来将剩余空间推到底部工具栏之上
          Container(
            height: 50,
            color: Colors.grey[300],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.arrow_back_ios, color: Colors.blue),
                Icon(Icons.arrow_forward_ios, color: Colors.blue),
                Icon(Icons.share, color: Colors.blue),
                Icon(Icons.book, color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
