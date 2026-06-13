import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:patch_maker/l10n/app_localizations.dart';
import 'package:patch_maker/theme/app_theme.dart';
import 'package:patch_maker/utils/installer.dart';

class InstallerWidget extends StatefulWidget {
  final Function(Locale) onLocaleChanged;
  final Locale currentLocale;
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const InstallerWidget({
    super.key,
    required this.onLocaleChanged,
    required this.currentLocale,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<InstallerWidget> createState() => _InstallerWidgetState();
}

class _InstallerWidgetState extends State<InstallerWidget> {
  final TextEditingController _patchDirController = TextEditingController();
  final TextEditingController _installDirController = TextEditingController();
  final List<String> _logMessages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  DateTime? _startTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logMessages.isEmpty) {
      _addLog(AppLocalizations.of(context).waitingForInput);
    }
  }

  void _addLog(String message, {bool isError = false}) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final prefix = isError ? '❌' : '📝';
      _logMessages.add('[$timestamp] $prefix $message');
    });
    _scrollToBottom();
  }

  void _clearLogs() {
    setState(() {
      _logMessages.clear();
    });
  }

  @override
  void dispose() {
    _patchDirController.dispose();
    _installDirController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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

  Future<void> _pickDirectory(TextEditingController controller) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        controller.text = selectedDirectory;
      });
    }
  }

  Future<void> _installPatch() async {
    if (_patchDirController.text.isEmpty ||
        _installDirController.text.isEmpty) {
      _addLog(
        AppLocalizations.of(context).fillAllRequiredFields,
        isError: true,
      );
      return;
    }

    _clearLogs();
    setState(() {
      _isLoading = true;
      _startTime = DateTime.now();
    });

    _addLog('🚀 ${AppLocalizations.of(context).installingPatch}');

    try {
      final installDir = _installDirController.text.trim();
      final installer = await PatchInstaller.create(
        patchDir: _patchDirController.text.trim(),
        installDir: installDir,
      );

      if (installer == null) {
        _addLog(AppLocalizations.of(context).scriptFileNotFound, isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final success = await installer.install(
        onProgress: (String message, {bool isError = false}) {
          _addLog(message, isError: isError);
        },
      );

      final endTime = DateTime.now();
      final duration = _startTime != null
          ? endTime.difference(_startTime!)
          : Duration.zero;

      _addLog('');
      if (success) {
        _addLog('✅ ${AppLocalizations.of(context).installSuccess}');
      } else {
        _addLog(
          '❌ ${AppLocalizations.of(context).installFailed}',
          isError: true,
        );
      }
      _addLog('⏱️ 总用时: ${duration.inMinutes}分${duration.inSeconds % 60}秒');
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppLocalizations.of(context).installerTitle),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDirectoryRow(
                controller: _patchDirController,
                labelText: AppLocalizations.of(context).patchDir,
              ),
              const SizedBox(height: 12.0),
              _buildDirectoryRow(
                controller: _installDirController,
                labelText: AppLocalizations.of(context).installDir,
              ),
              const SizedBox(height: 24.0),
              _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 15.0),
                    )
                  : Center(
                      child: CupertinoButton.filled(
                        onPressed: _installPatch,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40.0,
                          vertical: 14.0,
                        ),
                        child: Text(
                          AppLocalizations.of(context).installPatch,
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
                      minimumSize: const Size(0, 0),
                      onPressed: _clearLogs,
                      child: const Text('清空日志', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8.0),
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
                          style: CupertinoTheme.of(context)
                              .textTheme
                              .textStyle
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
                color: CupertinoTheme.of(context)
                    .textTheme
                    .textStyle
                    .color!
                    .withValues(alpha: .7),
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
