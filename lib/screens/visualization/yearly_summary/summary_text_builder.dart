import 'package:flutter/material.dart';
import 'random_percentage_widget.dart';

class SummaryTextBuilder {
  static Widget buildStoryText(
    BuildContext context,
    String text, {
    bool highlight = false,
    double? fontSize,
    TextAlign? textAlign,
    GlobalKey<RandomPercentageWidgetState>? randomKey,
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
                      child: RandomPercentageWidget(
                        key: randomKey,
                        randomKey: randomKey,
                      ),
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

  static String getMorningBusComment(String busTime, int count) {
    int hour = int.parse(busTime.split(':')[0]);

    if (hour < 7) {
      return '早上你最常选择的是 **$busTime** 的早班车，是个起得特别早的早起鸟呢，继续保持这个好习惯吧！';
    } else if (hour < 9) {
      return '早上你最常选择的是 **$busTime** 的班车，作息很规律呢，继续保持健康的生活节奏吧！';
    } else {
      return '早上你最常选择的是 **$busTime** 的班车，看来你很享受睡到自然醒呢，这是在提前适应大厂作息吗？😉';
    }
  }

  static String getNightBusComment(String busTime, int count) {
    int hour = int.parse(busTime.split(':')[0]);

    if (hour < 21) {
      return '晚上你最常选择的是 **$busTime** 的班车，看来你很注重工作与生活的平衡呢！';
    } else {
      return '晚上你最常选择的是 **$busTime** 的班车，是个努力的夜猫子呢，要记得注意休息哦！';
    }
  }

  static String getViolationComment(int violationCount, double violationRate) {
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

  static String getShareText(
      Map<String, dynamic> summary, int randomPercentage) {
    return '我在${summary['year']}年共预约了${summary['totalRides']}次班车，超越了$randomPercentage%的马池口🐮🐴，年度关键词是"${summary['keyword']}"！来自 Marchkov Helper';
  }
}
