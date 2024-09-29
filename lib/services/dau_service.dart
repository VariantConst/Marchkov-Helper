import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'version_service.dart';

class DauService {
  final AuthProvider _authProvider;
  final VersionService _versionService;

  DauService(this._authProvider, this._versionService);

  Future<void> sendDailyActive() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    final lastSentDate = prefs.getString('lastDauSentDate');

    if (lastSentDate == todayString) {
      // 已经发送过今天的 DAU
      return;
    }

    final studentId = _authProvider.username; // 假设 username 是 studentId
    final hash = sha256.convert(utf8.encode(studentId)).toString();

    final version = await _versionService.getCurrentVersion();

    // 检测设备是否为苹果设备
    final isApple = Platform.isIOS || Platform.isMacOS;

    final url =
        'https://cf-marchkov-stats.variantconst.com/?hash=$hash&version=$version&isApple=${isApple ? 1 : 0}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // 发送成功，记录今天的日期
        await prefs.setString('lastDauSentDate', todayString);
      } else {
        print('发送 DAU 请求失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      print('发送 DAU 请求出错: $e');
    }
  }
}
