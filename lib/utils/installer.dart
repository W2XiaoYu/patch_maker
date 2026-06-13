import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:patch_maker/model/manifest_metadata.dart';
import 'package:patch_maker/xdelta3/xdelta3.dart';

class PatchInstaller {
  final String patchDir;
  final String installDir;

  PatchInstaller._({
    required this.patchDir,
    required this.installDir,
  });

  static PatchInstaller? create({
    required String patchDir,
    required String installDir,
  }) {
    return PatchInstaller._(
      patchDir: patchDir,
      installDir: installDir,
    );
  }

  Future<ManifestMetadata?> loadManifest() async {
    final manifestPath = path.join(patchDir, 'manifest.json');
    final file = File(manifestPath);
    if (!file.existsSync()) return null;

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return ManifestMetadata.fromJson(json);
  }

  Future<bool> install({
    required Function(String message, {bool isError}) onProgress,
  }) async {
    final startTime = DateTime.now();

    onProgress('📂 正在读取 manifest.json...', isError: false);
    final manifest = await loadManifest();
    if (manifest == null) {
      onProgress('❌ manifest.json 不存在或格式错误', isError: true);
      return false;
    }

    final files = manifest.files;
    onProgress(
      '✅ 读取成功，共 ${files.length} 个文件需要处理',
      isError: false,
    );

    final tempDir = Directory(
      path.join(installDir, '.patch_install_temp'),
    );
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    int appliedCount = 0;
    int newFileCount = 0;
    int deletedCount = 0;
    int errorCount = 0;

    try {
      for (var i = 0; i < files.length; i++) {
        final fileMeta = files[i];
        final relativePath = fileMeta.relativePath;

        onProgress(
          ' [${i + 1}/${files.length}] 处理: $relativePath',
          isError: false,
        );

        try {
          if (fileMeta.deletedFileOnly == true) {
            final targetFile = File(path.join(installDir, relativePath));
            if (targetFile.existsSync()) {
              await targetFile.delete();
              onProgress(
                '🗑️ [${i + 1}/${files.length}] 已删除: $relativePath',
                isError: false,
              );
            } else {
              onProgress(
                '⏭️ [${i + 1}/${files.length}] 跳过删除(不存在): $relativePath',
                isError: false,
              );
            }
            deletedCount++;
          } else if (fileMeta.newFileOnly == true) {
            final sourceFile = File(path.join(patchDir, relativePath));
            final targetFile = File(path.join(installDir, relativePath));
            await targetFile.parent.create(recursive: true);

            if (sourceFile.existsSync()) {
              await sourceFile.copy(targetFile.path);
              onProgress(
                '➕ [${i + 1}/${files.length}] 新文件: $relativePath',
                isError: false,
              );
              newFileCount++;
            } else {
              onProgress(
                '⚠️ [${i + 1}/${files.length}] 新文件源不存在: $relativePath',
                isError: true,
              );
              errorCount++;
            }
          } else {
            // 补丁文件 — 在 isolate 中用 DLL 解码
            final patchFile = File(
              path.join(patchDir, '$relativePath.patch'),
            );
            final oldFile = File(path.join(installDir, relativePath));

            if (!patchFile.existsSync()) {
              onProgress(
                '❌ [${i + 1}/${files.length}] 补丁文件不存在: $relativePath.patch',
                isError: true,
              );
              errorCount++;
              continue;
            }

            if (!oldFile.existsSync()) {
              onProgress(
                '❌ [${i + 1}/${files.length}] 源文件不存在: $relativePath',
                isError: true,
              );
              errorCount++;
              continue;
            }

            final tempOutput = File(
              path.join(tempDir.path, relativePath),
            );

            final decodeResult = await compute(_decodePatchIsolate, {
              'old_file': oldFile.path,
              'patch_file': patchFile.path,
              'output_file': tempOutput.path,
              'max_output_size': fileMeta.newFileSizeBytes != null
                  ? fileMeta.newFileSizeBytes! + 4096
                  : null,
            });

            if (decodeResult['is_ok'] as bool) {
              final outputSize = decodeResult['output_size'] as int;
              final expectedSize = fileMeta.newFileSizeBytes ?? 0;

              // 验证文件大小
              if (expectedSize > 0 && outputSize != expectedSize) {
                onProgress(
                  '❌ [${i + 1}/${files.length}] 大小不匹配: $relativePath (期望 $expectedSize, 实际 $outputSize)',
                  isError: true,
                );
              }

              // 验证 SHA256
              if (fileMeta.newFileSha256.isNotEmpty) {
                final actualSha256 =
                    decodeResult['output_sha256'] as String;
                if (actualSha256 != fileMeta.newFileSha256) {
                  onProgress(
                    '⚠️ [${i + 1}/${files.length}] SHA256不匹配: $relativePath\n   期望: ${fileMeta.newFileSha256.substring(0, 16)}...\n   实际: ${actualSha256.substring(0, 16)}...\n   补丁: ${patchFile.path}',
                    isError: true,
                  );
                }
              }

              await tempOutput.copy(oldFile.path);
              onProgress(
                '✅ [${i + 1}/${files.length}] 已还原: $relativePath',
                isError: false,
              );
              appliedCount++;
            } else {
              onProgress(
                '❌ [${i + 1}/${files.length}] xdelta3还原失败: $relativePath\n   ${decodeResult['error_message']}',
                isError: true,
              );
              errorCount++;
            }
          }
        } catch (e) {
          onProgress(
            '💥 [${i + 1}/${files.length}] 异常: $relativePath - $e',
            isError: true,
          );
          errorCount++;
        }

        await Future.delayed(Duration.zero);
      }
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

    onProgress('', isError: false);
    onProgress('━━━━━━━━━━━━━━━━━━━━━━━━━━', isError: false);
    onProgress('📦 安装完成！统计信息：', isError: false);
    onProgress('  ✅ 补丁还原: $appliedCount 个', isError: false);
    onProgress('  ➕ 新增文件: $newFileCount 个', isError: false);
    onProgress('  🗑️ 删除文件: $deletedCount 个', isError: false);
    if (errorCount > 0) {
      onProgress('  ❌ 失败: $errorCount 个', isError: true);
    }
    onProgress('  📦 总文件数: ${files.length} 个', isError: false);
    onProgress(
      '  ⏱️ 总用时: ${duration.toStringAsFixed(2)} 秒',
      isError: false,
    );
    onProgress('━━━━━━━━━━━━━━━━━━━━━━━━━━', isError: false);

    return errorCount == 0;
  }
}

// ============================================================
// Isolate 入口（顶层函数）
// ============================================================

/// 在独立 isolate 中完成：流式解码 → 写输出 → 算 SHA256
Future<Map<String, dynamic>> _decodePatchIsolate(Map<String, dynamic> args) async {
  final oldFilePath = args['old_file'] as String;
  final patchFilePath = args['patch_file'] as String;
  final outputFilePath = args['output_file'] as String;

  try {
    final xd3 = Xdelta3();
    try {
      final ok = await xd3.decodeFile(
        patchFilePath: patchFilePath,
        oldFilePath: oldFilePath,
        outputFilePath: outputFilePath,
      );

      if (!ok) {
        return {
          'is_ok': false,
          'error_message': 'xdelta3 流式解码失败',
        };
      }

      final outputSize = File(outputFilePath).lengthSync();
      final outputSha256 = await _fileSha256(outputFilePath);

      return {
        'is_ok': true,
        'output_sha256': outputSha256,
        'output_size': outputSize,
      };
    } finally {
      xd3.close();
    }
  } catch (e) {
    return {
      'is_ok': false,
      'error_message': e.toString(),
    };
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