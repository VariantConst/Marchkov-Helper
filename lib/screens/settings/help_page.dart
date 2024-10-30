import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '帮助中心',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: '快速入门',
            icon: Icons.rocket_launch_outlined,
            items: [
              _HelpItem(
                title: '乘车页面',
                content: '乘车页面是应用的核心功能区域，展示当前时刻可乘坐的班车卡片，您可以从中选择最适合的班车进行预约。',
                icon: Icons.home_outlined,
              ),
              _HelpItem(
                title: '预约页面',
                content: '点击班车按钮预约，再次点击取消预约，长按按钮查看对应班车详情。',
                icon: Icons.directions_bus_outlined,
              ),
              _HelpItem(
                title: '仿官方页面',
                content:
                    '点击二维码可以切换到仿官方页面。主页面和仿官方页面的二维码都是有效的。该功能默认关闭，您可以在设置中开启此功能。',
                icon: Icons.qr_code,
              ),
            ],
          ),
          _buildSection(
            context,
            title: '功能说明',
            icon: Icons.lightbulb_outline,
            items: [
              _HelpItem(
                title: '班车显示',
                content:
                    '乘车页面只会显示过去30分钟到未来30分钟内发车的班车。如果已错过发车时刻，将无法预约，只会显示乘车码或临时码。',
                icon: Icons.access_time,
              ),
              _HelpItem(
                title: '智能推荐',
                content: '应用会学习您的乘车偏好，根据历史乘车记录智能推荐班车。需要您手动打开设置-预约历史，以缓存乘车记录。',
                icon: Icons.auto_awesome,
              ),
              _HelpItem(
                title: '自动预约',
                content: '应用会自动为您预约最合适的班车，直接出码，无需操作。该功能默认关闭，您可以在设置中开启此功能。',
                icon: Icons.schedule,
              ),
            ],
          ),
          _buildSection(
            context,
            title: '常见问题',
            icon: Icons.help_outline,
            items: [
              _HelpItem(
                title: '加载缓慢',
                content:
                    '如果加载太慢，请尝试关闭代理或连接校园网。这种情况在校园网连接差的情况下非常常见。如果问题仍然存在，可以尝试退出登录重新进入。',
                icon: Icons.speed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_HelpItem> items,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _buildHelpItem(context, items[i]),
                if (i < items.length - 1) Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem(BuildContext context, _HelpItem item) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            leading: Icon(item.icon, color: theme.colorScheme.primary),
            title: Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(56, 0, 16, 16),
                child: Text(
                  item.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpItem {
  final String title;
  final String content;
  final IconData icon;

  const _HelpItem({
    required this.title,
    required this.content,
    required this.icon,
  });
}
