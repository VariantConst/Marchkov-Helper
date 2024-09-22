import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';

class UserService {
  final AuthProvider authProvider;

  UserService(this.authProvider);

  Future<Map<String, String>> fetchUserInfo() async {
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
        return {
          'name': userInfo[0],
          'studentId': userInfo[1],
          'college': userInfo[2],
        };
      }
    }
    throw Exception('获取用户信息失败');
  }
}
