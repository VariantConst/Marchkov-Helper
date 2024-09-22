import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride_info.dart';
import '../providers/auth_provider.dart';

class RideHistoryService {
  final AuthProvider _authProvider;

  RideHistoryService(this._authProvider);

  Future<List<RideInfo>> getRideHistory() async {
    // 检查用户是否已登录
    if (!_authProvider.isLoggedIn) {
      throw Exception('未找到用户凭证');
    }

    // 获取缓存的乘车历史
    final cachedHistory = await _getCachedRideHistory();
    final lastFetchDate =
        cachedHistory?.lastFetchDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    final cachedRides = cachedHistory?.rides ?? [];

    // 计算需要获取的日期范围，使用北京时间
    final dateFormat = DateFormat('yyyy-MM-dd');
    final today = DateTime.now();
    final startDate = lastFetchDate.subtract(Duration(days: 1));
    final endDate = today;

    // 构建URL，只请求 status=4 和 status=5 的信息
    final dateStringStart = dateFormat.format(startDate);
    final dateStringEnd = dateFormat.format(endDate);
    final urlStrings = [
      'https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=0&status=4&sort_time=true&sort=desc&date_sta=$dateStringStart&date_end=$dateStringEnd',
      'https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=0&status=5&sort_time=true&sort=desc&date_sta=$dateStringStart&date_end=$dateStringEnd',
    ];

    // 发起请求获取新的乘车历史
    List<RideInfo> allNewRides = [];
    for (String url in urlStrings) {
      final rides = await _fetchRideHistory(url);
      allNewRides.addAll(rides);
    }

    // 合并新旧数据
    final mergedRides = _mergeRides(cachedRides, allNewRides, lastFetchDate);

    // 更新缓存
    await _updateCachedRideHistory(mergedRides, today);

    return mergedRides;
  }

  Future<List<RideInfo>> _fetchRideHistory(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Cookie': _authProvider.cookies,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['e'] == 0) {
        List<dynamic> rideData = data['d']['data'];
        return rideData.map((ride) {
          return RideInfo.fromJson(ride);
        }).toList();
      } else {
        throw Exception(data['m']);
      }
    } else {
      throw Exception('请求失败, 状态码: ${response.statusCode}');
    }
  }

  Future<CachedRideHistory?> _getCachedRideHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cachedRideHistory');
    if (data != null) {
      return CachedRideHistory.fromJson(json.decode(data));
    }
    return null;
  }

  Future<void> _updateCachedRideHistory(
      List<RideInfo> rides, DateTime lastFetchDate) async {
    final cachedHistory =
        CachedRideHistory(lastFetchDate: lastFetchDate, rides: rides);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'cachedRideHistory', json.encode(cachedHistory.toJson()));
  }

  List<RideInfo> _mergeRides(List<RideInfo> cachedRides,
      List<RideInfo> newRides, DateTime lastFetchDate) {
    // 过滤掉缓存中最后一次请求日期及之后的记录
    final filteredCachedRides = cachedRides.where((ride) {
      final rideDate = DateTime.parse(ride.appointmentTime);
      return rideDate.isBefore(lastFetchDate);
    }).toList();

    // 创建一个 Map 以便合并
    final Map<int, RideInfo> mergedRidesMap = {
      for (var ride in filteredCachedRides) ride.id: ride
    };

    for (var newRide in newRides) {
      mergedRidesMap[newRide.id] = newRide;
    }

    // 将 Map 转换为 List 并按预约时间降序排序
    final mergedRides = mergedRidesMap.values.toList();
    mergedRides.sort((a, b) => b.appointmentTime.compareTo(a.appointmentTime));

    return mergedRides;
  }
}
