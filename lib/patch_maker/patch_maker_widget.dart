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
  bool _shouldClearUserInformationFiles = false;
  bool _shouldCopyOldLibraryFiles = false;
  bool _shouldDeletePdbFiles = false;
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

  String _buildRealtimeStatusMessage(String stdout, String stderr) {
    final l10n = AppLocalizations.of(context);
    final trimmedStdout = stdout.trim();
    final trimmedStderr = stderr.trim();

    return '''
${l10n.generatingPatch}

📁 ${l10n.output}:
${trimmedStdout.isNotEmpty ? trimmedStdout : '(无输出)'}

⚠️ ${l10n.error}:
${trimmedStderr.isNotEmpty ? trimmedStderr : '(无错误)'}''';
  }

  void _refreshRealtimeStatus(
    StringBuffer stdoutBuffer,
    StringBuffer stderrBuffer,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = _buildRealtimeStatusMessage(
        stdoutBuffer.toString(),
        stderrBuffer.toString(),
      );
    });
    _scrollToBottom();
  }

  void _appendStdoutLog(
    StringBuffer stdoutBuffer,
    StringBuffer stderrBuffer,
    String message,
  ) {
    stdoutBuffer.writeln(message);
    _refreshRealtimeStatus(stdoutBuffer, stderrBuffer);
  }

  Future<int> _deleteFilesInDirectory(Directory directory) async {
    if (!directory.existsSync()) {
      return 0;
    }

    final files = <File>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        files.add(entity);
      }
    }

    for (final file in files) {
      await file.delete();
    }

    return files.length;
  }

  Future<int> _copyFilesRecursively(
    Directory sourceDirectory,
    Directory targetDirectory,
  ) async {
    if (!sourceDirectory.existsSync()) {
      return 0;
    }

    int copiedCount = 0;
    await for (final entity in sourceDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      final relativePath = path.relative(
        entity.path,
        from: sourceDirectory.path,
      );
      final targetPath = path.join(targetDirectory.path, relativePath);
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await entity.copy(targetPath);
      copiedCount++;
    }

    return copiedCount;
  }

  Future<int> _deletePdbFilesInDirectory(Directory directory) async {
    if (!directory.existsSync()) {
      return 0;
    }

    final pdbFiles = <File>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File &&
          path.extension(entity.path).toLowerCase() == '.pdb') {
        pdbFiles.add(entity);
      }
    }

    for (final file in pdbFiles) {
      await file.delete();
    }

    return pdbFiles.length;
  }

  Future<void> _runPrePatchOperations(
    String oldDir,
    String newDir,
    StringBuffer stdoutBuffer,
    StringBuffer stderrBuffer,
  ) async {
    if (_shouldClearUserInformationFiles) {
      final userInformationDir = Directory(
        path.join(newDir, 'Studio3DArt', 'UserInformation'),
      );
      if (userInformationDir.existsSync()) {
        final deletedCount = await _deleteFilesInDirectory(userInformationDir);
        _appendStdoutLog(
          stdoutBuffer,
          stderrBuffer,
          '🧹 已删除新目录 Studio3DArt\\UserInformation 下 $deletedCount 个文件',
        );
      } else {
        _appendStdoutLog(
          stdoutBuffer,
          stderrBuffer,
          'ℹ️ 新目录 Studio3DArt\\UserInformation 不存在，跳过删除',
        );
      }
    }

    if (_shouldCopyOldLibraryFiles) {
      final oldLibraryDir = Directory(
        path.join(oldDir, 'Studio3DArt', 'Library'),
      );
      final newLibraryDir = Directory(
        path.join(newDir, 'Studio3DArt', 'Library'),
      );

      if (oldLibraryDir.existsSync()) {
        final copiedCount = await _copyFilesRecursively(
          oldLibraryDir,
          newLibraryDir,
        );
        _appendStdoutLog(
          stdoutBuffer,
          stderrBuffer,
          '📚 已复制旧目录 Studio3DArt\\Library 下 $copiedCount 个文件到新目录',
        );
      } else {
        _appendStdoutLog(
          stdoutBuffer,
          stderrBuffer,
          'ℹ️ 旧目录 Studio3DArt\\Library 不存在，跳过复制',
        );
      }
    }

    if (_shouldDeletePdbFiles) {
      final newDirectory = Directory(newDir);
      final deletedCount = await _deletePdbFilesInDirectory(newDirectory);
      _appendStdoutLog(
        stdoutBuffer,
        stderrBuffer,
        '🧽 已删除新目录下 $deletedCount 个 .pdb 文件',
      );
    }
  }

  String _formatArchiveDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _normalizeArchiveVersion(String rawVersion) {
    final trimmedVersion = rawVersion.trim();
    if (trimmedVersion.isEmpty) {
      return '';
    }

    return trimmedVersion.replaceFirst(RegExp(r'^[vV]'), '');
  }

  String _buildArchiveFileName({
    required String version,
    required bool isPatchArchive,
  }) {
    final archiveDate = _formatArchiveDate(DateTime.now());
    final archiveSuffix = isPatchArchive ? '_Pitch' : '';
    return '3A_Render-v${version}_Prod_Win64_$archiveDate$archiveSuffix.zip';
  }

  String _buildArchivePath(
    String sourceDirPath, {
    required String version,
    required bool isPatchArchive,
  }) {
    final normalizedPath = path.normalize(sourceDirPath);
    final parentDir = path.dirname(normalizedPath);
    return path.join(
      parentDir,
      _buildArchiveFileName(version: version, isPatchArchive: isPatchArchive),
    );
  }

  Future<void> _createZipArchive({
    required String sevenZipPath,
    required String sourceDirPath,
    required String archivePath,
    required Encoding systemEncoding,
    required StringBuffer stdoutBuffer,
    required StringBuffer stderrBuffer,
  }) async {
    final l10n = AppLocalizations.of(context);
    final sourceDir = Directory(sourceDirPath);
    if (!sourceDir.existsSync()) {
      _appendStdoutLog(
        stdoutBuffer,
        stderrBuffer,
        'ℹ️ 目录不存在，跳过压缩: $sourceDirPath',
      );
      return;
    }

    final entries = await sourceDir.list(followLinks: false).toList();
    if (entries.isEmpty) {
      _appendStdoutLog(
        stdoutBuffer,
        stderrBuffer,
        'ℹ️ 目录为空，跳过压缩: $sourceDirPath',
      );
      return;
    }

    final archiveFile = File(archivePath);
    if (archiveFile.existsSync()) {
      await archiveFile.delete();
    }

    _appendStdoutLog(
      stdoutBuffer,
      stderrBuffer,
      '🗜️ 正在压缩: $sourceDirPath -> $archivePath',
    );

    final process = await Process.start(
      sevenZipPath,
      ['a', '-tzip', archivePath, '*', '-r', '-y'],
      workingDirectory: sourceDir.path,
      runInShell: false,
    );

    final zipStdout = StringBuffer();
    final zipStderr = StringBuffer();

    process.stdout.transform(systemEncoding.decoder).listen((data) {
      zipStdout.write(data);
    });
    process.stderr.transform(systemEncoding.decoder).listen((data) {
      zipStderr.write(data);
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final errorOutput = zipStderr.toString().trim().isNotEmpty
          ? zipStderr.toString().trim()
          : zipStdout.toString().trim();
      stderrBuffer.writeln(
        '压缩失败: $sourceDirPath -> $archivePath\n$errorOutput',
      );
      _refreshRealtimeStatus(stdoutBuffer, stderrBuffer);
      throw Exception('${l10n.archiveFailed}: $archivePath');
    }

    _appendStdoutLog(
      stdoutBuffer,
      stderrBuffer,
      '📦 ${l10n.archiveCreated}: $archivePath',
    );
  }

  Future<void> _createPostPatchArchives(
    String newDir,
    String outputDir,
    Encoding systemEncoding,
    StringBuffer stdoutBuffer,
    StringBuffer stderrBuffer,
  ) async {
    final archiveVersion = _normalizeArchiveVersion(
      _versionInputController.text,
    );
    if (archiveVersion.isEmpty) {
      throw Exception(AppLocalizations.of(context).archiveVersionRequired);
    }

    final sevenZipPath = Common.get7ZipPath();
    if (sevenZipPath == null || !File(sevenZipPath).existsSync()) {
      throw Exception(AppLocalizations.of(context).zipToolNotFound);
    }

    _appendStdoutLog(
      stdoutBuffer,
      stderrBuffer,
      AppLocalizations.of(context).compressingArchives,
    );

    await _createZipArchive(
      sevenZipPath: sevenZipPath,
      sourceDirPath: newDir,
      archivePath: _buildArchivePath(
        newDir,
        version: archiveVersion,
        isPatchArchive: false,
      ),
      systemEncoding: systemEncoding,
      stdoutBuffer: stdoutBuffer,
      stderrBuffer: stderrBuffer,
    );

    await _createZipArchive(
      sevenZipPath: sevenZipPath,
      sourceDirPath: outputDir,
      archivePath: _buildArchivePath(
        outputDir,
        version: archiveVersion,
        isPatchArchive: true,
      ),
      systemEncoding: systemEncoding,
      stdoutBuffer: stdoutBuffer,
      stderrBuffer: stderrBuffer,
    );
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

    if (_normalizeArchiveVersion(_versionInputController.text).isEmpty) {
      setState(() {
        _statusMessage = AppLocalizations.of(context).archiveVersionRequired;
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
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final exe = await Common.getRenderUpdaterPath(
      exeName: "patch_maker_2026-01-04.exe",
    );

    if (exe == null || !File(exe).existsSync()) {
      setState(() {
        _isLoading = false;
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
      await _runPrePatchOperations(oldDir, newDir, stdoutBuffer, stderrBuffer);

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
        _appendStdoutLog(
          stdoutBuffer,
          stderrBuffer,
          '✅ version.json 已写入: ${jsonFile.path}',
        );
      }

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
        _refreshRealtimeStatus(stdoutBuffer, stderrBuffer);
      });

      // 实时监听 stderr
      process.stderr.transform(systemEncoding.decoder).listen((data) {
        stderrBuffer.write(data);
        _refreshRealtimeStatus(stdoutBuffer, stderrBuffer);
      });

      final exitCode = await process.exitCode;

      final endTime = DateTime.now();
      final duration = _startTime != null
          ? endTime.difference(_startTime!)
          : Duration.zero;
      final durationText =
          '⏱️ 用时: ${duration.inMinutes}分${duration.inSeconds % 60}秒${duration.inMilliseconds % 1000}毫秒';

      if (exitCode == 0) {
        await _createPostPatchArchives(
          newDir,
          outputDir,
          systemEncoding,
          stdoutBuffer,
          stderrBuffer,
        );
      }

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
    final l10n = AppLocalizations.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.appTitle),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfigurationPanel(l10n),
              const SizedBox(height: 12),
              _buildOptionsPanel(l10n),
              const SizedBox(height: 24),
              _buildExecutionPanel(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDirectoryRow(
          controller: _oldDirController,
          labelText: l10n.oldVersionDir,
        ),
        const SizedBox(height: 12),
        _buildDirectoryRow(
          controller: _newDirController,
          labelText: l10n.newVersionDir,
        ),
        const SizedBox(height: 12),
        _buildDirectoryRow(
          controller: _outputDirController,
          labelText: l10n.outputDir,
        ),
        const SizedBox(height: 12),
        _buildVersionInputRow(
          controller: _versionInputController,
          labelText: l10n.versionNumber,
        ),
      ],
    );
  }

  Widget _buildOptionsPanel(AppLocalizations l10n) {
    return Column(
      children: [
        _buildToggleRow(
          labelText: l10n.versionWriteFile,
          value: _isGeneratVersion,
          onChanged: (value) {
            setState(() {
              _isGeneratVersion = value;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          labelText: l10n.clearUserInformationFiles,
          value: _shouldClearUserInformationFiles,
          onChanged: (value) {
            setState(() {
              _shouldClearUserInformationFiles = value;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          labelText: l10n.copyOldLibraryFiles,
          value: _shouldCopyOldLibraryFiles,
          onChanged: (value) {
            setState(() {
              _shouldCopyOldLibraryFiles = value;
            });
          },
        ),
        const SizedBox(height: 12),
        _buildToggleRow(
          labelText: l10n.deletePdbFiles,
          value: _shouldDeletePdbFiles,
          onChanged: (value) {
            setState(() {
              _shouldDeletePdbFiles = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildExecutionPanel(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 15))
            : Center(
                child: CupertinoButton.filled(
                  onPressed: _generatePatch,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  child: Text(
                    l10n.generatePatch,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
        const SizedBox(height: 24),
        Text(
          '${l10n.logOutput}:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme().getLogContainerBackgroundColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme().getTextFieldBorderColor(context),
            ),
          ),
          child: _buildLogPanel(),
        ),
      ],
    );
  }

  Widget _buildLogPanel() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Text(
        _statusMessage,
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 13.5,
          height: 1.45,
          color: CupertinoTheme.of(context).textTheme.textStyle.color,
          fontFamily: Platform.isWindows ? 'Consolas' : null,
        ),
      ),
    );
  }

  Widget _buildVersionInputRow({
    required TextEditingController controller,
    required String labelText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            fontSize: 13,
            color: CupertinoTheme.of(
              context,
            ).textTheme.textStyle.color!.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          placeholder: labelText,
          onChanged: (_) {
            if (mounted) {
              setState(() {});
            }
          },
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          style: CupertinoTheme.of(context).textTheme.textStyle,
          decoration: BoxDecoration(
            color: AppTheme().getTextFieldBackgroundColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme().getTextFieldBorderColor(context),
            ),
          ),
          clearButtonMode: OverlayVisibilityMode.editing,
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String labelText,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            labelText,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 13,
              color: CupertinoTheme.of(
                context,
              ).textTheme.textStyle.color!.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: CupertinoSwitch(value: value, onChanged: onChanged),
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
            fontSize: 13,
            color: CupertinoTheme.of(
              context,
            ).textTheme.textStyle.color!.withValues(alpha: 0.7),
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
                  horizontal: 12,
                  vertical: 12,
                ),
                style: CupertinoTheme.of(context).textTheme.textStyle,
                decoration: BoxDecoration(
                  color: AppTheme().getTextFieldBackgroundColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme().getTextFieldBorderColor(context),
                  ),
                ),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: CupertinoButton(
                onPressed: () => _pickDirectory(controller),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  CupertinoIcons.folder_open,
                  size: 24,
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
      debugPrint('验证manifest错误: $e\n$stack');
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
                      style: const TextStyle(fontSize: 13, height: 1.4),
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
