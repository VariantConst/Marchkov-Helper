import 'dart:convert';
import '../models/bus_route.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

class ReservationService {
  final AuthProvider _authProvider;

  ReservationService(this._authProvider);

  Future<bool> login(String username, String password) async {
    try {
      await _authProvider.login(username, password);
      return true;
    } catch (e) {
      print('登录失败: $e');
      return false;
    }
  }

  Future<List<BusRoute>> fetchBusRoutes(int hallId, String time) async {
    // 确保已登录
    if (!_authProvider.isLoggedIn) {
      throw Exception('未登录,请先登录');
    }

    final uri = Uri.parse('https://wproc.pku.edu.cn/site/reservation/list-page')
        .replace(
      queryParameters: {
        'hall_id': hallId.toString(),
        'time': time,
        'p': '1',
        'page_size': '0',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Cookie': _authProvider.cookies,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['e'] == 0) {
        List<dynamic> list = data['d']['list'];
        return list.map((json) => BusRoute.fromJson(json)).toList();
      } else {
        throw Exception(data['m']);
      }
    } else {
      throw Exception('请求失败，状态码: ${response.statusCode}');
    }
  }

  Future<String> fetchReservationData(String date) async {
    final cookies = _authProvider.cookies;
    final url = Uri.parse(
        'https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=$date&p=1&page_size=0');

    final response = await http.get(
      url,
      headers: {
        'Cookie': cookies,
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('请求失败: ${response.statusCode}');
    }
  }
}
