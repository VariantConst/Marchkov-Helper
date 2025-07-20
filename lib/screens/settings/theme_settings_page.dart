import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool isSameColor(Color selected, dynamic color) {
  if (color is MaterialColor) {
    return selected == color ||
        selected == color.shade500 ||
        selected == color.shade700;
  }
  return selected == color;
}

class ThemeSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('selectedMainPageIndex', 2);
            // ignore: use_build_context_synchronously
            Navigator.pop(context);
          },
        ),
        title: Text(
          '主题设置',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主题颜色',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: 16),
                    _buildColorOption(context, themeProvider),
                    SizedBox(height: 32),
                    Text(
                      '外观',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: 16),
                    _buildThemeOptions(context, themeProvider),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(BuildContext context, ThemeProvider themeProvider) {
    final pekingRed = Color.fromRGBO(140, 0, 0, 1.0);
    final colors = [
      pekingRed,
      Colors.purple,
      Colors.green,
      Colors.teal,
      Colors.blue,
      Colors.cyan,
      Colors.yellow,
    ];

    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withAlpha((0.3 * 255).toInt()),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: colors.map((color) {
            final isSelected = isSameColor(themeProvider.selectedColor, color);
            return Stack(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      HapticFeedback.selectionClick(); // 添加震动反馈
                      themeProvider.setSelectedColor(color, context);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha((0.4 * 255).toInt()),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildThemeOptions(BuildContext context, ThemeProvider themeProvider) {
    return Column(
      children: [
        _buildThemeOption(
          context,
          '浅色模式',
          ThemeMode.light,
          themeProvider,
        ),
        SizedBox(height: 16),
        _buildThemeOption(
          context,
          '深色模式',
          ThemeMode.dark,
          themeProvider,
        ),
        SizedBox(height: 16),
        _buildThemeOption(
          context,
          '跟随系统',
          ThemeMode.system,
          themeProvider,
        ),
      ],
    );
  }

  Widget _buildThemeOption(BuildContext context, String title,
      ThemeMode themeMode, ThemeProvider themeProvider) {
    final isSelected = themeProvider.themeMode == themeMode;

    String svgAsset;
    switch (themeMode) {
      case ThemeMode.light:
        svgAsset = 'assets/light_mode.svg';
        break;
      case ThemeMode.dark:
        svgAsset = 'assets/dark_mode.svg';
        break;
      case ThemeMode.system:
        svgAsset = 'assets/auto_mode.svg';
        break;
    }

    return Stack(
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withAlpha((0.3 * 255).toInt()),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              themeProvider.setThemeMode(themeMode, context);
            },
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      svgAsset,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isSelected)
          Positioned.fill(
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
