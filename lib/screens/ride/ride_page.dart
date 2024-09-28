import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';
import '../../models/reservation.dart';
import '../../services/reservation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
// 新增导入 RideHistoryService
import '../../services/ride_history_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // 新增导入

class RidePage extends StatefulWidget {
  const RidePage({super.key});

  @override
  RidePageState createState() => RidePageState();
}

class RidePageState extends State<RidePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isToggleLoading = false;

  bool _isGoingToYanyuan = true;

  List<Map<String, dynamic>> _nearbyBuses = [];
  int _selectedBusIndex = -1;

  // 添加预约相关变量

  // 添加 PageController 属性
  late PageController _pageController;

  // 添加一个加载状态变量
  bool _isLoading = true;

  // 添加新的属性
  bool? _showTip;

  // 添加一个新的列表来存储每个卡片的状态
  List<Map<String, dynamic>> _cardStates = [];

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadTipPreference();

    // 初始化 PageController，设置初始页面和视口Fraction
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.9, // 调整视口Fraction，使卡片占据更大的宽度
    );
  }

  @override
  void dispose() {
    // 释放 PageController 资源
    _pageController.dispose();
    super.dispose();
  }

  // 修改 _initialize 方法以并行获取所有班车的数据
  Future<void> _initialize() async {
    await _loadNearbyBuses();

    if (!mounted) return; // 检查组件是否仍然在树中

    if (_nearbyBuses.isNotEmpty) {
      setState(() {
        _selectedBusIndex = 0;
        // 初始化每个卡片的状态
        _cardStates = List.generate(
            _nearbyBuses.length,
            (index) => {
                  'qrCode': null,
                  'departureTime': '',
                  'routeName': '',
                  'codeType': '',
                  'errorMessage': '',
                });
      });
      // 并行获取所有班车的二维码
      await Future.wait([
        for (int i = 0; i < _nearbyBuses.length; i++)
          _fetchBusData(i), // 新增方法，用于获取每个班车的数据
      ]);
    } else {
      setState(() {});
    }

    // 数据加载完成，更新加载状态
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 新增方法，用于并行获取每个班车的数据而不改变选中的班车索引
  Future<void> _fetchBusData(int index) async {
    final bus = _nearbyBuses[index];
    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);
    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));

    try {
      await reservationProvider.loadCurrentReservations();
      Reservation? matchingReservation;

      try {
        matchingReservation =
            reservationProvider.currentReservations.firstWhere(
          (reservation) =>
              reservation.resourceName == bus['route_name'] &&
              reservation.appointmentTime ==
                  '${bus['abscissa']} ${bus['yaxis']}',
        );
      } catch (e) {
        matchingReservation = null; // 如果没有找到匹配的预约，设置为 null
      }

      if (matchingReservation != null) {
        await _fetchQRCode(reservationProvider, matchingReservation, index);
      } else {
        // 仅比较 HH:mm
        final departureTimeStr = bus['yaxis']; // "HH:mm"
        final nowStr = DateFormat('HH:mm').format(DateTime.now());
        final isPastDeparture = departureTimeStr.compareTo(nowStr) <= 0;

        if (isPastDeparture) {
          final tempCode = await _fetchTempCode(reservationService, bus);
          if (tempCode != null) {
            if (mounted) {
              setState(() {
                _cardStates[index] = {
                  'qrCode': tempCode['code'],
                  'departureTime': tempCode['departureTime']!,
                  'routeName': bus['route_name'],
                  'codeType': '临时码',
                  'errorMessage': '',
                };
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _cardStates[index]['errorMessage'] = '无法获取临时码';
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _cardStates[index] = {
                'qrCode': null,
                'departureTime': bus['yaxis'],
                'routeName': bus['route_name'],
                'codeType': '待预约',
                'errorMessage': '',
              };
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cardStates[index]['errorMessage'] = '加载数据时出错: $e';
        });
      }
    }
  }

  Future<void> _loadNearbyBuses() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayString = now.toIso8601String().split('T')[0];

    // 尝试从缓存中读取数据
    final cachedBusDataString = prefs.getString('cachedBusData');
    final cachedDate = prefs.getString('cachedDate');

    if (cachedBusDataString != null && cachedDate == todayString) {
      // 如果有当天的缓存数据，直接使用
      final cachedBusData = json.decode(cachedBusDataString);
      _processBusData(cachedBusData);
    } else {
      // 如果没有缓存或缓存不是当天的，重新获取数据
      if (!mounted) return; // 添加这行来检查组件是否仍然挂载
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final reservationService = ReservationService(authProvider);

      try {
        final allBuses = await reservationService.getAllBuses([todayString]);

        // 缓存新获取的数据
        await prefs.setString('cachedBusData', json.encode(allBuses));
        await prefs.setString('cachedDate', todayString);

        if (!mounted) return; // 再次检查组件是否仍然挂载
        _processBusData(allBuses);
      } catch (e) {
        print('加载附近班车失败: $e');
      }
    }

    // 新增: 获取乘车历史并统计乘坐次数
    if (mounted) {
      // 添加这行来检查组件是否仍然挂载
      await _loadRideHistory();
    }
  }

  void _processBusData(List<dynamic> busData) {
    final now = DateTime.now();
    _nearbyBuses = busData
        .where((bus) {
          final busTime = DateTime.parse('${bus['abscissa']} ${bus['yaxis']}');
          final diff = busTime.difference(now).inMinutes;

          // 添加路线名称过滤条件
          final routeName = bus['route_name'].toString().toLowerCase();
          final containsXin = routeName.contains('新');
          final containsYan = routeName.contains('燕');

          return diff >= -30 && diff <= 30 && containsXin && containsYan;
        })
        .toList()
        .cast<Map<String, dynamic>>();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadRideHistory() async {
    final rideHistoryService =
        RideHistoryService(Provider.of<AuthProvider>(context, listen: false));
    final rideHistory = await rideHistoryService.getRideHistory();

    // 统计每个班车（路线名 + 时间，不含日期）的乘坐次数
    Map<String, int> busUsageCount = {};
    for (var bus in _nearbyBuses) {
      String busKey = '${bus['route_name']}_${bus['yaxis']}'; // 只使用时间，不包含日期
      busUsageCount[busKey] = 0;
    }

    for (var ride in rideHistory) {
      DateTime rideDateTime = DateTime.parse(ride.appointmentTime);
      String rideTime = DateFormat('HH:mm').format(rideDateTime);
      String rideKey = '${ride.resourceName}_$rideTime';
      if (busUsageCount.containsKey(rideKey)) {
        busUsageCount[rideKey] = busUsageCount[rideKey]! + 1;
      }
    }

    // 根据乘坐次数对班车进行排序
    _nearbyBuses.sort((a, b) {
      String keyA = '${a['route_name']}_${a['yaxis']}';
      String keyB = '${b['route_name']}_${b['yaxis']}';
      return busUsageCount[keyB]!.compareTo(busUsageCount[keyA]!);
    });

    // 打印每个班车的乘坐次数
    for (var bus in _nearbyBuses) {
      String busKey = '${bus['route_name']}_${bus['yaxis']}';
      print('班车: $busKey, 乘坐次数: ${busUsageCount[busKey]}');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectBus(int index) async {
    if (!mounted) return; // 检查组件是否仍然在树中

    setState(() {
      _selectedBusIndex = index;
    });

    // 修改以下条件：基于 'codeType' 而不是 'errorMessage'
    if (_cardStates[index]['codeType'] == '乘车码') {
      return; // 如果已经是乘车码，不需要重新获取数据
    }

    final bus = _nearbyBuses[index];
    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);
    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));

    try {
      await reservationProvider.loadCurrentReservations();
      Reservation? matchingReservation;

      try {
        matchingReservation =
            reservationProvider.currentReservations.firstWhere(
          (reservation) =>
              reservation.resourceName == bus['route_name'] &&
              reservation.appointmentTime ==
                  '${bus['abscissa']} ${bus['yaxis']}',
        );
      } catch (e) {
        matchingReservation = null; // 如果没有找到匹配的预约，设置为 null
      }

      if (matchingReservation != null) {
        await _fetchQRCode(reservationProvider, matchingReservation, index);
      } else {
        // 仅比较 HH:mm
        final departureTimeStr = bus['yaxis']; // "HH:mm"
        final nowStr = DateFormat('HH:mm').format(DateTime.now());
        final isPastDeparture = departureTimeStr.compareTo(nowStr) <= 0;

        if (isPastDeparture) {
          final tempCode = await _fetchTempCode(reservationService, bus);
          if (tempCode != null) {
            if (mounted) {
              setState(() {
                _cardStates[index] = {
                  'qrCode': tempCode['code'],
                  'departureTime': tempCode['departureTime']!,
                  'routeName': bus['route_name'],
                  'codeType': '临时码',
                  'errorMessage': '',
                };
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _cardStates[index]['errorMessage'] = '无法获取临时码';
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _cardStates[index] = {
                'qrCode': null,
                'departureTime': bus['yaxis'],
                'routeName': bus['route_name'],
                'codeType': '待预约',
                'errorMessage': '',
              };
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cardStates[index]['errorMessage'] = '加载数据时出错: $e';
        });
      }
    }
  }

  Future<void> _fetchQRCode(
      ReservationProvider provider, Reservation reservation, int index) async {
    try {
      await provider.fetchQRCode(
        reservation.id.toString(),
        reservation.hallAppointmentDataId.toString(),
      );

      final actualDepartureTime = await _getActualDepartureTime(reservation);

      if (mounted) {
        setState(() {
          _cardStates[index] = {
            'qrCode': provider.qrCode,
            'departureTime': actualDepartureTime,
            'routeName': reservation.resourceName,
            'codeType': '乘车码',
            'appointmentId': reservation.id.toString(),
            'hallAppointmentDataId':
                reservation.hallAppointmentDataId.toString(),
            'errorMessage': '',
          };
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cardStates[index]['errorMessage'] = '获取二维码时出错: $e';
        });
      }
    }
  }

  Future<String> _getActualDepartureTime(Reservation reservation) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedBusDataString = prefs.getString('cachedBusData');
    if (cachedBusDataString != null) {
      final buses = jsonDecode(cachedBusDataString);
      final matchingBus = buses.firstWhere(
        (bus) =>
            bus['route_name'] == reservation.resourceName &&
            '${bus['abscissa']} ${bus['yaxis']}' == reservation.appointmentTime,
        orElse: () => null,
      );
      if (matchingBus != null) {
        return matchingBus['yaxis'];
      }
    }
    return reservation.appointmentTime.split(' ')[1];
  }

  Future<Map<String, String>?> _fetchTempCode(
      ReservationService service, Map<String, dynamic> bus) async {
    final resourceId = bus['bus_id'].toString();
    final startTime = '${bus['abscissa']} ${bus['yaxis']}';
    final code = await service.getTempQRCode(resourceId, startTime);
    return {
      'code': code,
      'departureTime': bus['yaxis'],
      'routeName': bus['route_name'],
    };
  }

  // 添加新的方法
  Future<void> _loadTipPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showTip = prefs.getBool('showRideTip') ?? true;
    });
  }

  Future<void> _saveTipPreference(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRideTip', show);
  }

  void _showTipDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('乘车提示'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 本页面只会显示过去30分钟到未来30分钟内发车的班车。'),
            Text('2. 如果已错过发车时刻，将无法预约，只会显示乘车码或临时码。'),
            Text('3. 应用会学习您的乘车偏好，根据历史乘车记录智能推荐班车。目前需要您手动打开设置-乘车历史，以缓存乘车记录。'),
            Text('4. 如果加载太慢，尝试关闭代理。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showTip = false;
              });
              _saveTipPreference(false);
            },
            child: Text('不再显示'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(int index) async {
    final cardState = _cardStates[index];
    if (cardState['appointmentId'] == null ||
        cardState['hallAppointmentDataId'] == null) {
      setState(() {
        cardState['errorMessage'] = '无有效的预约信息';
      });
      return;
    }

    setState(() {
      _isToggleLoading = true;
      cardState['errorMessage'] = '';
    });

    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));

    try {
      await reservationService.cancelReservation(
        cardState['appointmentId'],
        cardState['hallAppointmentDataId'],
      );

      // 仅比较 HH:mm
      final bus = _nearbyBuses[index];
      final departureTimeStr = bus['yaxis']; // "HH:mm"
      final nowStr = DateFormat('HH:mm').format(DateTime.now());
      final isPastDeparture = departureTimeStr.compareTo(nowStr) <= 0;

      if (isPastDeparture) {
        final tempCode = await _fetchTempCode(reservationService, bus);
        if (tempCode != null) {
          if (mounted) {
            setState(() {
              _cardStates[index] = {
                'qrCode': tempCode['code'],
                'departureTime': tempCode['departureTime']!,
                'routeName': bus['route_name'],
                'codeType': '临时码',
                'errorMessage': '',
              };
            });
          }
        } else {
          if (mounted) {
            setState(() {
              cardState['errorMessage'] = '无法获取临时码';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _cardStates[index] = {
              'qrCode': null,
              'departureTime': bus['yaxis'],
              'routeName': bus['route_name'],
              'codeType': '待预约',
              'errorMessage': '',
            };
          });
        }
      }
    } catch (e) {
      setState(() {
        cardState['errorMessage'] = '取消预约失败: $e';
      });
    } finally {
      setState(() {
        _isToggleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final secondaryColor = theme.colorScheme.secondary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 16), // 顶部间距
              if (_showTip == true)
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: _showTipDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        SizedBox(width: 8),
                        Text(
                          '查看乘车提示',
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.titleMedium?.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(
                height: 600,
                child: _nearbyBuses.isEmpty
                    ? Center(child: Text('无车可坐'))
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: _nearbyBuses.length,
                        onPageChanged: (index) {
                          _selectBus(index);
                        },
                        itemBuilder: (context, index) {
                          return _buildCard(index);
                        },
                      ),
              ),
              SizedBox(height: 16),
              // 底部指示槽
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _nearbyBuses.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedBusIndex == index
                            ? primaryColor
                            : secondaryColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(int index) {
    final cardState = _cardStates[index];
    final isNoBusAvailable = cardState['errorMessage'] ==
        '这会去${_isGoingToYanyuan ? '燕园' : '昌平'}没有班车可坐😅';

    // 仅比较 HH:mm
    final departureTimeStr = cardState['departureTime']; // "HH:mm"
    final nowStr = DateFormat('HH:mm').format(DateTime.now());
    final isPastDeparture = departureTimeStr.compareTo(nowStr) <= 0;

    Color textColor;
    Color borderColor;
    Color buttonColor;
    Color backgroundColor;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (isNoBusAvailable) {
      textColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
      borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
      buttonColor = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;
      backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.grey[100]!;
    } else if (cardState['codeType'] == '临时码') {
      textColor = theme.colorScheme.secondary;
      borderColor = theme.colorScheme.secondary.withOpacity(0.3);
      buttonColor = theme.colorScheme.secondary.withOpacity(0.1);
      backgroundColor = theme.colorScheme.secondary.withOpacity(0.05);
    } else {
      textColor = theme.colorScheme.primary;
      borderColor = theme.colorScheme.primary.withOpacity(0.3);
      buttonColor = theme.colorScheme.primary.withOpacity(0.1);
      backgroundColor = theme.colorScheme.primary.withOpacity(0.05);
    }

    return Card(
      elevation: 6,
      margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(isNoBusAvailable, cardState['codeType']),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isNoBusAvailable)
                    Column(
                      children: [
                        Text('😅', style: TextStyle(fontSize: 80)),
                        SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '去'),
                              TextSpan(
                                text: _isGoingToYanyuan ? '燕园' : '昌平',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: '方向'),
                            ],
                          ),
                          style: TextStyle(fontSize: 24, color: textColor),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '这会没有班车可坐，急了？',
                          style: TextStyle(fontSize: 14, color: textColor),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '只有过去30分钟到未来30分钟内\n发车的班车乘车码才会在这里显示。',
                          style: TextStyle(fontSize: 12, color: textColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          height: 50,
                          child: Center(
                            child: Text(
                              cardState['routeName'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          cardState['departureTime'],
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 20),
                        if (cardState['codeType'] == '乘车码' ||
                            cardState['codeType'] == '临时码')
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode ? Colors.grey[400]! : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            child: Center(
                              child: cardState['qrCode'] != null
                                  ? QrImageView(
                                      data: cardState['qrCode'],
                                      version: 13,
                                      size: 200.0,
                                      padding: EdgeInsets.zero,
                                      backgroundColor: isDarkMode
                                          ? Colors.grey[400]!
                                          : Colors.white,
                                      eyeStyle: QrEyeStyle(
                                        color: isDarkMode
                                            ? Colors.black
                                            : Colors.grey[700]!,
                                        eyeShape: QrEyeShape.square,
                                      ),
                                      dataModuleStyle: QrDataModuleStyle(
                                        color: isDarkMode
                                            ? Colors.black
                                            : Colors.grey[700]!,
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                      ),
                                      errorCorrectionLevel:
                                          QrErrorCorrectLevel.M,
                                    )
                                  : Text('无效的二维码'),
                            ),
                          )
                        else if (cardState['codeType'] == '待预约')
                          Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '待预约',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  SizedBox(height: 20),
                  // 仅当发车时间 > 当前时间时显示按钮
                  if (!isPastDeparture)
                    _buildReverseButton(buttonColor, textColor, index),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(bool isNoBusAvailable, String codeType) {
    Color startColor;
    Color endColor;
    Color textColor;
    String headerText;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (isNoBusAvailable) {
      startColor = isDarkMode ? Colors.grey[800]! : Colors.grey[200]!;
      endColor = isDarkMode ? Colors.grey[900]! : Colors.grey[100]!;
      textColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;
      headerText = '无车可坐';
    } else {
      if (codeType == '乘车码') {
        startColor = theme.colorScheme.primary.withOpacity(0.2);
        endColor = theme.colorScheme.primary.withOpacity(0.05);
        textColor = theme.colorScheme.primary;
        headerText = '乘车码';
      } else if (codeType == '临时码') {
        startColor = theme.colorScheme.secondary.withOpacity(0.2);
        endColor = theme.colorScheme.secondary.withOpacity(0.05);
        textColor = theme.colorScheme.secondary;
        headerText = '临时码';
      } else {
        // '待预约'
        startColor = theme.colorScheme.tertiary.withOpacity(0.2);
        endColor = theme.colorScheme.tertiary.withOpacity(0.05);
        textColor = theme.colorScheme.tertiary;
        headerText = '待预约';
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text(
          headerText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildReverseButton(Color buttonColor, Color textColor, int index) {
    final cardState = _cardStates[index];
    final isReservation = cardState['codeType'] == '乘车码';

    return SizedBox(
      width: 240,
      height: 56,
      child: ElevatedButton(
        onPressed: _isToggleLoading
            ? null
            : () {
                // 添加震动反馈
                HapticFeedback.lightImpact();
                if (isReservation) {
                  _cancelReservation(index);
                } else {
                  _makeReservation(index);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isToggleLoading ? Colors.grey.shade200 : buttonColor,
          foregroundColor: _isToggleLoading ? Colors.grey : textColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isToggleLoading
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                ),
              )
            : Text(
                isReservation ? '取消预约' : '预约',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _makeReservation(int index) async {
    setState(() {
      _isToggleLoading = true;
      _cardStates[index]['errorMessage'] = '';
    });

    final bus = _nearbyBuses[index];
    final reservationService =
        ReservationService(Provider.of<AuthProvider>(context, listen: false));
    final reservationProvider =
        Provider.of<ReservationProvider>(context, listen: false);

    try {
      await reservationService.makeReservation(
        bus['bus_id'].toString(),
        bus['abscissa'],
        bus['time_id'].toString(),
      );

      // 获取最新的预约列表
      await reservationProvider.loadCurrentReservations();

      // 尝试匹配刚刚预约的班车
      Reservation? matchingReservation;
      try {
        matchingReservation =
            reservationProvider.currentReservations.firstWhere(
          (reservation) =>
              reservation.resourceName == bus['route_name'] &&
              reservation.appointmentTime ==
                  '${bus['abscissa']} ${bus['yaxis']}',
        );
      } catch (e) {
        matchingReservation = null;
      }

      if (matchingReservation != null) {
        // 获取乘车码
        await _fetchQRCode(reservationProvider, matchingReservation, index);
      } else {
        setState(() {
          _cardStates[index]['errorMessage'] = '无法找到匹配的预约信息';
        });
      }
    } catch (e) {
      setState(() {
        _cardStates[index]['errorMessage'] = '预约失败: $e';
      });
    } finally {
      setState(() {
        _isToggleLoading = false;
      });
    }
  }
}
