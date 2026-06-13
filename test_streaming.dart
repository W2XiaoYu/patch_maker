// test_streaming.dart — xdelta3 流式 API 自测
// 用法: dart run test_streaming.dart

import 'dart:io';
import 'lib/xdelta3/xdelta3.dart';

void main() async {
  print('=== xdelta3 流式 API 自测 ===\n');

  final testDir = Directory('${Directory.systemTemp.path}/xd3_test');
  if (testDir.existsSync()) testDir.deleteSync(recursive: true);
  testDir.createSync(recursive: true);

  final oldFile = File('${testDir.path}/old.bin');
  final newFile = File('${testDir.path}/new.bin');
  final patchFile = File('${testDir.path}/output.patch');
  final outFile = File('${testDir.path}/restored.bin');

  // 测试用例
  final tests = [
    {'name': '小文件 (93B)', 'oldSize': 93, 'newSize': 93},
    {'name': '中等文件 (1MB)', 'oldSize': 1024 * 1024, 'newSize': 1024 * 1024 + 500},
    {'name': '大文件 (20MB)', 'oldSize': 20 * 1024 * 1024, 'newSize': 20 * 1024 * 1024 + 4096},
  ];

  int pass = 0, fail = 0;

  for (final test in tests) {
    final name = test['name'] as String;
    final oldSize = test['oldSize'] as int;
    final newSize = test['newSize'] as int;

    print('--- 测试: $name ---');

    // 生成测试数据
    oldFile.writeAsBytesSync(List.generate(oldSize, (i) => (i * 7 + 13) & 0xFF));
    newFile.writeAsBytesSync(List.generate(newSize, (i) => (i * 11 + 37) & 0xFF));

    final xd3 = Xdelta3();
    try {
      // 编码
      final encOk = await xd3.encodeFile(
        newFilePath: newFile.path,
        oldFilePath: oldFile.path,
        outputPatchPath: patchFile.path,
        chunkSize: 8 * 1024 * 1024,
        winsize: 8 * 1024 * 1024,
      );

      if (!encOk) {
        print('  ❌ 编码失败');
        fail++;
        continue;
      }

      final patchSize = patchFile.lengthSync();
      print('  补丁大小: $patchSize bytes (新文件: $newSize bytes)');

      // 解码
      final decOk = await xd3.decodeFile(
        patchFilePath: patchFile.path,
        oldFilePath: oldFile.path,
        outputFilePath: outFile.path,
        chunkSize: 8 * 1024 * 1024,
      );

      if (!decOk) {
        print('  ❌ 解码失败');
        fail++;
        continue;
      }

      // 比较
      final restoredBytes = outFile.readAsBytesSync();
      final expectedBytes = newFile.readAsBytesSync();

      if (restoredBytes.length != expectedBytes.length) {
        print('  ❌ 大小不匹配: 期望 ${expectedBytes.length}, 实际 ${restoredBytes.length} (差 ${restoredBytes.length - expectedBytes.length})');
        fail++;
      } else if (_bytesEqual(restoredBytes, expectedBytes)) {
        print('  ✅ 通过');
        pass++;
      } else {
        print('  ❌ 内容不匹配');
        // 找到第一个不同的位置
        for (int i = 0; i < restoredBytes.length; i++) {
          if (restoredBytes[i] != expectedBytes[i]) {
            print('  第一个差异: 位置 $i, 期望 ${expectedBytes[i]}, 实际 ${restoredBytes[i]}');
            break;
          }
        }
        fail++;
      }
    } finally {
      xd3.close();
    }

    print('');
  }

  print('=== 结果: $pass 通过, $fail 失败 ===');

  // 清理
  testDir.deleteSync(recursive: true);

  exit(fail > 0 ? 1 : 0);
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}