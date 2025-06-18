import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum ThemeMode {
  light,
  dark,
  system,
}

class AppTheme {
  static final AppTheme _instance = AppTheme._internal();
  
  factory AppTheme() {
    return _instance;
  }
  
  AppTheme._internal();
  
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  set themeMode(ThemeMode mode) {
    _themeMode = mode;
  }
  
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      final brightness = MediaQuery.platformBrightnessOf(context);
      return brightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
  
  CupertinoThemeData getLightTheme() {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: CupertinoColors.activeBlue,
      barBackgroundColor: CupertinoColors.systemBackground,
      scaffoldBackgroundColor: CupertinoColors.systemBackground,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: '微软雅黑',
          color: CupertinoColors.black,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: '微软雅黑',
          color: CupertinoColors.black,
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  CupertinoThemeData getDarkTheme() {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: CupertinoColors.activeBlue,
      barBackgroundColor: CupertinoColors.darkBackgroundGray,
      scaffoldBackgroundColor: CupertinoColors.darkBackgroundGray,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: '微软雅黑',
          color: CupertinoColors.white,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: '微软雅黑',
          color: CupertinoColors.white,
          fontSize: 18.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  CupertinoThemeData getTheme(BuildContext context) {
    return isDarkMode(context) ? getDarkTheme() : getLightTheme();
  }
  
  // 获取文本字段背景色
  Color getTextFieldBackgroundColor(BuildContext context) {
    return isDarkMode(context) 
        ? CupertinoColors.darkBackgroundGray.withOpacity(0.5) 
        : CupertinoColors.white;
  }
  
  // 获取文本字段边框色
  Color getTextFieldBorderColor(BuildContext context) {
    return isDarkMode(context) 
        ? CupertinoColors.systemGrey.withOpacity(0.3) 
        : CupertinoColors.systemGrey4;
  }
  
  // 获取日志容器背景色
  Color getLogContainerBackgroundColor(BuildContext context) {
    return isDarkMode(context) 
        ? CupertinoColors.darkBackgroundGray.withOpacity(0.7) 
        : CupertinoColors.systemBackground;
  }
  
  // 获取日志文本颜色
  Color getLogTextColor(BuildContext context) {
    return isDarkMode(context) 
        ? CupertinoColors.systemGrey.darkColor 
        : CupertinoColors.systemGrey;
  }
}