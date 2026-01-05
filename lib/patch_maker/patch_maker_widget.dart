import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:patch_maker/l10n/app_localizations.dart';
import 'package:patch_maker/l10n/language_selector.dart';
import 'package:patch_maker/theme/app_theme.dart';
import 'package:patch_maker/theme/theme_selector.dart';
import 'package:patch_maker/utils/common.dart';
import 'package:crypto/crypto.dart';

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
  late String _statusMessage;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _statusMessage = '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_statusMessage.isEmpty) {
      _statusMessage = AppLocalizations.of(context).waitingForInput;
    }
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

  Future<void> _verifyManifest(
    String manifestPath,
    String stdout,
    String stderr,
    String durationText,
  ) async {
    // 显示验证弹窗
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _VerificationDialog(
          manifestPath: manifestPath,
          stdout: stdout,
          stderr: stderr,
          durationText: durationText,
        );
      },
    );
  }

  Future<void> _generatePatch() async {
    if (_oldDirController.text.isEmpty ||
        _newDirController.text.isEmpty ||
        _outputDirController.text.isEmpty) {
      setState(() {
        _statusMessage = AppLocalizations.of(context).fillAllRequiredFields;
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = AppLocalizations.of(context).generatingPatch;
      _startTime = DateTime.now();
    });
    _scrollToBottom();

    final oldDir = _oldDirController.text.trim();
    final newDir = _newDirController.text.trim();
    final outputDir = _outputDirController.text.trim();
    final newVersionTag = _newVersionTagController.text.trim();
    final globalMeta = path.join(outputDir, 'manifest.json');
    final exe = await Common.getRenderUpdaterPath(
      exeName: "patch_maker_2026-01-04.exe",
    );

    if (exe == null || !File(exe).existsSync()) {
      setState(() {
        _statusMessage = AppLocalizations.of(context).scriptFileNotFound;
      });
      _scrollToBottom();
      return;
    }

    final systemEncoding =
        Platform.isWindows && Platform.localeName.contains('zh')
        ? Encoding.getByName('gbk') ?? utf8
        : utf8;
    if (_isGeneratVersion) {
      final version = _versionInputController.text.trim();

      ///1.0.0.0521
      final versionInfo = {
        'currentVersion': version,
        'buildNumber': version.split('.').last,
        'buildDate': DateTime.now().toIso8601String(),
      };
      final jsonFile = File(path.join(newDir, 'version.json'));
      await jsonFile.writeAsString(jsonEncode(versionInfo), flush: true);
      print("✅ version.json 已写入: ${jsonFile.path}");
    }
    Process? process;
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    try {
      process = await Process.start(exe, [
        '-old-dir',
        oldDir,
        '-new-dir',
        newDir,
        '-output-dir',
        outputDir,
        '-global-meta',
        globalMeta,
        '-new-version-tag',
        newVersionTag,
      ], runInShell: false);

      // 实时监听 stdout，每行更新UI
      process.stdout.transform(systemEncoding.decoder).listen((data) {
        stdoutBuffer.write(data);
        setState(() {
          _statusMessage = '''
${AppLocalizations.of(context).generatingPatch}

📁 ${AppLocalizations.of(context).output}:
${stdoutBuffer.toString().trim()}

⚠️ ${AppLocalizations.of(context).error}:
${stderrBuffer.toString().trim().isNotEmpty ? stderrBuffer.toString().trim() : '(无错误)'}''';
        });
        _scrollToBottom();
      });

      // 实时监听 stderr
      process.stderr.transform(systemEncoding.decoder).listen((data) {
        stderrBuffer.write(data);
        setState(() {
          _statusMessage = '''
${AppLocalizations.of(context).generatingPatch}

📁 ${AppLocalizations.of(context).output}:
${stdoutBuffer.toString().trim().isNotEmpty ? stdoutBuffer.toString().trim() : '(无输出)'}

⚠️ ${AppLocalizations.of(context).error}:
${stderrBuffer.toString().trim()}''';
        });
        _scrollToBottom();
      });

      final exitCode = await process.exitCode;

      final endTime = DateTime.now();
      final duration = _startTime != null
          ? endTime.difference(_startTime!)
          : Duration.zero;
      final durationText =
          '⏱️ 用时: ${duration.inMinutes}分${duration.inSeconds % 60}秒${duration.inMilliseconds % 1000}毫秒';

      final stdout = stdoutBuffer.toString().trim();
      final stderr = stderrBuffer.toString().trim();

      setState(() {
        if (exitCode == 0) {
          _statusMessage =
              '''
✅ ${AppLocalizations.of(context).patchGenerationSuccess}
$durationText

📁 ${AppLocalizations.of(context).output}:
${stdout.isNotEmpty ? stdout : '(无输出)'}

⚠️ ${AppLocalizations.of(context).error}:
${stderr.isNotEmpty ? stderr : '(无错误)'}

🔍 正在验证manifest.json...''';
        } else {
          _statusMessage =
              '''
❌ ${AppLocalizations.of(context).patchGenerationFailed}
$durationText
🔁 ${AppLocalizations.of(context).errorCode}: $exitCode

📁 ${AppLocalizations.of(context).output}:
${stdout.isNotEmpty ? stdout : '(无输出)'}

⚠️ ${AppLocalizations.of(context).error}:
${stderr.isNotEmpty ? stderr : '(无错误)'}''';
        }
      });
      _scrollToBottom();

      // 如果成功，验证manifest.json
      if (exitCode == 0) {
        await _verifyManifest(globalMeta, stdout, stderr, durationText);
      }
    } catch (e, stack) {
      final endTime = DateTime.now();
      final duration = _startTime != null
          ? endTime.difference(_startTime!)
          : Duration.zero;
      final durationText =
          '⏱️ 用时: ${duration.inMinutes}分${duration.inSeconds % 60}秒${duration.inMilliseconds % 1000}毫秒';

      setState(() {
        _statusMessage =
            '''
💥 ${AppLocalizations.of(context).executionError}
$durationText

⚠️ 错误详情:
$e

📋 堆栈跟踪:
$stack''';
      });
      _scrollToBottom();
    } finally {
      process?.kill();
      setState(() {
        _isLoading = false;
      });
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
        child: SingleChildScrollView(
          // 允许内容滚动，防止溢出
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDirectoryRow(
                controller: _oldDirController,
                labelText: AppLocalizations.of(context).oldVersionDir,
              ),
              const SizedBox(height: 12.0), // 增加间距
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

              const SizedBox(height: 24.0), // 按钮上方多一点间距
              _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 15.0),
                    ) // 适当调整加载指示器大小
                  : Center(
                      child: CupertinoButton.filled(
                        onPressed: _generatePatch,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40.0,
                          vertical: 14.0,
                        ), // 调整按钮内边距
                        child: Text(
                          AppLocalizations.of(context).generatePatch,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ), // 按钮文字稍粗
                        ),
                      ),
                    ),
              const SizedBox(height: 24.0), // 状态消息上方多一点间距
              Text(
                '${AppLocalizations.of(context).logOutput}:',
                style: const TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 8.0),
              Container(
                width: double.infinity, // 确保宽度占满
                height: 200, // 固定高度的日志区域
                decoration: BoxDecoration(
                  color: AppTheme().getLogContainerBackgroundColor(context),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: AppTheme().getTextFieldBorderColor(context),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _statusMessage,
                    style: CupertinoTheme.of(context).textTheme.textStyle
                        .copyWith(
                          fontSize: 14.0,
                          color: AppTheme().getLogTextColor(context),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            ).textTheme.textStyle.color!.withOpacity(0.7),
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
            ).textTheme.textStyle.color!.withOpacity(0.7),
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

// 验证弹窗组件
class _VerificationDialog extends StatefulWidget {
  final String manifestPath;
  final String stdout;
  final String stderr;
  final String durationText;

  const _VerificationDialog({
    required this.manifestPath,
    required this.stdout,
    required this.stderr,
    required this.durationText,
  });

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  bool _isLoading = true;
  String _resultMessage = '';
  String _currentFile = '';
  int _verifiedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performVerification();
    });
  }

  Future<void> _performVerification() async {
    final l10n = AppLocalizations.of(context);

    try {
      final manifestFile = File(widget.manifestPath);
      if (!manifestFile.existsSync()) {
        setState(() {
          _isLoading = false;
          _resultMessage = l10n.manifestNotFound;
        });
        return;
      }

      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
      final files = manifest['files'] as List<dynamic>? ?? [];

      // 统计信息
      int totalFiles = files.length;
      int errorFiles = 0;
      int successFiles = 0;
      int deletedFiles = 0;
      int hashVerified = 0;
      List<String> errorMessages = [];

      setState(() {
        _totalCount = totalFiles;
      });

      // 检查每个文件
      for (int i = 0; i < files.length; i++) {
        final fileMap = files[i] as Map<String, dynamic>;
        final relativePath = fileMap['relative_path'] as String? ?? '';

        setState(() {
          _verifiedCount = i + 1;
          _currentFile = relativePath;
        });

        // 检查是否是已删除的文件
        if (fileMap['deleted_file_only'] == true) {
          deletedFiles++;
          continue;
        }

        // 检查是否有错误
        if (fileMap.containsKey('error_status')) {
          errorFiles++;
          final errorStatus = fileMap['error_status'] as String;
          errorMessages.add('$relativePath\n  $errorStatus');
        } else {
          successFiles++;

          // 验证补丁文件哈希
          final patchFilePath = fileMap['patch_file_path'] as String?;
          final patchFileSha256 = fileMap['patch_file_sha256'] as String?;

          if (patchFilePath != null &&
              patchFileSha256 != null &&
              patchFileSha256.isNotEmpty) {
            final patchFile = File(patchFilePath);
            if (patchFile.existsSync()) {
              try {
                final bytes = await patchFile.readAsBytes();
                final actualHash = sha256.convert(bytes).toString();
                if (actualHash != patchFileSha256) {
                  errorMessages.add('$relativePath\n  ${l10n.hashMismatch}');
                } else {
                  hashVerified++;
                }
              } catch (e) {
                errorMessages.add('$relativePath\n  ${l10n.cannotReadPatch}');
              }
            } else {
              errorMessages.add('$relativePath\n  ${l10n.patchNotFound}');
            }
          }
        }
      }

      // 构建验证报告
      final reportBuffer = StringBuffer();
      reportBuffer.writeln('${l10n.verificationComplete}\n');
      reportBuffer.writeln('${l10n.totalFiles}: $totalFiles');
      reportBuffer.writeln('${l10n.successGenerated}: $successFiles');
      reportBuffer.writeln('${l10n.failedGenerated}: $errorFiles');
      reportBuffer.writeln('${l10n.deletedFiles}: $deletedFiles');
      reportBuffer.writeln('${l10n.hashVerified}: $hashVerified');

      if (errorMessages.isNotEmpty) {
        reportBuffer.writeln('\n${l10n.errorDetails}:');
        reportBuffer.writeln('─' * 30);
        for (var msg in errorMessages) {
          reportBuffer.writeln(msg);
          reportBuffer.writeln('');
        }
      } else {
        reportBuffer.writeln('\n${l10n.allFilesVerified}');
      }

      setState(() {
        _isLoading = false;
        _resultMessage = reportBuffer.toString();
      });
    } catch (e, stack) {
      setState(() {
        _isLoading = false;
        _resultMessage = '${l10n.verificationError}: $e';
      });
      print('验证manifest错误: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: CupertinoPopupSurface(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              l10n.verifyManifest,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // 内容区域
            if (_isLoading) ...[
              // 加载中
              Row(
                children: [
                  const CupertinoActivityIndicator(radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.verifying} ($_verifiedCount/$_totalCount)',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (_currentFile.isNotEmpty)
                          Text(
                            _currentFile,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.systemGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 结果
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: Text(
                    _resultMessage,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 关闭按钮
            if (!_isLoading)
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemBlue,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l10n.close,
                    style: const TextStyle(color: CupertinoColors.white),
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
