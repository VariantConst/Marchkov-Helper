import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class ThemeSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('主题设置')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: 16),
                _buildThemeOption(context, '浅色模式', 'assets/day_mode.svg',
                    ThemeMode.light, themeProvider),
                SizedBox(height: 24),
                _buildThemeOption(context, '深色模式', 'assets/night_mode.svg',
                    ThemeMode.dark, themeProvider),
                SizedBox(height: 24),
                _buildThemeOption(context, '跟随系统', 'assets/auto_mode.svg',
                    ThemeMode.system, themeProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, String svgPath,
      ThemeMode themeMode, ThemeProvider themeProvider) {
    final isSelected = themeProvider.themeMode == themeMode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color textColor;
    if (isSelected) {
      textColor = isDarkMode ? Colors.white : Theme.of(context).primaryColor;
    } else {
      textColor = isDarkMode ? Colors.white70 : Colors.black87;
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.width * 0.7 * 9 / 16,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => themeProvider.setThemeMode(themeMode),
                child: Stack(
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(isSelected
                          ? [
                              1,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0
                            ]
                          : [
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0
                            ]),
                      child: SvgPicture.asset(
                        svgPath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
