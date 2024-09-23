import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  void _launchURL(BuildContext context) async {
    const url = 'https://github.com/VariantConst/3-2-1-Marchkov/';
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return; // 添加 mounted 检查
      // 如果无法打开链接，可以在这里处理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('关于'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '三、二、一，马池口！',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Text(
              '一键部署你的私有班车预约服务，出示乘车码从未如此优雅。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _launchURL(context),
              child: Text('检查更新'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _launchURL(context),
              child: Text('支持我们'),
            ),
          ],
        ),
      ),
    );
  }
}
