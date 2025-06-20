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
    // 简单的参数验证
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
      });
      _scrollToBottom();

    final oldDir = _oldDirController.text;
    final newDir = _newDirController.text;
    final outputDir = _outputDirController.text;
    final globalMeta = path.join(outputDir, 'manifest.json');
    final exe = await Common.getRenderUpdaterPath(exeName: "patch_maker.exe");
    if (exe == null) {
      setState(() {
        _statusMessage = AppLocalizations.of(context).scriptFileNotFound;
      });
      _scrollToBottom();
    }
    Process? process;
    try {
      process = await Process.start(
        exe ?? "", // 假设你的Go exe在此路径
        [
          '-old-dir',
          oldDir,
          '-new-dir',
          newDir,
          '-output-dir',
          outputDir,
          '-global-meta',
          globalMeta,
        ],
        runInShell: true,
      );
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final systemEncoding =
          Platform.isWindows && Platform.localeName.contains('zh')
          ? Encoding.getByName('gbk') ?? utf8
          : utf8;

      await for (var data in process.stdout.transform(systemEncoding.decoder)) {
        stdoutBuffer.write(data);
      }
      await for (var data in process.stderr.transform(systemEncoding.decoder)) {
        stderrBuffer.write(data);
      }

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        setState(() {
          _statusMessage =
              '${AppLocalizations.of(context).patchGenerationSuccess}\n${AppLocalizations.of(context).output}:\n${stdoutBuffer.toString()}\n${AppLocalizations.of(context).error}:\n${stderrBuffer.toString()}';
        });
        _scrollToBottom();
      } else {
        setState(() {
          _statusMessage =
              '${AppLocalizations.of(context).patchGenerationFailed}\n${AppLocalizations.of(context).errorCode}: $exitCode\n${AppLocalizations.of(context).output}:\n${stdoutBuffer.toString()}\n${AppLocalizations.of(context).error}:\n${stderrBuffer.toString()}';
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _statusMessage = '${AppLocalizations.of(context).executionError}: $e\n${AppLocalizations.of(context).ensureGoExecutableExists}';
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
                  border: Border.all(color: AppTheme().getTextFieldBorderColor(context)),
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _statusMessage,
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
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
            color: CupertinoTheme.of(context).textTheme.textStyle.color!.withOpacity(0.7),
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
                  border: Border.all(color: AppTheme().getTextFieldBorderColor(context)),
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
            color: CupertinoTheme.of(context).textTheme.textStyle.color!.withOpacity(0.7),
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
            border: Border.all(color: AppTheme().getTextFieldBorderColor(context)),
          ),
          clearButtonMode: OverlayVisibilityMode.editing,
        ),
      ],
    );
  }
}
