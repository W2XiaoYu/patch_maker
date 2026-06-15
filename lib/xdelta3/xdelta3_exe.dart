/// xdelta3.exe subprocess wrapper.
///
/// Calls the official xdelta3 CLI binary via Process.run instead of FFI.
/// Each invocation is a fresh process — the OS reclaims all memory on exit,
/// so there is no possibility of internal xdelta3 allocations leaking into
/// the Flutter process.
///
/// The exe is expected to live next to the Flutter app's executable
/// (installed by windows/CMakeLists.txt).
library;

import 'dart:convert';
import 'dart:io';

class Xdelta3Exe {
  static String? _cachedExePath;

  /// Locate xdelta3.exe next to the running executable.
  ///
  /// Throws [FileSystemException] if not found.
  static String locateExe() {
    final cached = _cachedExePath;
    if (cached != null && File(cached).existsSync()) return cached;

    final exeDir = File(Platform.resolvedExecutable).parent;
    final candidates = <String>[
      '${exeDir.path}${Platform.pathSeparator}xdelta3.exe',
      // Debug runs from build/<mode>/ — DLL/EXE live alongside
      '${exeDir.path}${Platform.pathSeparator}xdelta3.exe',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        _cachedExePath = path;
        return path;
      }
    }

    throw FileSystemException(
      'xdelta3.exe not found next to ${Platform.resolvedExecutable}',
      exeDir.path,
    );
  }

  /// Generate a VCDIFF delta: [newFilePath] relative to [oldFilePath],
  /// write to [outputPatchPath].
  ///
  /// Returns true on success, false on error.
  Future<bool> encodeFile({
    required String newFilePath,
    required String oldFilePath,
    required String outputPatchPath,
    int flags = 0,
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) async {
    return _run([
      '-f',
      '-q',
      '-e',
      '-s',
      oldFilePath,
      newFilePath,
      outputPatchPath,
    ]);
  }

  /// Apply [patchFilePath] against [oldFilePath], write to [outputFilePath].
  ///
  /// Returns true on success, false on error.
  Future<bool> decodeFile({
    required String patchFilePath,
    required String oldFilePath,
    required String outputFilePath,
    int flags = 0,
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) async {
    return _run([
      '-f',
      '-q',
      '-d',
      '-s',
      oldFilePath,
      patchFilePath,
      outputFilePath,
    ]);
  }

  /// Run xdelta3.exe with [args], return true on exit code 0.
  Future<bool> _run(List<String> args) async {
    try {
      final exe = locateExe();
      // Drain stderr/stdout so the child can't block on a full pipe.
      // Output is normally empty thanks to -q.
      final result = await Process.run(
        exe,
        args,
        stderrEncoding: utf8,
        stdoutEncoding: utf8,
        runInShell: false,
      );
      if (result.exitCode != 0) {
        stderr.writeln(
          'xdelta3.exe failed (exit ${result.exitCode}): ${result.stderr}',
        );
        return false;
      }
      return true;
    } catch (e) {
      stderr.writeln('xdelta3.exe invocation failed: $e');
      return false;
    }
  }
}