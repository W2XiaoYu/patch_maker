import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:patch_maker/l10n/app_localizations.dart';
import 'package:patch_maker/l10n/language_selector.dart';
import 'package:patch_maker/theme/app_theme.dart';
import 'package:patch_maker/theme/theme_selector.dart';
import 'package:patch_maker/utils/path.dart';

class PatchMakerWidget extends StatefulWidget {
  final Function(Locale) onLocaleChanged;
  final Locale currentLocale;
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const PatchMakerWidget({
    super.key,
    required this.onLocaleChanged,
    required this.currentLocale,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<PatchMakerWidget> createState() => _PatchMakerWidgetState();
}

class _PatchMakerWidgetState extends State<PatchMakerWidget> {
  final TextEditingController _oldDirController = TextEditingController();
  final TextEditingController _newDirController = TextEditingController();
  final TextEditingController _outputDirController = TextEditingController();
  final TextEditingController _newVersionTagController =
      TextEditingController();
  final TextEditingController _versionInputController = TextEditingController();
  bool _isGeneratVersion = false;
  final List<String> _logMessages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  DateTime? _startTime;
  int _errorCount = 0;
  int _successCount = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logMessages.isEmpty) {
      _addLog(AppLocalizations.of(context).waitingForInput);
    }
  }

  // 添加日志的辅助方法
  void _addLog(String message, {bool isError = false}) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final prefix = isError ? '❌' : '📝';
      _logMessages.add('[$timestamp] $prefix $message');
      if (isError) {
        _errorCount++;
      } else {
        _successCount++;
      }
    });
    _scrollToBottom();
  }

  // 清空日志
  void _clearLogs() {
    setState(() {
      _logMessages.clear();
      _errorCount = 0;
      _successCount = 0;
    });
  }

  @override
  void dispose() {
    _oldDirController.dispose();
    _newDirController.dispose();
    _outputDirController.dispose();
    _newVersionTagController.dispose();
    _scrollController.dispose();
    _versionInputController.dispose();
    super.dispose();
  }

  // 滚动到底部的辅助方法
  void _scrollToBottom() {
    // 使用Future.delayed确保在状态更新后滚动
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 辅助方法，用于选择目录
  Future<void> _pickDirectory(TextEditingController controller) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        controller.text = selectedDirectory;
      });
    }
  }

  Future<void> _generatePatch() async {
    if (_oldDirController.text.isEmpty ||
        _newDirController.text.isEmpty ||
        _outputDirController.text.isEmpty) {
      _addLog(
        AppLocalizations.of(context).fillAllRequiredFields,
        isError: true,
      );
      return;
    }

    // 清空之前的日志
    _clearLogs();

    setState(() {
      _isLoading = true;
      _startTime = DateTime.now();
    });

    _addLog('🚀 ${AppLocalizations.of(context).generatingPatch}');

    final oldDir = _oldDirController.text.trim();
    final newDir = _newDirController.text.trim();
    final outputDir = _outputDirController.text.trim();
    final newVersionTag = _newVersionTagController.text.trim();
    final globalMeta = path.join(outputDir, 'manifest.json');

    try {
      // 如果需要生成版本文件
      if (_isGeneratVersion) {
        final version = _versionInputController.text.trim();
        if (version.isEmpty) {
          _addLog('⚠️ 版本号不能为空', isError: true);
          setState(() => _isLoading = false);
          return;
        }

        final versionInfo = {
          'currentVersion': version,
          'buildNumber': version.split('.').last,
          'buildDate': DateTime.now().toIso8601String(),
        };
        final jsonFile = File(path.join(newDir, 'version.json'));
        await jsonFile.writeAsString(jsonEncode(versionInfo), flush: true);

        _addLog('✅ version.json 已写入: ${jsonFile.path}');
      }

      // 创建 PatchUtils 实例
      final patchUtils = await PatchUtils.create(
        oldPath: oldDir,
        newPath: newDir,
        outputPath: outputDir,
      );

      if (patchUtils == null) {
        _addLog(AppLocalizations.of(context).scriptFileNotFound, isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // 生成补丁 manifest（带进度回调）
      final manifest = await patchUtils.generatePatchManifest(
        newVersionTag: newVersionTag,
        onProgress: (String message, {bool isError = false}) {
          _addLog(message, isError: isError);
        },
      );

      final endTime = DateTime.now();
      final duration = _startTime != null
          ? endTime.difference(_startTime!)
          : Duration.zero;

      if (manifest != null) {
        _addLog('');
        _addLog('✅ ${AppLocalizations.of(context).patchGenerationSuccess}');
        _addLog('⏱️ 总用时: ${duration.inMinutes}分${duration.inSeconds % 60}秒');

        // 自动验证 manifest.json
        _addLog('');
        _addLog('🔍 正在验证 manifest.json...');
        await _validateManifestJson(globalMeta);
      } else {
        _addLog(
          '❌ ${AppLocalizations.of(context).patchGenerationFailed}',
          isError: true,
        );
      }
    } catch (e, stack) {
      _addLog('', isError: true);
      _addLog(
        '💥 ${AppLocalizations.of(context).executionError}',
        isError: true,
      );
      _addLog('错误详情: $e', isError: true);
      print('堆栈跟踪: $stack');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 验证 manifest.json
  Future<void> _validateManifestJson(String manifestPath) async {
    try {
      final manifestFile = File(manifestPath);
      if (!manifestFile.existsSync()) {
        _addLog('⚠️ manifest.json 不存在', isError: true);
        return;
      }

      final content = await manifestFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      // 检查必需字段
      final requiredFields = [
        'old_version_directory',
        'new_version_directory',
        'patch_output_directory',
        'generation_time',
        'total_duration_seconds',
        'new_version_tag',
        'patch_count',
        'new_file_count',
        'deleted_file_count',
        'files',
      ];

      bool hasError = false;
      for (var field in requiredFields) {
        if (!json.containsKey(field)) {
          _addLog('❌ 缺少字段: $field', isError: true);
          hasError = true;
        }
      }

      // 检查文件列表
      final files = json['files'] as List<dynamic>? ?? [];
      int errorFileCount = 0;

      for (var fileData in files) {
        final fileMap = fileData as Map<String, dynamic>;
        final errorMessage = fileMap['error_message'] as String?;

        if (errorMessage != null && errorMessage.isNotEmpty) {
          errorFileCount++;
          final relativePath = fileMap['relative_path'] as String? ?? '未知';
          _addLog('❌ 文件错误: $relativePath', isError: true);
          _addLog('   原因: $errorMessage', isError: true);
        }
      }

      if (!hasError) {
        _addLog('✅ manifest.json 结构正确');
        _addLog('📊 文件总数: ${files.length}');
        _addLog('📦 补丁文件: ${json['patch_count']}');
        _addLog('➕ 新增文件: ${json['new_file_count']}');
        _addLog('🗑️ 删除文件: ${json['deleted_file_count']}');

        if (errorFileCount > 0) {
          _addLog('⚠️ 失败文件: $errorFileCount', isError: true);
        } else {
          _addLog('✅ 所有文件处理成功');
        }
      }
    } catch (e) {
      _addLog('❌ 验证 manifest.json 失败: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppLocalizations.of(context).appTitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemeSelector(
              onThemeChanged: widget.onThemeChanged,
              currentThemeMode: widget.currentThemeMode,
            ),
            const SizedBox(width: 8),
            LanguageSelector(
              onLocaleChanged: widget.onLocaleChanged,
              currentLocale: widget.currentLocale,
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDirectoryRow(
                controller: _oldDirController,
                labelText: AppLocalizations.of(context).oldVersionDir,
              ),
              const SizedBox(height: 12.0),
              _buildDirectoryRow(
                controller: _newDirController,
                labelText: AppLocalizations.of(context).newVersionDir,
              ),
              const SizedBox(height: 12.0),
              _buildDirectoryRow(
                controller: _outputDirController,
                labelText: AppLocalizations.of(context).outputDir,
              ),
              const SizedBox(height: 12.0),
              _buildVersionRow(
                controller: _versionInputController,
                labelText: AppLocalizations.of(context).versionWriteFile,
              ),

              const SizedBox(height: 24.0),
              _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 15.0),
                    )
                  : Center(
                      child: CupertinoButton.filled(
                        onPressed: _generatePatch,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40.0,
                          vertical: 14.0,
                        ),
                        child: Text(
                          AppLocalizations.of(context).generatePatch,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
              const SizedBox(height: 24.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppLocalizations.of(context).logOutput}:',
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  if (_logMessages.isNotEmpty)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minSize: 0,
                      onPressed: _clearLogs,
                      child: const Text('清空日志', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8.0),
              // 日志区域使用 Expanded 占满剩余空间
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme().getLogContainerBackgroundColor(context),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: AppTheme().getTextFieldBorderColor(context),
                    ),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12.0),
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      final message = _logMessages[index];
                      final isError =
                          message.contains('❌') ||
                          message.contains('💥') ||
                          message.contains('⚠️');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          message,
                          style: CupertinoTheme.of(context).textTheme.textStyle
                              .copyWith(
                                fontSize: 13.0,
                                color: isError
                                    ? CupertinoColors.systemRed
                                    : AppTheme().getLogTextColor(context),
                                fontFamily: 'monospace',
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleTextField({
    required TextEditingController controller,
    required String labelText,
    String? placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 13.0,
            color: CupertinoTheme.of(
              context,
            ).textTheme.textStyle.color!.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder ?? labelText,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          style: CupertinoTheme.of(context).textTheme.textStyle,
          decoration: BoxDecoration(
            color: AppTheme().getTextFieldBackgroundColor(context),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: AppTheme().getTextFieldBorderColor(context),
            ),
          ),
          clearButtonMode: OverlayVisibilityMode.editing,
        ),
      ],
    );
  }

  Widget _buildVersionRow({
    required TextEditingController controller,
    required String labelText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 13.0,
            color: CupertinoTheme.of(
              context,
            ).textTheme.textStyle.color!.withValues(alpha: .7),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                enabled: _isGeneratVersion,
                controller: controller,
                placeholder: labelText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 12.0,
                ),
                style: CupertinoTheme.of(context).textTheme.textStyle,
                decoration: BoxDecoration(
                  color: AppTheme().getTextFieldBackgroundColor(context),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AppTheme().getTextFieldBorderColor(context),
                  ),
                ),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
            ),
            const SizedBox(width: 8.0),
            SizedBox(
              width: 60,
              child: CupertinoSwitch(
                value: _isGeneratVersion,
                onChanged: (bool value) {
                  setState(() {
                    _isGeneratVersion = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectoryRow({
    required TextEditingController controller,
    required String labelText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 13.0,
            color: CupertinoTheme.of(
              context,
            ).textTheme.textStyle.color!.withValues(alpha: .7),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: controller,
                placeholder: labelText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 12.0,
                ),
                style: CupertinoTheme.of(context).textTheme.textStyle,
                decoration: BoxDecoration(
                  color: AppTheme().getTextFieldBackgroundColor(context),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AppTheme().getTextFieldBorderColor(context),
                  ),
                ),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
            ),
            const SizedBox(width: 8.0),
            SizedBox(
              width: 60,
              child: CupertinoButton(
                onPressed: () => _pickDirectory(controller),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  CupertinoIcons.folder_open,
                  size: 24.0,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
