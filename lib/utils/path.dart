import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:patch_maker/model/manifest_metadata.dart';
import 'package:patch_maker/utils/common.dart';

class PatchUtils {
  final String oldPath;
  final String newPath;
  final String outputPath;
  late String exePath;

  PatchUtils._({
    required this.oldPath,
    required this.newPath,
    required this.outputPath,
    required this.exePath,
  });

  /// 创建 PatchUtils 实例
  static Future<PatchUtils?> create({
    required String oldPath,
    required String newPath,
    required String outputPath,
  }) async {
    final exe = await Common.getRenderUpdaterPath(
      exeName: "xdelta3-3.0.11-x86_64.exe",
    );

    if (exe == null || exe.isEmpty) {
      print('错误: 无法找到 xdelta3 可执行文件');
      return null;
    }

    return PatchUtils._(
      oldPath: oldPath,
      newPath: newPath,
      outputPath: outputPath,
      exePath: exe,
    );
  }

  /// 生成补丁并返回完整的 manifest
  Future<ManifestMetadata?> generatePatchManifest({
    String newVersionTag = "",
    Function(String message, {bool isError})? onProgress, // 添加进度回调（支持错误标记）
  }) async {
    final startTime = DateTime.now();
    final List<FileMetadata> fileResults = [];

    // 获取需要处理的文件列表
    onProgress?.call('📂 正在扫描文件...', isError: false);
    final tasks = await _buildTaskList();
    final newFilesMap = <String, bool>{};

    print('开始生成补丁，共 ${tasks.length} 个文件需要处理...');
    onProgress?.call('✅ 扫描完成，共 ${tasks.length} 个文件需要处理', isError: false);

    int patchCount = 0;
    int newFileCount = 0;
    int errorCount = 0;

    // 处理新版本文件（生成补丁或标记为新文件）
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final relativePath = task['relative_path']!;
      newFilesMap[relativePath] = true;

      print('处理: $relativePath (${i + 1}/${tasks.length})');
      onProgress?.call(
        ' [${i + 1}/${tasks.length}] 处理: $relativePath',
        isError: false,
      );

      final metadata = await _makeSinglePatchWithRetry(
        relativePath: relativePath,
        oldFile: task['old_full_path']!,
        newFile: task['new_full_path']!,
        patchOut: task['output_path']!,
        maxRetries: 3,
        onProgress: onProgress,
      );

      if (metadata != null) {
        fileResults.add(metadata);

        if (metadata.errorMessage != null &&
            metadata.errorMessage!.isNotEmpty) {
          // 有错误
          errorCount++;
          onProgress?.call(
            '❌ [${i + 1}/${tasks.length}] 失败: $relativePath',
            isError: true,
          );
        } else if (metadata.newFileOnly == true) {
          newFileCount++;
          onProgress?.call(
            '✅ [${i + 1}/${tasks.length}] 新文件: $relativePath',
            isError: false,
          );
        } else {
          patchCount++;
          onProgress?.call(
            '✅ [${i + 1}/${tasks.length}] 已生成补丁: $relativePath',
            isError: false,
          );
        }
      }

      // 每处理一个文件后让出控制权给 UI 线程
      await Future.delayed(Duration.zero);
    }

    // 检查删除的文件
    onProgress?.call('🔍 检查已删除的文件...', isError: false);
    int deletedFileCount = 0;
    final deletedFiles = await _findDeletedFiles(newFilesMap);
    for (var deletedMeta in deletedFiles) {
      fileResults.add(deletedMeta);
      deletedFileCount++;
      print('删除文件: ${deletedMeta.relativePath}');
      onProgress?.call('🗑️ 已删除: ${deletedMeta.relativePath}', isError: false);

      // 让出控制权给 UI 线程
      await Future.delayed(Duration.zero);
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

    // 生成总结信息
    onProgress?.call('', isError: false);
    onProgress?.call('━━━━━━━━━━━━━━━━━━━━━━━━━━', isError: false);
    onProgress?.call('�� 处理完成！统计信息：', isError: false);
    onProgress?.call('  ✅ 补丁文件: $patchCount 个', isError: false);
    onProgress?.call('  ➕ 新增文件: $newFileCount 个', isError: false);
    onProgress?.call('  🗑️ 删除文件: $deletedFileCount 个', isError: false);
    if (errorCount > 0) {
      onProgress?.call('  ❌ 失败文件: $errorCount 个', isError: true);
    }
    onProgress?.call('  📦 总文件数: ${fileResults.length} 个', isError: false);
    onProgress?.call(
      '  ⏱️ 总用时: ${duration.toStringAsFixed(2)} 秒',
      isError: false,
    );
    onProgress?.call('━━━━━━━━━━━━━━━━━━━━━━━━━━', isError: false);

    final manifest = ManifestMetadata(
      oldVersionDirectory: oldPath,
      newVersionDirectory: newPath,
      patchOutputDirectory: outputPath,
      generationTime: startTime.toIso8601String(),
      totalDurationSeconds: duration,
      newVersionTag: newVersionTag,
      patchCount: patchCount,
      newFileCount: newFileCount,
      deletedFileCount: deletedFileCount,
      files: fileResults,
    );

    onProgress?.call('💾 正在写入 manifest.json...', isError: false);
    await _writeManifestFile(manifest);
    onProgress?.call('✅ manifest.json 已保存', isError: false);

    return manifest;
  }

  /// 查找被删除的文件
  Future<List<FileMetadata>> _findDeletedFiles(
    Map<String, bool> newFilesMap,
  ) async {
    final deletedFiles = <FileMetadata>[];
    final oldDir = Directory(oldPath);

    if (!oldDir.existsSync()) {
      return deletedFiles;
    }

    await for (var entity in oldDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relativePath = entity.path.substring(oldPath.length + 1);

        // 如果新版本中不存在此文件，则标记为删除
        if (!newFilesMap.containsKey(relativePath)) {
          final oldFileSha256 = await _calculateSha256(entity.path);
          final oldFileSize = await entity.length();

          deletedFiles.add(
            FileMetadata(
              relativePath: relativePath,
              newFileSha256: '',
              patchFileSha256: '',
              oldFileSizeBytes: oldFileSize,
              oldFileSha256: oldFileSha256,
              deletedFileOnly: true,
            ),
          );
        }
      }
    }

    return deletedFiles;
  }

  /// 构建任务列表
  Future<List<Map<String, String>>> _buildTaskList() async {
    final tasks = <Map<String, String>>[];
    final oldDir = Directory(oldPath);
    final newDir = Directory(newPath);

    if (!oldDir.existsSync()) {
      print('错误: 旧版本目录不存在: $oldPath');
      return tasks;
    }

    if (!newDir.existsSync()) {
      print('错误: 新版本目录不存在: $newPath');
      return tasks;
    }

    // 遍历新版本目录的所有文件
    await for (var entity in newDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relativePath = entity.path.substring(newPath.length + 1);
        final oldFilePath = '$oldPath${Platform.pathSeparator}$relativePath';
        final outputFilePath =
            '$outputPath${Platform.pathSeparator}$relativePath.patch';

        tasks.add({
          'relative_path': relativePath,
          'old_full_path': oldFilePath,
          'new_full_path': entity.path,
          'output_path': outputFilePath,
        });
      }
    }

    return tasks;
  }

  /// 写入 manifest 文件
  Future<void> _writeManifestFile(ManifestMetadata manifest) async {
    try {
      final manifestPath = '$outputPath${Platform.pathSeparator}manifest.json';
      final manifestFile = File(manifestPath);

      // 确保输出目录存在
      await manifestFile.parent.create(recursive: true);

      // 写入格式化的 JSON
      final jsonStr = JsonEncoder.withIndent('  ').convert(manifest.toJson());
      await manifestFile.writeAsString(jsonStr);

      print('Manifest 已写入: $manifestPath');
    } catch (e) {
      print('写入 manifest 失败: $e');
    }
  }

  /// 生成单个补丁文件（带重试功能）
  Future<FileMetadata?> _makeSinglePatchWithRetry({
    required String relativePath,
    required String oldFile,
    required String newFile,
    required String patchOut,
    int maxRetries = 3,
    Function(String message, {bool isError})? onProgress,
  }) async {
    int attempt = 0;
    String? lastError;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final metadata = await makeSinglePatch(
          relativePath: relativePath,
          oldFile: oldFile,
          newFile: newFile,
          patchOut: patchOut,
        );

        // 如果成功，返回结果
        if (metadata != null) {
          return metadata;
        }

        // 如果返回 null（文件未变化或新文件），也认为是成功
        return null;
      } catch (e) {
        lastError = e.toString();
        print('处理文件失败 ($attempt/$maxRetries): $relativePath - $e');
        onProgress?.call(
          '⚠️ 处理失败 (尝试 $attempt/$maxRetries): $relativePath',
          isError: true,
        );

        // 如果不是最后一次尝试，等待一小段时间再重试
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          print('重试中... ($attempt/$maxRetries)');
          onProgress?.call(
            '🔄 重试中 ($attempt/$maxRetries): $relativePath',
            isError: false,
          );
        }
      }
    }

    // 所有重试都失败后，返回带错误信息的 FileMetadata
    print('文件处理失败（已重试 $maxRetries 次）: $relativePath - $lastError');
    onProgress?.call(
      '💥 最终失败（已重试 $maxRetries 次）: $relativePath',
      isError: true,
    );
    return FileMetadata(
      relativePath: relativePath,
      newFileSha256: '',
      patchFileSha256: '',
      errorMessage: '处理失败（已重试 $maxRetries 次）: $lastError',
    );
  }

  /// 生成单个补丁文件
  Future<FileMetadata?> makeSinglePatch({
    required String relativePath,
    required String oldFile,
    required String newFile,
    required String patchOut,
  }) async {
    final oldExists = File(oldFile).existsSync();
    final newExists = File(newFile).existsSync();

    if (!newExists) {
      throw Exception('新文件不存在: $newFile');
    }

    // 确保输出目录存在
    final patchFile = File(patchOut);
    await patchFile.parent.create(recursive: true);

    // 如果旧文件不存在，这是一个新文件，需要复制到输出目录
    if (!oldExists) {
      print('新增文件: $relativePath');
      return await _createNewFileMetadata(relativePath, newFile);
    }

    // 检查文件是否真的有变化（SHA256 + 文件大小）
    final oldFileObj = File(oldFile);
    final newFileObj = File(newFile);
    final oldFileSize = await oldFileObj.length();
    final newFileSize = await newFileObj.length();

    // 只有在文件大小不同时才计算 SHA256（性能优化）
    if (oldFileSize == newFileSize) {
      final oldHash = await _calculateSha256(oldFile);
      final newHash = await _calculateSha256(newFile);

      if (oldHash == newHash) {
        print('未变化: $relativePath');
        return null; // 文件没有变化，跳过
      }
    }

    print('发现变化: $relativePath');

    // 执行 xdelta3 生成补丁
    final result = await Process.run(exePath, [
      '-e',
      '-s',
      oldFile,
      newFile,
      patchOut,
    ], runInShell: true);

    if (result.exitCode == 0) {
      return await _createPatchMetadata(
        relativePath: relativePath,
        oldFile: oldFile,
        newFile: newFile,
        patchFile: patchOut,
      );
    } else {
      // xdelta3 执行失败，抛出异常以便重试
      throw Exception(
        'xdelta3 生成补丁失败 (退出码: ${result.exitCode}): ${result.stderr}',
      );
    }
  }

  /// 创建新文件的元数据（将新文件复制到输出目录）
  Future<FileMetadata> _createNewFileMetadata(
    String relativePath,
    String newFile,
  ) async {
    final newFileObj = File(newFile);
    final newFileSize = await newFileObj.length();
    final newFileSha256 = await _calculateSha256(newFile);

    // 复制新文件到输出目录
    final outputFilePath = '$outputPath${Platform.pathSeparator}$relativePath';
    final outputFile = File(outputFilePath);
    await outputFile.parent.create(recursive: true);
    await newFileObj.copy(outputFilePath);

    print('成功复制新增文件: $relativePath');

    return FileMetadata(
      relativePath: relativePath,
      newFileSha256: newFileSha256,
      patchFileSha256: '',
      newFileSizeBytes: newFileSize,
      newFileOnly: true,
    );
  }

  /// 创建补丁文件的元数据
  Future<FileMetadata> _createPatchMetadata({
    required String relativePath,
    required String oldFile,
    required String newFile,
    required String patchFile,
  }) async {
    final oldFileObj = File(oldFile);
    final newFileObj = File(newFile);
    final patchFileObj = File(patchFile);

    final oldFileSize = await oldFileObj.length();
    final newFileSize = await newFileObj.length();
    final patchFileSize = await patchFileObj.length();

    final oldFileSha256 = await _calculateSha256(oldFile);
    final newFileSha256 = await _calculateSha256(newFile);
    final patchFileSha256 = await _calculateSha256(patchFile);

    final compressionRatio = (patchFileSize / newFileSize) * 100;

    return FileMetadata(
      relativePath: relativePath,
      newFileSha256: newFileSha256,
      patchFileSha256: patchFileSha256,
      oldFileSizeBytes: oldFileSize,
      newFileSizeBytes: newFileSize,
      patchFileSizeBytes: patchFileSize,
      oldFileSha256: oldFileSha256,
      compressionRatioPercent: compressionRatio,
    );
  }

  /// 计算文件的 SHA256（在独立 isolate 中执行，避免阻塞 UI）
  Future<String> _calculateSha256(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();

      // 小文件直接计算，大文件使用 compute 在独立线程中计算
      if (fileSize < 10 * 1024 * 1024) {
        // 小于 10MB，直接计算
        final bytes = await file.readAsBytes();
        final digest = sha256.convert(bytes);
        return digest.toString();
      } else {
        // 大于 10MB，使用 compute 在独立 isolate 中计算
        return await compute(_calculateSha256InIsolate, filePath);
      }
    } catch (e) {
      print('计算 SHA256 失败: $e');
      return '';
    }
  }
}

/// 在独立 isolate 中计算 SHA256（顶层函数或静态方法）
String _calculateSha256InIsolate(String filePath) {
  try {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes);
    return digest.toString();
  } catch (e) {
    print('Isolate 中计算 SHA256 失败: $e');
    return '';
  }
}
