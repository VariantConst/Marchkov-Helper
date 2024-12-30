import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/ride_info.dart';
import 'summary_violation_pie_chart.dart';
import 'summary_monthly_bar_chart.dart';

class AnnualSummaryCard extends StatefulWidget {
  final List<RideInfo> rides;

  const AnnualSummaryCard({
    Key? key,
    required this.rides,
  }) : super(key: key);

  @override
  State<AnnualSummaryCard> createState() => _AnnualSummaryCardState();
}

class _AnnualSummaryCardState extends State<AnnualSummaryCard> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSaving = false;
  final Map<int, int> monthCount = {};
  late int maxMonthCount = 0;

  @override
  void initState() {
    super.initState();
    final summary = _calculateSummary();
    if (summary.isNotEmpty) {
      maxMonthCount = monthCount.values.reduce((a, b) => a > b ? a : b);
    }
  }

  Future<void> _saveAndShare() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // 等待下一帧完成渲染
      await Future.delayed(Duration(milliseconds: 500));

      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取渲染边界');

      // 等待图表动画完成
      await Future.delayed(Duration(milliseconds: 500));

      // 确保所有图片都已加载完成
      await precacheImage(boundary);

      final image = await boundary.toImage(pixelRatio: 2.0); // 降低一点分辨率，避免内存问题
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据');

      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/annual_summary_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(imagePath)],
        text: '我的${_getSummaryYear()}年班车总结',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // 添加这个辅助方法来预缓存图片
  Future<void> precacheImage(RenderRepaintBoundary boundary) async {
    final imageSize = boundary.size;
    final constraints = BoxConstraints(
      maxWidth: imageSize.width,
      maxHeight: imageSize.height,
    );

    // 强制完成所有渲染
    await Future.delayed(Duration(milliseconds: 200));
    WidgetsBinding.instance.platformDispatcher.scheduleFrame();
    await Future.delayed(Duration(milliseconds: 200));
  }

  int _getSummaryYear() {
    final now = DateTime.now();
    // 如果是12月或1月，显示即将过去或刚过去的年份
    if (now.month == 12) {
      return now.year;
    } else if (now.month == 1) {
      return now.year - 1;
    }
    return -1; // 其他月份返回-1，表示不显示年度总结
  }

  List<RideInfo> _filterRidesByYear(int year) {
    return widget.rides.where((ride) {
      final rideDate = DateTime.parse(ride.appointmentTime);
      return rideDate.year == year;
    }).toList();
  }

  Map<String, dynamic> _calculateSummary() {
    final summaryYear = _getSummaryYear();
    if (summaryYear == -1 || widget.rides.isEmpty) return {};

    final yearRides = _filterRidesByYear(summaryYear);
    if (yearRides.isEmpty) return {};

    // 总预约和违约
    int totalRides = yearRides.length;
    int violationCount =
        yearRides.where((ride) => ride.statusName == '已预约').length;

    // 按月份统计
    Map<int, int> hourCount = {};
    Map<String, int> morningBusCount = {}; // 统计12点前的班车
    Map<String, int> nightBusCount = {}; // 统计晚间班车

    Map<int, Map<String, int>> hourRouteCount = {};

    for (var ride in yearRides) {
      DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
      int month = appointmentTime.month;
      int hour = appointmentTime.hour;
      String routeName = ride.resourceName;

      monthCount[month] = (monthCount[month] ?? 0) + 1;
      hourCount[hour] = (hourCount[hour] ?? 0) + 1;

      // 统计12点前的班车
      if (hour < 12) {
        String busTime = '${hour.toString().padLeft(2, '0')}:00';
        morningBusCount[busTime] = (morningBusCount[busTime] ?? 0) + 1;
      }

      // 统计晚间班车 (17:30-23:00)
      if (hour >= 17 && hour <= 23) {
        String busTime = '${hour.toString().padLeft(2, '0')}:00';
        nightBusCount[busTime] = (nightBusCount[busTime] ?? 0) + 1;
      }

      // 统计每个小时的路线
      hourRouteCount.putIfAbsent(hour, () => {});
      hourRouteCount[hour]![routeName] =
          (hourRouteCount[hour]![routeName] ?? 0) + 1;
    }

    // 找出最多乘车的月份
    int? mostFrequentMonth;
    int maxMonthCount = 0;
    monthCount.forEach((month, count) {
      if (count > maxMonthCount) {
        maxMonthCount = count;
        mostFrequentMonth = month;
      }
    });

    // 找出最常乘坐的时段和路线
    int? mostFrequentHour;
    int maxHourCount = 0;
    String? mostFrequentRoute;
    hourCount.forEach((hour, count) {
      if (count > maxHourCount) {
        maxHourCount = count;
        mostFrequentHour = hour;
        mostFrequentRoute = hourRouteCount[hour]!
            .entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }
    });

    // 找出最常乘坐的早班车
    String? mostFrequentMorningBus;
    int maxMorningCount = 0;
    morningBusCount.forEach((time, count) {
      if (count > maxMorningCount) {
        maxMorningCount = count;
        mostFrequentMorningBus = time;
      }
    });

    // 找出最常乘坐的晚班车
    String? mostFrequentNightBus;
    int maxNightCount = 0;
    nightBusCount.forEach((time, count) {
      if (count > maxNightCount) {
        maxNightCount = count;
        mostFrequentNightBus = time;
      }
    });

    return {
      'year': _getSummaryYear(),
      'totalRides': totalRides,
      'violationCount': violationCount,
      'violationRate': totalRides > 0 ? (violationCount / totalRides * 100) : 0,
      'mostFrequentMonth': mostFrequentMonth,
      'mostFrequentMonthCount': maxMonthCount,
      'mostFrequentHour': mostFrequentHour,
      'mostFrequentHourCount': maxHourCount,
      'mostFrequentRoute': mostFrequentRoute,
      'mostFrequentMorningBus': mostFrequentMorningBus,
      'mostFrequentMorningBusCount': maxMorningCount,
      'mostFrequentNightBus': mostFrequentNightBus,
      'mostFrequentNightBusCount': maxNightCount,
    };
  }

  Widget _buildStoryText(BuildContext context, String text,
      {bool highlight = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: highlight ? 20 : 16,
            height: 1.6,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: theme.colorScheme.onSurface,
          ),
          children: text
              .split('**')
              .asMap()
              .map((index, segment) {
                return MapEntry(
                  index,
                  TextSpan(
                    text: segment,
                    style: TextStyle(
                      fontSize: index % 2 == 1 ? 24 : (highlight ? 20 : 16),
                      color: index % 2 == 1
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: index % 2 == 1
                          ? FontWeight.bold
                          : (highlight ? FontWeight.bold : FontWeight.normal),
                      height: 1.6,
                    ),
                  ),
                );
              })
              .values
              .toList(),
        ),
      ),
    );
  }

  String _getMorningBusComment(String busTime, int count) {
    int hour = int.parse(busTime.split(':')[0]);

    if (hour < 7) {
      return '你最常选择的是 **$busTime** 的早班车，是个起得特别早的早起鸟呢，继续保持这个好习惯吧！';
    } else if (hour < 9) {
      return '你最常选择的是 **$busTime** 的班车，作息很规律呢，继续保持健康的生活节奏吧！';
    } else {
      return '你最常选择的是 **$busTime** 的班车，看来你很享受睡到自然醒呢，这是在提前适应大厂作息吗？😉';
    }
  }

  String _getNightBusComment(String busTime, int count) {
    int hour = int.parse(busTime.split(':')[0]);

    if (hour < 21) {
      return '晚上你最常选择的是 **$busTime** 的班车，看来你很注重工作与生活的平衡呢！';
    } else {
      return '晚上你最常选择的是 **$busTime** 的班车，是个努力的夜猫子呢，要记得注意休息哦！';
    }
  }

  String _getViolationComment(int violationCount, double violationRate) {
    String baseText =
        '其中有 **$violationCount** 次未能按时签到，违约率为 **${violationRate.toStringAsFixed(1)}%**';

    if (violationRate == 0) {
      return '$baseText，你太靠谱了，从不爽约！';
    } else if (violationRate <= 5) {
      return '$baseText，偶尔也会有意外发生，但你的守时表现依然很棒！';
    } else if (violationRate <= 15) {
      return '$baseText，还需要继续努力，相信明年一定会更好！';
    } else {
      return '$baseText，这个违约率有点高哦，建议提前5分钟到达候车点～';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryYear = _getSummaryYear();
    if (summaryYear == -1) {
      return SizedBox.shrink();
    }

    final summary = _calculateSummary();
    if (summary.isEmpty) {
      return Center(
        child: Text(
          '$summaryYear 年暂无乘车数据',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 16,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // 实际显示的可滚动内容
        SingleChildScrollView(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              width: screenWidth, // 固定宽度
              color: theme.scaffoldBackgroundColor,
              padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${summary['year']} 班车年度总结',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '恭喜你完成了一年的牛马通勤之旅！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 32),
                  _buildStoryText(
                    context,
                    '在这一年里，你一共乘坐了 **${summary['totalRides']}** 次班车',
                    highlight: true,
                  ),
                  if (summary['violationCount'] > 0) ...[
                    Divider(height: 32),
                    _buildStoryText(
                      context,
                      _getViolationComment(
                        summary['violationCount'],
                        summary['violationRate'],
                      ),
                    ),
                    SizedBox(height: 16),
                    SummaryViolationPieChart(
                      totalRides: summary['totalRides'],
                      violationCount: summary['violationCount'],
                    ),
                  ],
                  if (summary['mostFrequentMonth'] != null) ...[
                    Divider(height: 32),
                    _buildStoryText(
                      context,
                      '你在 **${summary['mostFrequentMonth']}月** 最为勤奋，乘坐了 **${summary['mostFrequentMonthCount']}** 次班车',
                      highlight: true,
                    ),
                    SizedBox(height: 16),
                    SummaryMonthlyBarChart(
                      monthlyRides: Map.fromEntries(
                        monthCount.entries.map((e) => MapEntry(e.key, e.value)),
                      ),
                      maxCount: maxMonthCount,
                    ),
                  ],
                  if (summary['mostFrequentHour'] != null &&
                      summary['mostFrequentRoute'] != null) ...[
                    Divider(height: 32),
                    _buildStoryText(
                      context,
                      '你乘坐最多的是 **${summary['mostFrequentHour'].toString().padLeft(2, '0')}:00** 的 **${summary['mostFrequentRoute']}** 班车',
                      highlight: true,
                    ),
                  ],
                  if (summary['mostFrequentMorningBus'] != null) ...[
                    SizedBox(height: 24),
                    _buildStoryText(
                      context,
                      _getMorningBusComment(
                        summary['mostFrequentMorningBus'],
                        summary['mostFrequentMorningBusCount'],
                      ),
                    ),
                  ],
                  if (summary['mostFrequentNightBus'] != null) ...[
                    SizedBox(height: 24),
                    _buildStoryText(
                      context,
                      _getNightBusComment(
                        summary['mostFrequentNightBus'],
                        summary['mostFrequentNightBusCount'],
                      ),
                    ),
                  ],
                  SizedBox(height: 48),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _saveAndShare,
                    icon: _isSaving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.share),
                    label: Text(_isSaving ? '正在生成...' : '保存并分享年度总结'),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // 生成图片时的加载指示器
        if (_isSaving)
          Positioned.fill(
            child: Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在生成年度总结...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
