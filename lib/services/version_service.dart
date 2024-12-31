import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VersionService {
  Future<String> getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<String?> getLatestVersion() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.github.com/repos/VariantConst/Marchkov-Helper/releases/latest'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tagName = data['tag_name'] as String;
        // 移除 'v' 前缀
        return tagName.startsWith('v') ? tagName.substring(1) : tagName;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<String?> getUpdateURL() async {
    try {
      if (Platform.isIOS) {
        return 'https://apps.apple.com/app/id6476472136';
      } else if (Platform.isAndroid) {
        final response = await http.get(Uri.parse(
            'https://api.github.com/repos/VariantConst/Marchkov-Helper/releases/latest'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final assets = data['assets'] as List;
          // 查找 .apk 文件
          final apkAsset = assets.firstWhere(
              (asset) => asset['name'].toString().endsWith('.apk'),
              orElse: () => null);
          if (apkAsset != null) {
            return apkAsset['browser_download_url'] as String;
          }
        }
        // 如果找不到 APK 下载链接，返回 GitHub release 页面
        return 'https://github.com/VariantConst/Marchkov-Helper/releases/latest';
      } else {
        return 'https://github.com/VariantConst/Marchkov-Helper/releases/latest';
      }
    } catch (e) {
      return null;
    }
  }
}
