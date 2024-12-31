import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../models/ride_info.dart';
import 'summary_violation_pie_chart.dart';
import 'summary_monthly_bar_chart.dart';
import 'random_percentage_widget.dart';
import 'summary_text_builder.dart';

class AnnualSummaryCard extends StatefulWidget {
  final List<RideInfo> rides;

  const AnnualSummaryCard({
    super.key,
    required this.rides,
  });

  @override
  State<AnnualSummaryCard> createState() => _AnnualSummaryCardState();
}

class _AnnualSummaryCardState extends State<AnnualSummaryCard> {
  final GlobalKey _boundaryKey = GlobalKey();
  final GlobalKey<RandomPercentageWidgetState> _randomPercentageKey =
      GlobalKey();
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
      final summary = _calculateSummary();
      if (summary.isEmpty) {
        throw Exception('无法生成年度总结数据');
      }

      final randomPercentageState = _randomPercentageKey.currentState;
      if (randomPercentageState != null &&
          randomPercentageState.randomPercentage == null) {
        randomPercentageState.generateRandomPercentage();
      }

      await Future.delayed(Duration(milliseconds: 500));

      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取渲染边界');

      await Future.delayed(Duration(milliseconds: 500));
      await precacheImage(boundary);

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据');

      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/annual_summary_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(imagePath)],
        text: SummaryTextBuilder.getShareText(
            summary, _randomPercentageKey.currentState?.randomPercentage ?? 0),
        subject: '我的${summary['year']}年班车总结',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> precacheImage(RenderRepaintBoundary boundary) async {
    await Future.delayed(Duration(milliseconds: 200));
    WidgetsBinding.instance.platformDispatcher.scheduleFrame();
    await Future.delayed(Duration(milliseconds: 200));
  }

  int _getSummaryYear() {
    final now = DateTime.now();
    if (now.month == 12) {
      return now.year;
    } else if (now.month == 1) {
      return now.year - 1;
    }
    return -1;
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

    monthCount.clear();

    int totalRides = yearRides.length;
    int violationCount =
        yearRides.where((ride) => ride.statusName == '已预约').length;

    Map<String, int> timeCount = {};
    Map<String, int> morningBusCount = {};
    Map<String, int> nightBusCount = {};
    Map<String, Map<String, int>> timeRouteCount = {};

    for (var ride in yearRides) {
      DateTime appointmentTime = DateTime.parse(ride.appointmentTime);
      int month = appointmentTime.month;
      String timeSlot =
          '${appointmentTime.hour.toString().padLeft(2, '0')}:${appointmentTime.minute.toString().padLeft(2, '0')}';
      String routeName = ride.resourceName;

      monthCount[month] = (monthCount[month] ?? 0) + 1;
      timeCount[timeSlot] = (timeCount[timeSlot] ?? 0) + 1;

      if (appointmentTime.hour < 12) {
        morningBusCount[timeSlot] = (morningBusCount[timeSlot] ?? 0) + 1;
      }

      if (appointmentTime.hour > 17 ||
          (appointmentTime.hour == 17 && appointmentTime.minute >= 30)) {
        nightBusCount[timeSlot] = (nightBusCount[timeSlot] ?? 0) + 1;
      }

      timeRouteCount.putIfAbsent(timeSlot, () => {});
      timeRouteCount[timeSlot]![routeName] =
          (timeRouteCount[timeSlot]![routeName] ?? 0) + 1;
    }

    print('\n=== 时间频次统计 ===');
    final sortedTimes = timeCount.entries.toList()
      ..sort((a, b) {
        int freqCompare = b.value.compareTo(a.value);
        if (freqCompare != 0) return freqCompare;
        return a.key.compareTo(b.key);
      });

    for (var entry in sortedTimes) {
      print(
          '${entry.key} - ${entry.value}次 (路线: ${timeRouteCount[entry.key]?.entries.map((e) => "${e.key}: ${e.value}次").join(", ")})');
    }

    print('\n=== 早班车统计 ===');
    final sortedMorning = morningBusCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedMorning) {
      print('${entry.key} - ${entry.value}次');
    }

    print('\n=== 晚班车统计 ===');
    final sortedNight = nightBusCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedNight) {
      print('${entry.key} - ${entry.value}次');
    }

    print('\n=== 月度统计 ===');
    final sortedMonths = monthCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var entry in sortedMonths) {
      print('${entry.key}月 - ${entry.value}次');
    }

    int? mostFrequentMonth;
    int maxMonthCount = 0;
    monthCount.forEach((month, count) {
      if (count > maxMonthCount) {
        maxMonthCount = count;
        mostFrequentMonth = month;
      }
    });

    String? mostFrequentTime;
    int maxTimeCount = 0;
    String? mostFrequentRoute;
    timeCount.forEach((time, count) {
      if (count > maxTimeCount) {
        maxTimeCount = count;
        mostFrequentTime = time;
        mostFrequentRoute = timeRouteCount[time]!
            .entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }
    });

    String? mostFrequentMorningBus;
    int maxMorningCount = 0;
    morningBusCount.forEach((time, count) {
      if (count > maxMorningCount) {
        maxMorningCount = count;
        mostFrequentMorningBus = time;
      }
    });

    String? mostFrequentNightBus;
    int maxNightCount = 0;
    nightBusCount.forEach((time, count) {
      if (count > maxNightCount) {
        maxNightCount = count;
        mostFrequentNightBus = time;
      }
    });

    double violationRate =
        totalRides > 0 ? (violationCount / totalRides * 100) : 0;

    String keyword;
    String keywordReason;
    IconData keywordIcon;

    if (totalRides < 30) {
      keyword = "大摆子";
      keywordReason = "全年仅预约了 **$totalRides** 次班车，是个不折不扣的大摆子！";
      keywordIcon = Icons.directions_walk;
    } else if (monthCount.values.every((count) => count >= 10)) {
      keyword = "卷王";
      keywordReason = "全年每个月都预约了 **10** 次以上的班车，是个不折不扣的卷王！";
      keywordIcon = Icons.workspace_premium;
    } else if (violationRate > 30) {
      keyword = "鸽王";
      keywordReason =
          "全年违约率高达 **${violationRate.toStringAsFixed(1)}%**，获得年度鸽王称号！";
      keywordIcon = Icons.flutter_dash;
    } else if (mostFrequentNightBus != null) {
      final nightHour = int.parse(mostFrequentNightBus!.split(':')[0]);
      final nightMinute = int.parse(mostFrequentNightBus!.split(':')[1]);
      if (nightHour >= 22 || (nightHour == 21 && nightMinute >= 30)) {
        keyword = "夜猫子";
        keywordReason = "最常预约 **$mostFrequentNightBus** 的班车，是个不折不扣的夜猫子！";
        keywordIcon = Icons.nightlight_round;
      } else {
        keyword = "momo";
        keywordReason = "全年搭乘 **$totalRides** 次班车，是个稳定的通勤选手！";
        keywordIcon = Icons.sentiment_satisfied;
      }
    } else if (mostFrequentMorningBus != null) {
      final morningHour = int.parse(mostFrequentMorningBus!.split(':')[0]);
      final morningMinute = int.parse(mostFrequentMorningBus!.split(':')[1]);
      if (morningHour < 8 || (morningHour == 8 && morningMinute <= 30)) {
        keyword = "早鸟";
        keywordReason = "最常预约 **$mostFrequentMorningBus** 的班车，是个积极向上的早鸟！";
        keywordIcon = Icons.wb_sunny;
      } else {
        keyword = "momo";
        keywordReason = "全年搭乘 **$totalRides** 次班车，是个稳定的通勤选手！";
        keywordIcon = Icons.sentiment_satisfied;
      }
    } else {
      keyword = "momo";
      keywordReason = "全年搭乘 **$totalRides** 次班车，是个稳定的通勤选手！";
      keywordIcon = Icons.sentiment_satisfied;
    }

    return {
      'year': summaryYear,
      'totalRides': totalRides,
      'violationCount': violationCount,
      'violationRate': violationRate,
      'mostFrequentMonth': mostFrequentMonth,
      'mostFrequentMonthCount': maxMonthCount,
      'mostFrequentTime': mostFrequentTime,
      'mostFrequentTimeCount': maxTimeCount,
      'mostFrequentRoute': mostFrequentRoute,
      'mostFrequentMorningBus': mostFrequentMorningBus,
      'mostFrequentMorningBusCount': maxMorningCount,
      'mostFrequentNightBus': mostFrequentNightBus,
      'mostFrequentNightBusCount': maxNightCount,
      'keyword': keyword,
      'keywordReason': keywordReason,
      'keywordIcon': keywordIcon,
    };
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
        SingleChildScrollView(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              width: screenWidth,
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
                  SummaryTextBuilder.buildStoryText(
                    context,
                    '在这一年里，你一共预约了 **${summary['totalRides']}** 次班车，超越了 **???%** 的马池口 🐮🐴！',
                    highlight: true,
                    randomKey: _randomPercentageKey,
                  ),
                  if (summary['violationCount'] > 0) ...[
                    SizedBox(height: 16),
                    SummaryTextBuilder.buildStoryText(
                      context,
                      SummaryTextBuilder.getViolationComment(
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
                    SummaryTextBuilder.buildStoryText(
                      context,
                      '你在 **${summary['mostFrequentMonth']}月** 最为勤奋，预约了 **${summary['mostFrequentMonthCount']}** 次班车',
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
                  if (summary['mostFrequentTime'] != null &&
                      summary['mostFrequentRoute'] != null) ...[
                    Divider(height: 32),
                    SummaryTextBuilder.buildStoryText(
                      context,
                      '你预约最多的是 **${summary['mostFrequentTime']}** 的 **${summary['mostFrequentRoute']}** 班车，共预约了 **${summary['mostFrequentTimeCount']}** 次',
                      highlight: true,
                    ),
                  ],
                  if (summary['mostFrequentMorningBus'] != null) ...[
                    SizedBox(height: 24),
                    SummaryTextBuilder.buildStoryText(
                      context,
                      SummaryTextBuilder.getMorningBusComment(
                        summary['mostFrequentMorningBus'],
                        summary['mostFrequentMorningBusCount'],
                      ),
                    ),
                  ],
                  if (summary['mostFrequentNightBus'] != null) ...[
                    SizedBox(height: 24),
                    SummaryTextBuilder.buildStoryText(
                      context,
                      SummaryTextBuilder.getNightBusComment(
                        summary['mostFrequentNightBus'],
                        summary['mostFrequentNightBusCount'],
                      ),
                    ),
                  ],
                  SizedBox(height: 32),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withAlpha((0.5 * 255).toInt()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              summary['keywordIcon'] as IconData,
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${summary['year']}年度关键词',
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          summary['keyword'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5,
                          child: SummaryTextBuilder.buildStoryText(
                            context,
                            summary['keywordReason'],
                            fontSize: 14,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.only(top: 32),
                    child: Column(
                      children: [
                        if (_isSaving) ...[
                          Text(
                            '扫码下载 Marchkov Helper',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '自动预约，一键乘车',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withAlpha((0.05 * 255).toInt()),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: QrImageView(
                                  data: 'https://shuttle.variantconst.com',
                                  version: QrVersions.auto,
                                  size: 140.0,
                                  padding: EdgeInsets.all(10),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary
                                      .withAlpha((0.8 * 255).toInt()),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withAlpha((0.2 * 255).toInt()),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _saveAndShare,
                                borderRadius: BorderRadius.circular(32),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.share_rounded,
                                        color: theme.colorScheme.onPrimary,
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        '分享我的年度总结',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isSaving)
          Positioned.fill(
            child: Container(
              color: theme.scaffoldBackgroundColor.withAlpha(255),
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
