import 'dart:io'; // 新增
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  AboutPageState createState() => AboutPageState(); // 修改这里
}

// 将类名从私有改为公有，并确保类名一致
class AboutPageState extends State<AboutPage> {
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _getCurrentVersion();
  }

  void _getCurrentVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  Future<void> _checkUpdate() async {
    try {
      final response = await http
          .get(Uri.parse('https://shuttle.variantconst.com/api/version'));
      if (response.statusCode == 200) {
        String latestVersion = response.body.trim();
        if (latestVersion != _currentVersion) {
          // 有新版本，提示用户更新
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('发现新版本'),
              content:
                  Text('最新版本为 $latestVersion，当前版本为 $_currentVersion。是否前往更新？'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _launchUpdateURL(); // 修改这里
                  },
                  child: Text('更新'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('取消'),
                ),
              ],
            ),
          );
        } else {
          // 已是最新版本
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('当前已是最新版本')),
          );
        }
      } else {
        // 请求失败
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法获取最新版本号')),
        );
      }
    } catch (e) {
      // 异常处理
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新时出现错')),
      );
    }
  }

  Future<void> _launchUpdateURL() async {
    String url = '';
    try {
      if (Platform.isIOS) {
        // 获取 iOS 更新链接
        final response = await http
            .get(Uri.parse('https://shuttle.variantconst.com/api/ios_url'));
        if (response.statusCode == 200) {
          url = response.body.trim();
          print("iOS 更新链接: $url");
        } else {
          throw Exception('无法获取 iOS 更新链接');
        }
      } else if (Platform.isAndroid) {
        // 获取 Android 更新链接
        final response = await http
            .get(Uri.parse('https://shuttle.variantconst.com/api/android_url'));
        if (response.statusCode == 200) {
          url = response.body.trim();
          print("Android 更新链接: $url");
        } else {
          throw Exception('无法获取 Android 更新链接');
        }
      } else {
        // 其他平台，跳转到官网
        url = 'https://shuttle.variantconst.com';
      }

      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开更新链接')),
        );
      }
    } catch (e) {
      // 异常处理
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取更新链接时出现错误')),
      );
    }
  }

  void _visitWebsite() async {
    const url = 'https://shuttle.variantconst.com';
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开官网链接')),
      );
    }
  }

  void _launchSupportURL() async {
    const url = 'https://github.com/VariantConst/3-2-1-Marchkov/';
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开支持链接')),
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
            SizedBox(height: 16),
            Text(
              '当前版本：$_currentVersion',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _checkUpdate,
              child: Text('检查更新'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _launchSupportURL,
              child: Text('支持我们'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _visitWebsite,
              child: Text('访问官网'),
            ),
          ],
        ),
      ),
    );
  }
}
