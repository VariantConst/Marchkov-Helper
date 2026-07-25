import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'version_service.dart';

class DauService {
  final VersionService _versionService;
  static const _installationIdKey = 'dauInstallationId';

  DauService(this._versionService);

  Future<void> sendDailyActive() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    final lastSentDate = prefs.getString('lastDauSentDate');

    if (lastSentDate == todayString) {
      // 已经发送过今天的 DAU
      return;
    }

    var installationId = prefs.getString(_installationIdKey);
    if (installationId == null) {
      final random = Random.secure();
      installationId = List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await prefs.setString(_installationIdKey, installationId);
    }

    final version = await _versionService.getCurrentVersion();

    // 检测设备是否为苹果设备
    final isApple = Platform.isIOS || Platform.isMacOS;

    final url =
        'https://cf-marchkov-stats.variantconst.com/?hash=$installationId&version=$version&isApple=${isApple ? 1 : 0}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // 发送成功，记录今天的日期
        await prefs.setString('lastDauSentDate', todayString);
      }
    } catch (_) {}
  }
}
