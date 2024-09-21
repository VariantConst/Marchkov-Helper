import 'dart:convert';
import '../models/bus_route.dart';
import '../services/auth_service.dart';

class ReservationService {
  final AuthService _authService;

  ReservationService(this._authService);

  Future<bool> login(String username, String password) async {
    try {
      await _authService.login(username, password);
      return true;
    } catch (e) {
      print('登录失败: $e');
      return false;
    }
  }

  Future<List<BusRoute>> fetchBusRoutes(int hallId, String time) async {
    // 确保已登录
    if (!_authService.isLoggedIn) {
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

    final response = await _authService.get(uri);

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
}
