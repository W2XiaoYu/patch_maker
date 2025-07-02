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
    final exe = await Common.getRenderUpdaterPath(exeName: "patch_maker.exe");

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

    Process? process;
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

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      // 👇并发读取 stdout 和 stderr，避免阻塞
      final stdoutFuture = process.stdout
          .transform(systemEncoding.decoder)
          .forEach(stdoutBuffer.write);
      final stderrFuture = process.stderr
          .transform(systemEncoding.decoder)
          .forEach(stderrBuffer.write);

      final exitCode = await process.exitCode;
      await stdoutFuture;
      await stderrFuture;

      final endTime = DateTime.now();
      final duration = _startTime != null ? endTime.difference(_startTime!) : Duration.zero;
      final durationText = '⏱️ 用时: ${duration.inMinutes}分${duration.inSeconds % 60}秒${duration.inMilliseconds % 1000}毫秒';
      
      final stdout = stdoutBuffer.toString().trim();
      final stderr = stderrBuffer.toString().trim();
      
      setState(() {
        if (exitCode == 0) {
          _statusMessage = '''
✅ ${AppLocalizations.of(context).patchGenerationSuccess}
$durationText

📁 ${AppLocalizations.of(context).output}:
${stdout.isNotEmpty ? stdout : '(无输出)'}

⚠️ ${AppLocalizations.of(context).error}:
${stderr.isNotEmpty ? stderr : '(无错误)'}''';
        } else {
          _statusMessage = '''
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
    } catch (e, stack) {
      final endTime = DateTime.now();
      final duration = _startTime != null ? endTime.difference(_startTime!) : Duration.zero;
      final durationText = '⏱️ 用时: ${duration.inMinutes}分${duration.inSeconds % 60}秒${duration.inMilliseconds % 1000}毫秒';
      
      setState(() {
        _statusMessage = '''
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
            CupertinoButton(
              onPressed: () => _pickDirectory(controller),
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                CupertinoIcons.folder_open,
                size: 24.0,
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
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
        CupertinoTextField(
          controller: controller,
          placeholder: labelText,
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
}
