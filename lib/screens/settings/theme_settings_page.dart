import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class ThemeSettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('主题设置'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7 * 9 / 16,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? (isDarkMode
                          ? Colors.white12
                          : Theme.of(context).primaryColor.withOpacity(0.3))
                      : Colors.grey.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
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
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white
                                  : Theme.of(context).primaryColor,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: AnimatedOpacity(
                          duration: Duration(milliseconds: 300),
                          opacity: isSelected ? 1.0 : 0.0,
                          child: Container(
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white
                                  : Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: isDarkMode
                                  ? Theme.of(context).primaryColor
                                  : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          AnimatedDefaultTextStyle(
            duration: Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: isSelected ? 18 : 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
            child: Text(title),
          ),
        ],
      ),
    );
  }
}
