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
  /// Returns a record with [ok] and the captured stderr/exception text
  /// (empty on success) so callers can surface the real reason to the UI.
  Future<({bool ok, String error})> encodeFile({
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
  /// Returns a record with [ok] and the captured stderr/exception text
  /// (empty on success) so callers can surface the real reason to the UI.
  ///
  /// Note: 不加 -q，让 xdelta3 在失败时把具体错误（如 header error、
  /// bad input）输出到 stderr — 我们只在 exit != 0 时展示 stderr。
  Future<({bool ok, String error})> decodeFile({
    required String patchFilePath,
    required String oldFilePath,
    required String outputFilePath,
    int flags = 0,
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) async {
    return _run([
      '-f',
      '-d',
      '-s',
      oldFilePath,
      patchFilePath,
      outputFilePath,
    ]);
  }

  /// Run xdelta3.exe with [args]. Returns ok=true on exit code 0;
  /// otherwise ok=false with the merged stderr/stdout text.
  ///
  /// 用 Process.start 拿原始字节，再用多级 fallback 解码 —— 因为
  /// 中文 Windows 上 xdelta3.exe 的 stderr 是 GBK 编码（含中文路径），
  /// 用 utf8 直接解会抛 FormatException 把真正的错误吞掉。
  Future<({bool ok, String error})> _run(List<String> args) async {
    try {
      final exe = locateExe();
      final process = await Process.start(
        exe,
        args,
        runInShell: false,
      );

      final stdoutFuture = process.stdout.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      final stderrFuture = process.stderr.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );

      final exitCode = await process.exitCode;
      final stdoutBytes = await stdoutFuture;
      final stderrBytes = await stderrFuture;

      if (exitCode != 0) {
        final err = _safeDecode(stderrBytes).trim();
        final out = _safeDecode(stdoutBytes).trim();
        final buf = StringBuffer();
        if (err.isNotEmpty) buf.writeln(err);
        if (out.isNotEmpty) buf.writeln(out);
        final msg = 'xdelta3.exe exit=$exitCode: ${buf.toString().trim()}';
        stderr.writeln(msg);
        return (ok: false, error: msg);
      }
      return (ok: true, error: '');
    } catch (e) {
      final msg = 'xdelta3.exe invocation failed: $e';
      stderr.writeln(msg);
      return (ok: false, error: msg);
    }
  }

  /// 多级解码：先 utf8（Linux/Mac），失败 fallback systemEncoding
  /// （中文 Windows = GBK/cp936），再失败用 utf8 allowMalformed 兜底
  /// （无效字节变 U+FFFD，至少不抛异常）。
  String _safeDecode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return systemEncoding.decode(bytes);
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }
}