import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
      'pageSubtitle':
          'Set the directories, choose optional processing steps, and generate both patch files and ZIP archives.',
      'configurationSectionTitle': 'Directories & Version',
      'configurationSectionSubtitle':
          'Choose the old, new, and output directories, then enter the release version used for ZIP naming.',
      'optionsSectionTitle': 'Processing Options',
      'optionsSectionSubtitle':
          'Extra cleanup and copy operations that run before patch generation starts.',
      'executionSectionTitle': 'Generate & Logs',
      'executionSectionSubtitle':
          'Start the process here and review live output, ZIP creation, and manifest verification logs.',
      'archivesGeneratedHint':
          'After a successful run, the app automatically creates the full package ZIP and the patch ZIP.',
      'scriptFileNotFound': 'Error: Script file not found',
      'zipToolNotFound': 'Error: 7z.exe not found',
      'archiveVersionRequired':
          'Error: Please enter the version number used for zip naming.',
      'compressingArchives': 'Compressing zip packages...',
      'archiveCreated': 'Archive created',
      'archiveFailed': 'Archive creation failed',
      'archivePreviewTitle': 'ZIP Naming Preview',
      'archivePreviewSubtitle':
          'Filenames are generated from the version number and today\'s date.',
      'archivePreviewEmpty':
          'Enter a version number to preview the ZIP filename.',
      'fullPackageLabel': 'Full Package',
      'patchPackageLabel': 'Patch Package',
      'fillAllRequiredFields':
          'Error: Please fill in all required directories.',
      'ensureGoExecutableExists':
          'Please ensure the Go executable exists and the path is correct.',
      'selectTheme': 'Select Theme',
      'lightTheme': 'Light',
      'darkTheme': 'Dark',
      'systemTheme': 'System',
      'cancel': 'Cancel',
      'versionNumber': 'Version Number',
      'versionWriteFile':
          'Write the version file in the new version directory.',
      'clearUserInformationFiles':
          'Delete all files under Studio3DArt\\UserInformation in the new version directory',
      'copyOldLibraryFiles':
          'Copy all files from old Studio3DArt\\Library to new Studio3DArt\\Library',
      'deletePdbFiles': 'Delete all .pdb files in the new version directory',
      'signFiles': 'Sign Files',
      'verifyManifest': 'Verify Manifest',
      'verifying': 'Verifying',
      'verificationComplete': 'Verification Complete',
      'totalFiles': 'Total Files',
      'successGenerated': 'Generated',
      'failedGenerated': 'Failed',
      'deletedFiles': 'Deleted',
      'hashVerified': 'Hash Verified',
      'errorDetails': 'Error Details',
      'allFilesVerified': 'All files verified successfully',
      'manifestNotFound': 'manifest.json not found',
      'verificationError': 'Verification error',
      'hashMismatch': 'Hash mismatch',
      'cannotReadPatch': 'Cannot read patch file',
      'patchNotFound': 'Patch file not found',
      'close': 'Close',
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
      'pageSubtitle': '配置目录、选择处理选项后，一次生成补丁文件和 ZIP 压缩包。',
      'configurationSectionTitle': '目录与版本',
      'configurationSectionSubtitle': '选择旧目录、新目录和输出目录，并填写用于 ZIP 命名的发布版本号。',
      'optionsSectionTitle': '处理选项',
      'optionsSectionSubtitle': '这些额外处理会在补丁生成前执行。',
      'executionSectionTitle': '生成与日志',
      'executionSectionSubtitle': '在这里启动任务，并查看实时输出、ZIP 打包和 Manifest 验证日志。',
      'archivesGeneratedHint': '生成成功后，会自动创建完整包 ZIP 和补丁 ZIP。',
      'scriptFileNotFound': '错误：未找到脚本文件',
      'zipToolNotFound': '错误：未找到 7z.exe',
      'archiveVersionRequired': '错误：请填写用于 ZIP 命名的版本号',
      'compressingArchives': '正在生成 ZIP 压缩包...',
      'archiveCreated': '压缩包已生成',
      'archiveFailed': '压缩包生成失败',
      'archivePreviewTitle': 'ZIP 命名预览',
      'archivePreviewSubtitle': '文件名会根据版本号和当天日期自动生成。',
      'archivePreviewEmpty': '填写版本号后可预览 ZIP 文件名。',
      'fullPackageLabel': '完整包',
      'patchPackageLabel': '补丁包',
      'fillAllRequiredFields': '错误：请填写所有必填目录和版本标签。',
      'ensureGoExecutableExists': '请确保Go可执行文件存在且路径正确。',
      'selectTheme': '选择主题',
      'lightTheme': '浅色',
      'darkTheme': '深色',
      'systemTheme': '跟随系统',
      'cancel': '取消',
      'versionNumber': '版本号',
      'versionWriteFile': "在新版本目录下写入版本文件",
      'clearUserInformationFiles': '删除新目录 Studio3DArt\\UserInformation 下的所有文件',
      'copyOldLibraryFiles': '将旧目录 Studio3DArt\\Library 下的所有文件复制到新目录',
      'deletePdbFiles': '删除新目录里的所有 .pdb 文件',
      'signFiles': '文件签名',
      'verifyManifest': '验证 Manifest',
      'verifying': '正在验证',
      'verificationComplete': '验证完成',
      'totalFiles': '总文件数',
      'successGenerated': '成功生成',
      'failedGenerated': '生成失败',
      'deletedFiles': '已删除',
      'hashVerified': '哈希验证',
      'errorDetails': '错误详情',
      'allFilesVerified': '所有文件验证通过',
      'manifestNotFound': 'manifest.json 文件不存在',
      'verificationError': '验证出错',
      'hashMismatch': '哈希不匹配',
      'cannotReadPatch': '无法读取补丁文件',
      'patchNotFound': '补丁文件不存在',
      'close': '关闭',
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

  String get pageSubtitle =>
      _localizedValues[locale.languageCode]!['pageSubtitle']!;

  String get configurationSectionTitle =>
      _localizedValues[locale.languageCode]!['configurationSectionTitle']!;

  String get configurationSectionSubtitle =>
      _localizedValues[locale.languageCode]!['configurationSectionSubtitle']!;

  String get optionsSectionTitle =>
      _localizedValues[locale.languageCode]!['optionsSectionTitle']!;

  String get optionsSectionSubtitle =>
      _localizedValues[locale.languageCode]!['optionsSectionSubtitle']!;

  String get executionSectionTitle =>
      _localizedValues[locale.languageCode]!['executionSectionTitle']!;

  String get executionSectionSubtitle =>
      _localizedValues[locale.languageCode]!['executionSectionSubtitle']!;

  String get archivesGeneratedHint =>
      _localizedValues[locale.languageCode]!['archivesGeneratedHint']!;

  String get scriptFileNotFound =>
      _localizedValues[locale.languageCode]!['scriptFileNotFound']!;

  String get zipToolNotFound =>
      _localizedValues[locale.languageCode]!['zipToolNotFound']!;

  String get archiveVersionRequired =>
      _localizedValues[locale.languageCode]!['archiveVersionRequired']!;

  String get compressingArchives =>
      _localizedValues[locale.languageCode]!['compressingArchives']!;

  String get archiveCreated =>
      _localizedValues[locale.languageCode]!['archiveCreated']!;

  String get archiveFailed =>
      _localizedValues[locale.languageCode]!['archiveFailed']!;

  String get archivePreviewTitle =>
      _localizedValues[locale.languageCode]!['archivePreviewTitle']!;

  String get archivePreviewSubtitle =>
      _localizedValues[locale.languageCode]!['archivePreviewSubtitle']!;

  String get archivePreviewEmpty =>
      _localizedValues[locale.languageCode]!['archivePreviewEmpty']!;

  String get fullPackageLabel =>
      _localizedValues[locale.languageCode]!['fullPackageLabel']!;

  String get patchPackageLabel =>
      _localizedValues[locale.languageCode]!['patchPackageLabel']!;

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

  String get versionNumber =>
      _localizedValues[locale.languageCode]!['versionNumber']!;

  String get versionWriteFile =>
      _localizedValues[locale.languageCode]!['versionWriteFile']!;

  String get clearUserInformationFiles =>
      _localizedValues[locale.languageCode]!['clearUserInformationFiles']!;

  String get copyOldLibraryFiles =>
      _localizedValues[locale.languageCode]!['copyOldLibraryFiles']!;

  String get deletePdbFiles =>
      _localizedValues[locale.languageCode]!['deletePdbFiles']!;

  String get signFiles => _localizedValues[locale.languageCode]!['signFiles']!;

  String get verifyManifest =>
      _localizedValues[locale.languageCode]!['verifyManifest']!;

  String get verifying => _localizedValues[locale.languageCode]!['verifying']!;

  String get verificationComplete =>
      _localizedValues[locale.languageCode]!['verificationComplete']!;

  String get totalFiles =>
      _localizedValues[locale.languageCode]!['totalFiles']!;

  String get successGenerated =>
      _localizedValues[locale.languageCode]!['successGenerated']!;

  String get failedGenerated =>
      _localizedValues[locale.languageCode]!['failedGenerated']!;

  String get deletedFiles =>
      _localizedValues[locale.languageCode]!['deletedFiles']!;

  String get hashVerified =>
      _localizedValues[locale.languageCode]!['hashVerified']!;

  String get errorDetails =>
      _localizedValues[locale.languageCode]!['errorDetails']!;

  String get allFilesVerified =>
      _localizedValues[locale.languageCode]!['allFilesVerified']!;

  String get manifestNotFound =>
      _localizedValues[locale.languageCode]!['manifestNotFound']!;

  String get verificationError =>
      _localizedValues[locale.languageCode]!['verificationError']!;

  String get hashMismatch =>
      _localizedValues[locale.languageCode]!['hashMismatch']!;

  String get cannotReadPatch =>
      _localizedValues[locale.languageCode]!['cannotReadPatch']!;

  String get patchNotFound =>
      _localizedValues[locale.languageCode]!['patchNotFound']!;

  String get close => _localizedValues[locale.languageCode]!['close']!;
}
