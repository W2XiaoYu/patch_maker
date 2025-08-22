import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// 支持的语言列表
const List<Locale> supportedLocales = [
  Locale('zh', ''), // 中文
  Locale('en', ''), // 英文
];

/// 本地化代理
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

/// 本地化资源
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // 获取当前实例的辅助方法
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // 本地化资源
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Update Patch Generator',
      'oldVersionDir': 'Old Version Directory',
      'newVersionDir': 'New Version Directory',
      'outputDir': 'Output Directory',
      'generatePatch': 'Generate Patch',
      'logOutput': 'Log Output',
      'waitingForInput': 'Waiting for input...',
      'generatingPatch': 'Generating patch...',
      'patchGenerationSuccess': 'Patch generation successful!',
      'patchGenerationFailed': 'Patch generation failed!',
      'output': 'Output',
      'error': 'Error',
      'errorCode': 'Error code',
      'executionError': 'Execution error',
      'scriptFileNotFound': 'Error: Script file not found',
      'fillAllRequiredFields':
          'Error: Please fill in all required directories.',
      'ensureGoExecutableExists':
          'Please ensure the Go executable exists and the path is correct.',
      'selectTheme': 'Select Theme',
      'lightTheme': 'Light',
      'darkTheme': 'Dark',
      'systemTheme': 'System',
      'cancel': 'Cancel',
      'versionWriteFile':
          'Write the version file in the new version directory.',
      'signFiles': 'Sign Files',
    },
    'zh': {
      'appTitle': '更新补丁生成器',
      'oldVersionDir': '旧版本目录',
      'newVersionDir': '新版本目录',
      'outputDir': '输出目录',
      'generatePatch': '生成补丁',
      'logOutput': '日志输出',
      'waitingForInput': '等待输入...',
      'generatingPatch': '正在生成补丁...',
      'patchGenerationSuccess': '补丁生成成功！',
      'patchGenerationFailed': '补丁生成失败！',
      'output': '输出',
      'error': '错误',
      'errorCode': '错误码',
      'executionError': '执行出错',
      'scriptFileNotFound': '错误：未找到脚本文件',
      'fillAllRequiredFields': '错误：请填写所有必填目录和版本标签。',
      'ensureGoExecutableExists': '请确保Go可执行文件存在且路径正确。',
      'selectTheme': '选择主题',
      'lightTheme': '浅色',
      'darkTheme': '深色',
      'systemTheme': '跟随系统',
      'cancel': '取消',
      'versionWriteFile': "在新版本目录下写入版本文件",
      'signFiles': '文件签名',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['appTitle']!;

  String get oldVersionDir =>
      _localizedValues[locale.languageCode]!['oldVersionDir']!;

  String get newVersionDir =>
      _localizedValues[locale.languageCode]!['newVersionDir']!;

  String get outputDir => _localizedValues[locale.languageCode]!['outputDir']!;

  String get generatePatch =>
      _localizedValues[locale.languageCode]!['generatePatch']!;

  String get logOutput => _localizedValues[locale.languageCode]!['logOutput']!;

  String get waitingForInput =>
      _localizedValues[locale.languageCode]!['waitingForInput']!;

  String get generatingPatch =>
      _localizedValues[locale.languageCode]!['generatingPatch']!;

  String get patchGenerationSuccess =>
      _localizedValues[locale.languageCode]!['patchGenerationSuccess']!;

  String get patchGenerationFailed =>
      _localizedValues[locale.languageCode]!['patchGenerationFailed']!;

  String get output => _localizedValues[locale.languageCode]!['output']!;

  String get error => _localizedValues[locale.languageCode]!['error']!;

  String get errorCode => _localizedValues[locale.languageCode]!['errorCode']!;

  String get executionError =>
      _localizedValues[locale.languageCode]!['executionError']!;

  String get scriptFileNotFound =>
      _localizedValues[locale.languageCode]!['scriptFileNotFound']!;

  String get fillAllRequiredFields =>
      _localizedValues[locale.languageCode]!['fillAllRequiredFields']!;

  String get ensureGoExecutableExists =>
      _localizedValues[locale.languageCode]!['ensureGoExecutableExists']!;

  String get selectTheme =>
      _localizedValues[locale.languageCode]!['selectTheme']!;

  String get lightTheme =>
      _localizedValues[locale.languageCode]!['lightTheme']!;

  String get darkTheme => _localizedValues[locale.languageCode]!['darkTheme']!;

  String get systemTheme =>
      _localizedValues[locale.languageCode]!['systemTheme']!;

  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;

  String get versionWriteFile =>
      _localizedValues[locale.languageCode]!['versionWriteFile']!;

  String get signFiles => _localizedValues[locale.languageCode]!['signFiles']!;
}
