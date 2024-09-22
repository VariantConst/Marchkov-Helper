import 'dart:convert';
import '../models/bus_route.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';

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
        return list
            .map((json) => BusRoute(id: json['id'], name: json['name']))
            .toList();
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

  Future<List<dynamic>> getAllBuses(List<String> dateStrings) async {
    // 创建一个 Future 列表，每个 Future 都是一个 fetchReservationData 调用
    List<Future<String>> futures = dateStrings.map((dateString) {
      return fetchReservationData(dateString);
    }).toList();

    // 并行等待所有请求完成
    List<String> responses = await Future.wait(futures);

    List<dynamic> allBuses = [];

    // 添加一个 Set 用于去重
    Set<String> busSet = {};

    // 遍历所有的响应结果
    for (var response in responses) {
      final data = json.decode(response);

      if (data['e'] == 0) {
        List<dynamic> list = data['d']['list'];

        for (var bus in list) {
          var busId = bus['id'];
          var table = bus['table'];
          for (var key in table.keys) {
            var timeSlots = table[key];
            for (var slot in timeSlots) {
              if (slot['row']['margin'] > 0) {
                // 解析并格式化日期和时间
                String dateStr = slot['abscissa'].trim(); // 去除空格
                String timeStr = slot['yaxis'].trim(); // 去除空格

                // 将日期和时间合并
                DateTime dateTime = DateTime.parse('$dateStr $timeStr');

                // 格式化日期和时间
                String normalizedDate =
                    DateFormat('yyyy-MM-dd').format(dateTime);
                String normalizedTime = DateFormat('HH:mm').format(dateTime);

                // 获取 time_id
                String timeId = slot['time_id'].toString();

                // 构建更加唯一的标识符，包括 busId 和 timeId
                String uniqueKey =
                    '${normalizedDate}_${normalizedTime}_${busId}_$timeId';

                // 如果未出现过，则添加至列表
                if (busSet.add(uniqueKey)) {
                  Map<String, dynamic> busInfo = {
                    'route_name': bus['name'],
                    'bus_id': busId,
                    'abscissa': normalizedDate,
                    'yaxis': normalizedTime,
                    'row': slot['row'],
                    'time_id': slot['time_id'],
                    'status': slot['row']['status'],
                  };

                  allBuses.add(busInfo);
                }
              }
            }
          }
        }
      } else {
        throw Exception(data['m']);
      }
    }

    return allBuses;
  }

  Future<void> makeReservation(
      String resourceId, String date, String period) async {
    if (!_authProvider.isLoggedIn) {
      throw Exception('未登录，请先登录');
    }

    final uri = Uri.parse('https://wproc.pku.edu.cn/site/reservation/launch');
    final response = await http.post(
      // 修改为 http.post
      uri,
      headers: {
        'Cookie': _authProvider.cookies,
      },
      body: {
        'resource_id': resourceId,
        'data': '[{"date": "$date", "period": $period, "sub_resource_id": 0}]',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['m'] == '操作成功') {
        // 预约成功
        return;
      } else {
        throw Exception(data['m']);
      }
    } else {
      throw Exception('请求失败，状态码: ${response.statusCode}');
    }
  }

  // 添加获取用户预约列表的方法
  Future<List<dynamic>> fetchMyReservations() async {
    final uri = Uri.parse(
      'https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=0&status=2&sort_time=true&sort=asc',
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
        return data['d']['data'];
      } else {
        throw Exception(data['m']);
      }
    } else {
      throw Exception('请求失败，状态码: ${response.statusCode}');
    }
  }

  // 添加获取二维码的方法
  Future<String> getReservationQRCode(
      String id, String hallAppointmentDataId) async {
    final uri = Uri.parse(
      'https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?id=$id&type=0&hall_appointment_data_id=$hallAppointmentDataId',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Cookie': _authProvider.cookies,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['e'] == 0) {
          return data['d']['code'];
        } else {
          throw Exception(data['m']);
        }
      } else {
        throw Exception('请求失败，状态码: ${response.statusCode}');
      }
    } catch (e) {
      print('获取二维码时出错: $e');
      rethrow;
    }
  }

  Future<String> getTempQRCode(String resourceId, String startTime) async {
    final uri = Uri.parse(
      'https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id=$resourceId&text=$startTime',
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
        return data['d']['code'];
      } else {
        throw Exception(data['m']);
      }
    } else {
      throw Exception('请求失败，状态码: ${response.statusCode}');
    }
  }

  Future<void> cancelReservation(
      String appointmentId, String hallAppointmentDataId) async {
    if (!_authProvider.isLoggedIn) {
      throw Exception('未登录，请先登录');
    }

    final uri = Uri.parse(
        'https://wproc.pku.edu.cn/site/reservation/single-time-cancel');
    final response = await http.post(
      uri,
      headers: {
        'Cookie': _authProvider.cookies,
      },
      body: {
        'appointment_id': appointmentId,
        'data_id[0]': hallAppointmentDataId, // 移除了反斜杠
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['m'] == '操作成功') {
        // 取消预约成功
        return;
      } else {
        throw Exception(data['m']);
      }
    } else {
      throw Exception('请求失败，状态码: ${response.statusCode}');
    }
  }
}
