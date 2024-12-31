import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/version_service.dart'; // 添加此行

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  AboutPageState createState() => AboutPageState();
}

class AboutPageState extends State<AboutPage> {
  String _currentVersion = '';
  final VersionService _versionService = VersionService(); // 添加此行
  bool _isCheckingUpdate = false; // 添加此行

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
    if (_isCheckingUpdate) return; // 如果正在检查，直接返回

    setState(() {
      _isCheckingUpdate = true; // 开始检查时设置为true
    });

    try {
      String? latestVersion = await _versionService.getLatestVersion(); // 修改此行
      if (!mounted) return;

      if (latestVersion != null && latestVersion != _currentVersion) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('发现新版本'),
            content: Text('新版本为 $latestVersion，当前版本为 $_currentVersion。是否前往更新？'),
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
        _showSnackBar(
          icon: Icons.check_circle_outline,
          message: '当前已是最新版本',
          isError: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        icon: Icons.error_outline,
        message: '检查更新时出现错误',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false; // 完成检查时设置为false
        });
      }
    }
  }

  void _showSnackBar({
    required IconData icon,
    required String message,
    required bool isError,
  }) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        backgroundColor: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer,
        content: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isError ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
            SizedBox(width: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchUpdateURL(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        _showSnackBar(
          icon: Icons.error_outline,
          message: '无法打开更新链接',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        icon: Icons.error_outline,
        message: '获取更新链接时出现错误',
        isError: true,
      );
    }
  }

  void _visitWebsite() async {
    const url = 'https://shuttle.variantconst.com';
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showSnackBar(
        icon: Icons.error_outline,
        message: '无法打开官网链接',
        isError: true,
      );
    }
  }

  void _launchSupportURL() async {
    const url = 'https://github.com/VariantConst/3-2-1-Marchkov/';
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _showSnackBar(
        icon: Icons.error_outline,
        message: '无法打开支持链接',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '关于应用',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 头部信息区域
            Container(
              padding: EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withAlpha((0.2 * 255).toInt()),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'MarchKov Helper',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v$_currentVersion',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '你的私有班车预约服务，出示乘车码从未如此优雅。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // 功能列表
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest
                    .withAlpha((0.3 * 255).toInt()),
                child: Column(
                  children: [
                    _buildListTile(
                      context,
                      title: '检查更新',
                      subtitle: '点击检查是否有新版本可用',
                      icon: Icons.system_update_outlined,
                      onTap: _checkUpdate,
                    ),
                    Divider(height: 1, indent: 56),
                    _buildListTile(
                      context,
                      title: '访问官网',
                      subtitle: '点击访问马池口官网',
                      icon: Icons.language_outlined,
                      onTap: _visitWebsite,
                    ),
                    Divider(height: 1, indent: 56),
                    _buildListTile(
                      context,
                      title: '支持我们',
                      subtitle: '点击访问代码仓库',
                      icon: Icons.favorite_outline,
                      onTap: _launchSupportURL,
                    ),
                  ],
                ),
              ),
            ),

            // 版权信息
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                '© VariantConst 2024',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isFirst = title == '检查更新'; // 第一个选项
    final isLast = title == '支持我们'; // 最后一个选项

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: isFirst ? Radius.circular(12) : Radius.zero,
        bottom: isLast ? Radius.circular(12) : Radius.zero,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          title: Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title == '检查更新' && _isCheckingUpdate)
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
