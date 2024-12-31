import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/ride_info.dart';
import 'summary_violation_pie_chart.dart';
import 'summary_monthly_bar_chart.dart';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart';

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
  final GlobalKey<_RandomPercentageWidgetState> _randomPercentageKey =
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

      // 检查随机数是否已生成，如果没有则自动生成
      final randomPercentageState = _randomPercentageKey.currentState;
      if (randomPercentageState != null &&
          randomPercentageState._randomPercentage == null) {
        randomPercentageState._generateRandomPercentage();
      }

      // 等待下一帧完成渲染
      await Future.delayed(Duration(milliseconds: 500));

      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取渲染边界');

      // 等待图表动画完成
      await Future.delayed(Duration(milliseconds: 500));

      // 确保所有图片都已加载完成
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
        text: _getShareText(summary),
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

  // 添加这个辅助方法来预缓存图片
  Future<void> precacheImage(RenderRepaintBoundary boundary) async {
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

    // 重置月度统计
    monthCount.clear();

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

    // 找出最常预约的时段和路线
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

    // 找出最常预约的早班车
    String? mostFrequentMorningBus;
    int maxMorningCount = 0;
    morningBusCount.forEach((time, count) {
      if (count > maxMorningCount) {
        maxMorningCount = count;
        mostFrequentMorningBus = time;
      }
    });

    // 找出最常预约的晚班车
    String? mostFrequentNightBus;
    int maxNightCount = 0;
    nightBusCount.forEach((time, count) {
      if (count > maxNightCount) {
        maxNightCount = count;
        mostFrequentNightBus = time;
      }
    });

    // 计算违约率
    double violationRate =
        totalRides > 0 ? (violationCount / totalRides * 100) : 0;

    // 计算年度关键词
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
    } else if (mostFrequentNightBus != null &&
        int.parse(mostFrequentNightBus!.split(':')[0]) >= 22) {
      keyword = "夜猫子";
      keywordReason = "最常预约 **$mostFrequentNightBus** 的班车，是个不折不扣的夜猫子！";
      keywordIcon = Icons.nightlight_round;
    } else if (mostFrequentMorningBus != null &&
        int.parse(mostFrequentMorningBus!.split(':')[0]) < 8) {
      keyword = "早鸟";
      keywordReason = "最常预约 **$mostFrequentMorningBus** 的班车，是个积极向上的早鸟！";
      keywordIcon = Icons.wb_sunny;
    } else {
      keyword = "momo";
      keywordReason = "全年搭乘 **$totalRides** 次班车，是个稳定的通勤选手！";
      keywordIcon = Icons.sentiment_satisfied;
    }

    return {
      'year': _getSummaryYear(),
      'totalRides': totalRides,
      'violationCount': violationCount,
      'violationRate': violationRate,
      'mostFrequentMonth': mostFrequentMonth,
      'mostFrequentMonthCount': maxMonthCount,
      'mostFrequentHour': mostFrequentHour,
      'mostFrequentHourCount': maxHourCount,
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

  Widget _buildStoryText(
    BuildContext context,
    String text, {
    bool highlight = false,
    double? fontSize,
    TextAlign? textAlign,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: RichText(
        textAlign: textAlign ?? TextAlign.left,
        text: TextSpan(
          style: TextStyle(
            fontSize: fontSize ?? (highlight ? 20 : 16),
            height: 1.6,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: theme.colorScheme.onSurface,
          ),
          children: text
              .split('**')
              .asMap()
              .map((index, segment) {
                if (segment == '???%') {
                  return MapEntry(
                    index,
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: RandomPercentageWidget(key: _randomPercentageKey),
                    ),
                  );
                }
                return MapEntry(
                  index,
                  TextSpan(
                    text: segment,
                    style: TextStyle(
                      fontSize: index % 2 == 1
                          ? (fontSize ?? 24)
                          : (fontSize ?? (highlight ? 20 : 16)),
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
      return '早上你最常选择的是 **$busTime** 的早班车，是个起得特别早的早起鸟呢，继续保持这个好习惯吧！';
    } else if (hour < 9) {
      return '早上你最常选择的是 **$busTime** 的班车，作息很规律呢，继续保持健康的生活节奏吧！';
    } else {
      return '早上你最常选择的是 **$busTime** 的班车，看来你很享受睡到自然醒呢，这是在提前适应大厂作息吗？😉';
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

  // 修改分享文本格式
  String _getShareText(Map<String, dynamic> summary) {
    final randomPercentage =
        _randomPercentageKey.currentState?._randomPercentage ?? 0;
    return '我在${summary['year']}年共预约了${summary['totalRides']}次班车，超越了$randomPercentage%的马池口🐮🐴，年度关键词是"${summary['keyword']}"！来自 Marchkov Helper';
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
                  _buildStoryText(
                    context,
                    '在这一年里，你一共预约了 **${summary['totalRides']}** 次班车，超越了 **???%** 的马池口 🐮🐴！',
                    highlight: true,
                  ),
                  if (summary['violationCount'] > 0) ...[
                    SizedBox(height: 16),
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
                  if (summary['mostFrequentHour'] != null &&
                      summary['mostFrequentRoute'] != null) ...[
                    Divider(height: 32),
                    _buildStoryText(
                      context,
                      '你预约最多的是 **${summary['mostFrequentHour'].toString().padLeft(2, '0')}:00** 的 **${summary['mostFrequentRoute']}** 班车，共预约了 **${summary['mostFrequentHourCount']}** 次',
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
                          child: _buildStoryText(
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
                          // 二维码部分
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
                          // 重新设计的分享按钮
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

        // 生成图片时的加载指示器
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

class StripePainter extends CustomPainter {
  final Color color;
  final double stripeWidth;
  final double gapWidth;

  StripePainter({
    required this.color,
    required this.stripeWidth,
    required this.gapWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stripeWidth
      ..strokeCap = StrokeCap.round;

    final spacing = stripeWidth + gapWidth;
    final count = (size.width + size.height) ~/ spacing;

    for (var i = -count; i < count * 2; i++) {
      final x = i * spacing - size.height;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StripePainter oldDelegate) =>
      color != oldDelegate.color ||
      stripeWidth != oldDelegate.stripeWidth ||
      gapWidth != oldDelegate.gapWidth;
}

class RandomPercentageWidget extends StatefulWidget {
  const RandomPercentageWidget({super.key});

  @override
  State<RandomPercentageWidget> createState() => _RandomPercentageWidgetState();
}

class _RandomPercentageWidgetState extends State<RandomPercentageWidget> {
  int? _randomPercentage;

  // 添加生成随机数的方法
  void _generateRandomPercentage() {
    setState(() {
      _randomPercentage = 50 + Random().nextInt(51);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _generateRandomPercentage();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 2,
          ),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 200),
            child: _randomPercentage == null
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.95, end: 1.05),
                    duration: Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _randomPercentage == null) {
                          setState(() {});
                        }
                      });

                      return Transform.scale(
                        scale: value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 40,
                              alignment: Alignment.center,
                              child: Text(
                                'randint\n(50,100)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CustomPaint(
                                size: Size(60, 40),
                                painter: StripePainter(
                                  color: theme.colorScheme.primary
                                      .withAlpha((0.2 * 255).toInt()),
                                  stripeWidth: 4,
                                  gapWidth: 4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Text(
                    '$_randomPercentage%',
                    style: TextStyle(
                      fontSize: 20,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
