import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

class VersionService {
  Future<String> getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<String?> getLatestVersion() async {
    try {
      final response = await http
          .get(Uri.parse('https://shuttle.variantconst.com/api/version'));
      if (response.statusCode == 200) {
        return response.body.trim();
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
        final response = await http
            .get(Uri.parse('https://shuttle.variantconst.com/api/ios_url'));
        if (response.statusCode == 200) {
          return response.body.trim();
        } else {
          throw Exception('无法获取 iOS 更新链接');
        }
      } else if (Platform.isAndroid) {
        final response = await http
            .get(Uri.parse('https://shuttle.variantconst.com/api/android_url'));
        if (response.statusCode == 200) {
          return response.body.trim();
        } else {
          throw Exception('无法获取 Android 更新链接');
        }
      } else {
        return 'https://shuttle.variantconst.com';
      }
    } catch (e) {
      return null;
    }
  }
}
