import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Common {
  static Future<String?> getRenderUpdaterPath({required String exeName}) async {
    if (kDebugMode) {
      final currentDir = Directory.current.path;
      final exeFilePath = path.join(currentDir, 'exe', exeName);
      final exeFile = File(exeFilePath);
      if (!exeFile.existsSync()) {
        if (kDebugMode) {
          print('$exeName 不存在');
        }
        return null;
      }
      return exeFile.path;
    } else {
      final Directory supportDir = await getApplicationSupportDirectory();
      final String updaterName = "patch_maker_2026-01-04.exe";
      final String assetKey = 'exe/$exeName';
      final String localPath = path.join(supportDir.path, updaterName);
      final File localFile = File(localPath);

      final ByteData data = await rootBundle.load(assetKey);
      final List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await localFile.writeAsBytes(bytes, flush: true);
      return localPath;
    }
  }

  static String? get7ZipPath() {
    final runtimePath = path.join(
      File(Platform.resolvedExecutable).parent.path,
      'resources',
      '7z.exe',
    );
    final runtimeFile = File(runtimePath);
    if (runtimeFile.existsSync()) {
      return runtimeFile.path;
    }

    if (kDebugMode) {
      final projectPath = path.join(
        Directory.current.path,
        'windows',
        'runner',
        'resources',
        '7z.exe',
      );
      final projectFile = File(projectPath);
      if (projectFile.existsSync()) {
        return projectFile.path;
      }
    }

    debugPrint('7z.exe 不存在');
    return null;
  }
}
