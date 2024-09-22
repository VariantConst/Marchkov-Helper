import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

class UserService {
  final AuthProvider authProvider;

  UserService(this.authProvider);

  Future<Map<String, String>> fetchUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name');
    final studentId = prefs.getString('studentId');
    final college = prefs.getString('college');

    if (name != null && studentId != null && college != null) {
      return {
        'name': name,
        'studentId': studentId,
        'college': college,
      };
    }

    // 如果本地没有数据，则从网络获取
    final cookies = await authProvider.getLatestCookies();
    final response = await http.get(
      Uri.parse(
          'https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id=7&text=22:00'),
      headers: {
        'Cookie': cookies,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['e'] == 0) {
        final userInfo = data['d']['name'].split('\r\n');
        // 显式指定 result 的类型
        final Map<String, String> result = {
          'name': userInfo[0],
          'studentId': userInfo[1],
          'college': userInfo[2],
        };

        // 保存到本地
        await prefs.setString('name', result['name']!);
        await prefs.setString('studentId', result['studentId']!);
        await prefs.setString('college', result['college']!);

        return result;
      }
    }
    throw Exception('获取用户信息失败');
  }
}
