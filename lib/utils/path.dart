import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:patch_maker/model/manifest_metadata.dart';
import 'package:patch_maker/xdelta3/xdelta3_exe.dart';

class PatchUtils {
  final String oldPath;
  final String newPath;
  final String outputPath;

  PatchUtils._({
    required this.oldPath,
    required this.newPath,
    required this.outputPath,
  });

  static PatchUtils? create({
    required String oldPath,
    required String newPath,
    required String outputPath,
  }) {
    return PatchUtils._(
      oldPath: oldPath,
      newPath: newPath,
      outputPath: outputPath,
    );
  }

  /// 生成补丁并返回完整的 manifest
  Future<ManifestMetadata?> generatePatchManifest({
    String newVersionTag = "",
    Function(String message, {bool isError})? onProgress,
  }) async {
    final startTime = DateTime.now();
    final List<FileMetadata> fileResults = [];

    onProgress?.call('📂 正在扫描文件...', isError: false);
    final tasks = await _buildTaskList();
    final newFilesMap = <String, bool>{};

    print('开始生成补丁，共 ${tasks.length} 个文件需要处理...');
    onProgress?.call(
      '✅ 扫描完成，共 ${tasks.length} 个文件需要处理',
      isError: false,
    );

    int patchCount = 0;
    int newFileCount = 0;
    int errorCount = 0;

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

      await Future.delayed(Duration.zero);
    }

    onProgress?.call('🔍 检查已删除的文件...', isError: false);
    int deletedFileCount = 0;
    final deletedFiles = await _findDeletedFiles(newFilesMap);
    for (var deletedMeta in deletedFiles) {
      fileResults.add(deletedMeta);
      deletedFileCount++;
      print('删除文件: ${deletedMeta.relativePath}');
      onProgress?.call(
        '🗑️ 已删除: ${deletedMeta.relativePath}',
        isError: false,
      );
      await Future.delayed(Duration.zero);
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

    onProgress?.call('', isError: false);
    onProgress?.call('━━━━━━━━━━━━━━━━━━━━━━━━━━', isError: false);
    onProgress?.call('📦 处理完成！统计信息：', isError: false);
    onProgress?.call('  ✅ 补丁文件: $patchCount 个', isError: false);
    onProgress?.call('  ➕ 新增文件: $newFileCount 个', isError: false);
    onProgress?.call('  🗑️ 删除文件: $deletedFileCount 个', isError: false);
    if (errorCount > 0) {
      onProgress?.call('  ❌ 失败文件: $errorCount 个', isError: true);
    }
    onProgress?.call(
      '  📦 总文件数: ${fileResults.length} 个',
      isError: false,
    );
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
      patchAlgorithm: 'xdelta3',
      files: fileResults,
    );

    onProgress?.call('💾 正在写入 manifest.json...', isError: false);
    await _writeManifestFile(manifest);
    onProgress?.call('✅ manifest.json 已保存', isError: false);

    return manifest;
  }

  Future<List<FileMetadata>> _findDeletedFiles(
    Map<String, bool> newFilesMap,
  ) async {
    final deletedFiles = <FileMetadata>[];
    final oldDir = Directory(oldPath);

    if (!oldDir.existsSync()) return deletedFiles;

    await for (var entity in oldDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relativePath = entity.path.substring(oldPath.length + 1);
        if (!newFilesMap.containsKey(relativePath)) {
          final sha = await compute(_sha256Isolate, entity.path);
          deletedFiles.add(
            FileMetadata(
              relativePath: relativePath,
              newFileSha256: '',
              patchFileSha256: '',
              oldFileSizeBytes: await entity.length(),
              oldFileSha256: sha,
              deletedFileOnly: true,
            ),
          );
        }
      }
    }

    return deletedFiles;
  }

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

    await for (var entity in newDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relativePath = entity.path.substring(newPath.length + 1);
        tasks.add({
          'relative_path': relativePath,
          'old_full_path':
              '$oldPath${Platform.pathSeparator}$relativePath',
          'new_full_path': entity.path,
          'output_path':
              '$outputPath${Platform.pathSeparator}$relativePath.patch',
        });
      }
    }

    return tasks;
  }

  Future<void> _writeManifestFile(ManifestMetadata manifest) async {
    try {
      final manifestPath =
          '$outputPath${Platform.pathSeparator}manifest.json';
      final manifestFile = File(manifestPath);
      await manifestFile.parent.create(recursive: true);
      final jsonStr =
          JsonEncoder.withIndent('  ').convert(manifest.toJson());
      await manifestFile.writeAsString(jsonStr);
      print('Manifest 已写入: $manifestPath');
    } catch (e) {
      print('写入 manifest 失败: $e');
    }
  }

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
        return metadata;
      } catch (e) {
        lastError = e.toString();
        print('处理文件失败 ($attempt/$maxRetries): $relativePath - $e');
        onProgress?.call(
          '⚠️ 处理失败 (尝试 $attempt/$maxRetries): $relativePath',
          isError: true,
        );
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          onProgress?.call(
            '🔄 重试中 ($attempt/$maxRetries): $relativePath',
            isError: false,
          );
        }
      }
    }

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

  /// 生成单个补丁文件（在 isolate 中执行，不阻塞 UI）
  Future<FileMetadata?> makeSinglePatch({
    required String relativePath,
    required String oldFile,
    required String newFile,
    required String patchOut,
  }) async {
    final result = await compute(_makePatchIsolate, {
      'relative_path': relativePath,
      'old_file': oldFile,
      'new_file': newFile,
      'patch_out': patchOut,
      'output_path': outputPath,
    });

    final action = result['action'] as String;

    switch (action) {
      case 'unchanged':
        return null;
      case 'new_file':
        return FileMetadata(
          relativePath: relativePath,
          newFileSha256: result['new_file_sha256'] as String,
          patchFileSha256: '',
          newFileSizeBytes: result['new_file_size_bytes'] as int,
          newFileOnly: true,
          newFilePath: newFile,
          oldFilePath: oldFile,
        );
      case 'patch':
        return FileMetadata(
          relativePath: relativePath,
          newFileSha256: result['new_file_sha256'] as String,
          patchFileSha256: result['patch_file_sha256'] as String,
          oldFileSizeBytes: result['old_file_size_bytes'] as int,
          newFileSizeBytes: result['new_file_size_bytes'] as int,
          patchFileSizeBytes: result['patch_file_size_bytes'] as int,
          oldFileSha256: result['old_file_sha256'] as String,
          compressionRatioPercent: result['compression_ratio_percent'] as double,
          oldFilePath: result['old_file_path'] as String,
          newFilePath: result['new_file_path'] as String,
          patchFilePath: result['patch_file_path'] as String,
          generationTime: result['generation_time'] as String,
        );
      default:
        throw Exception(result['error_message'] as String);
    }
  }
}

// ============================================================
// Isolate 入口（顶层函数）
// ============================================================

/// 在独立 isolate 中完成：比较 → 流式编码 → 写补丁 → 算哈希
Future<Map<String, dynamic>> _makePatchIsolate(Map<String, String> args) async {
  final oldFileStr = args['old_file']!;
  final newFileStr = args['new_file']!;
  final patchOutStr = args['patch_out']!;
  final outputPath = args['output_path']!;
  final relativePath = args['relative_path']!;

  try {
    final newFile = File(newFileStr);
    if (!newFile.existsSync()) {
      return {'action': 'error', 'error_message': '新文件不存在: $newFileStr'};
    }

    final oldFile = File(oldFileStr);
    final newFileSize = newFile.lengthSync();

    // 旧文件不存在 → 新文件，复制到输出目录
    if (!oldFile.existsSync()) {
      final sha = await _fileSha256(newFileStr);
      final dest = '$outputPath${Platform.pathSeparator}$relativePath';
      File(dest).parent.createSync(recursive: true);
      newFile.copySync(dest);
      return {
        'action': 'new_file',
        'new_file_sha256': sha,
        'new_file_size_bytes': newFileSize,
      };
    }

    final oldFileSize = oldFile.lengthSync();

    // 大小相同时比较 SHA256 判断是否变化（分块计算，不全载入内存）
    if (oldFileSize == newFileSize) {
      final oldSha = await _fileSha256(oldFileStr);
      final newSha = await _fileSha256(newFileStr);
      if (oldSha == newSha) {
        return {'action': 'unchanged'};
      }
    }

    // subprocess 编码（在独立进程内执行，避免 FFI 内存问题）
    final patchFile = File(patchOutStr);
    patchFile.parent.createSync(recursive: true);

    final result = await Xdelta3Exe().encodeFile(
      newFilePath: newFileStr,
      oldFilePath: oldFileStr,
      outputPatchPath: patchOutStr,
    );

    if (!result.ok) {
      return {
        'action': 'error',
        'error_message': 'xdelta3.exe 编码失败：${result.error}',
      };
    }

    final patchFileSize = patchFile.lengthSync();
    final newSha = await _fileSha256(newFileStr);
    final oldSha = await _fileSha256(oldFileStr);
    final patchSha = await _fileSha256(patchOutStr);

    return {
      'action': 'patch',
      'new_file_sha256': newSha,
      'patch_file_sha256': patchSha,
      'old_file_size_bytes': oldFileSize,
      'new_file_size_bytes': newFileSize,
      'patch_file_size_bytes': patchFileSize,
      'old_file_sha256': oldSha,
      'compression_ratio_percent': (patchFileSize / newFileSize) * 100,
      'old_file_path': oldFileStr,
      'new_file_path': newFileStr,
      'patch_file_path': patchOutStr,
      'generation_time': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    return {'action': 'error', 'error_message': e.toString()};
  }
}

/// 分块计算文件 SHA256（不全载入内存）
Future<String> _fileSha256(String filePath) async {
  return compute(_fileSha256Isolate, filePath);
}

/// Isolate 中分块计算 SHA256
String _fileSha256Isolate(String filePath) {
  try {
    final file = File(filePath);
    if (!file.existsSync()) return '';
    final raf = file.openSync();
    try {
      final sink = _DigestSink();
      final input = sha256.startChunkedConversion(sink);
      final buf = Uint8List(64 * 1024 * 1024);
      while (true) {
        final n = raf.readIntoSync(buf);
        if (n == 0) break;
        input.add(Uint8List.sublistView(buf, 0, n));
      }
      input.close();
      return sink.digest.toString();
    } finally {
      raf.closeSync();
    }
  } catch (_) {
    return '';
  }
}

class _DigestSink implements Sink<Digest> {
  Digest digest = Digest([]);
  @override
  void add(Digest data) => digest = data;
  @override
  void close() {}
}

/// 在 isolate 中计算文件 SHA256（已废弃，保留兼容）
String _sha256Isolate(String filePath) {
  try {
    return sha256.convert(File(filePath).readAsBytesSync()).toString();
  } catch (e) {
    return '';
  }
}