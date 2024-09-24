import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/version_service.dart'; // 添加此行

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  AboutPageState createState() => AboutPageState();
}

class AboutPageState extends State<AboutPage> {
  String _currentVersion = '';
  final VersionService _versionService = VersionService(); // 添加此行

  @override
  void initState() {
    super.initState();
    _getCurrentVersion();
  }

  void _getCurrentVersion() async {
    String version = await _versionService.getCurrentVersion(); // 修改此行
    setState(() {
      _currentVersion = version;
    });
  }

  Future<void> _checkUpdate() async {
    try {
      String? latestVersion = await _versionService.getLatestVersion(); // 修改此行
      if (latestVersion != null && latestVersion != _currentVersion) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('发现新版本'),
            content:
                Text('最新版本为 $latestVersion，当前版本为 $_currentVersion。是否前往更新？'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  String? url = await _versionService.getUpdateURL(); // 修改此行
                  if (url != null) {
                    await _launchUpdateURL(url); // 修改此行
                  }
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
      } else if (latestVersion != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('当前已是最新版本')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新时出现错误')),
      );
    }
  }

  Future<void> _launchUpdateURL(String url) async {
    // 修改此行
    try {
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开更新链接')),
        );
      }
    } catch (e) {
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MarchKov Helper',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '你的私有班车预约服务，出示乘车码从未如此优雅。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '当前版本：$_currentVersion',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Divider(),
            ListTile(
              title: Text('检查更新'),
              subtitle: Text('点击检查是否有新版本可用'),
              trailing: Icon(Icons.arrow_forward),
              onTap: _checkUpdate,
            ),
            Divider(),
            ListTile(
              title: Text('访问官网'),
              subtitle: Text('点击访问马池口官网'),
              trailing: Icon(Icons.arrow_forward),
              onTap: _visitWebsite,
            ),
            Divider(),
            ListTile(
              title: Text('支持我们'),
              subtitle: Text('点击访问代码仓库'),
              trailing: Icon(Icons.arrow_forward),
              onTap: _launchSupportURL,
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  '© VariantConst 2024',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
