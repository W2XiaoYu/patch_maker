/// xdelta3 — High-level Dart wrapper for Flutter / Dart FFI
///
/// Usage:
/// ```dart
/// import 'xdelta3.dart';
///
/// final xd3 = Xdelta3();
///
/// // Generate delta
/// final result = xd3.encode(input: newBytes, source: oldBytes);
/// if (result.isOk) {
///   final delta = result.data;
/// }
///
/// // Apply delta
/// final restored = xd3.decode(input: delta, source: oldBytes);
/// print(restored.data); // = newBytes
///
/// xd3.close();
/// ```
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'xd3_bindings.dart';
import 'xd3_streaming.dart';

export 'xd3_bindings.dart' show Xd3Flags, Xd3Return;
export 'xd3_streaming.dart';

// ============================================================
// Result type
// ============================================================

/// Result of an encode or decode operation.
class Xd3Result {
  /// Whether the operation succeeded (return code == 0).
  final bool isOk;

  /// Output data: delta bytes (encode) or restored bytes (decode).
  /// Empty on failure.
  final Uint8List data;

  /// Native error code (0 on success).
  final int errorCode;

  /// Human-readable error message. Empty on success.
  final String errorMessage;

  const Xd3Result._({
    required this.isOk,
    required this.data,
    required this.errorCode,
    required this.errorMessage,
  });

  static Xd3Result ok(Uint8List data) => Xd3Result._(
        isOk: true,
        data: data,
        errorCode: 0,
        errorMessage: '',
      );

  static Xd3Result fail(int code, String msg) => Xd3Result._(
        isOk: false,
        data: Uint8List(0),
        errorCode: code,
        errorMessage: msg,
      );
}

// ============================================================
// High-level wrapper
// ============================================================

/// xdelta3 DLL wrapper for Flutter / Dart.
///
/// Generates and applies VCDIFF deltas.
///
/// Example:
/// ```dart
/// final xd3 = Xdelta3();
///
/// final oldFile = File('old.bin').readAsBytesSync();
/// final newFile = File('new.bin').readAsBytesSync();
///
/// final delta = xd3.encode(input: newFile, source: oldFile);
/// File('patch.vcdiff').writeAsBytesSync(delta.data);
///
/// final restored = xd3.decode(input: delta.data, source: oldFile);
/// xd3.close();
/// ```
class Xdelta3 {
  final Xdelta3Native _native;

  /// Loads the xdelta3 DLL.
  ///
  /// [dllPath] — Optional explicit path to the DLL.
  ///   If null, auto-detects based on platform.
  Xdelta3({String? dllPath}) : _native = Xdelta3Native(dllPath: dllPath);

  /// Generate a VCDIFF delta: [input] (new) relative to [source] (old).
  ///
  /// - [input]  New data (the "target").
  /// - [source] Original data. Pass empty for compression-only.
  /// - [flags]  Optional OR-combination of [Xd3Flags] values (default: 0).
  /// - [outputHeadroom] Output buffer is allocated as
  ///   `input.length * outputHeadroom`. Increase if encode fails with
  ///   ENOSPC (return code will be non-zero).
  ///
  /// Returns [Xd3Result] with delta bytes on success.
  Xd3Result encode({
    required Uint8List input,
    Uint8List? source,
    int flags = 0,
    double outputHeadroom = 1.5,
  }) {
    final int inputLen = input.length;
    final int sourceLen = source?.length ?? 0;
    final int availOutput =
        (inputLen * outputHeadroom + 256).ceil().clamp(1024, 0x7FFFFFFF);

    // Allocate native memory
    final inputPtr = calloc<Uint8>(inputLen);
    final sourcePtr = sourceLen > 0 ? calloc<Uint8>(sourceLen) : nullptr;
    final outputPtr = calloc<Uint8>(availOutput);
    final outputSizePtr = calloc<UsizeT>();

    try {
      // Copy input data to native memory
      inputPtr.asTypedList(inputLen).setAll(0, input);
      if (sourceLen > 0) {
        sourcePtr.asTypedList(sourceLen).setAll(0, source!);
      }
      outputSizePtr.value = availOutput;

      final ret = _native.encodeMemory(
        inputPtr,
        inputLen,
        sourcePtr,
        sourceLen,
        outputPtr,
        outputSizePtr,
        availOutput,
        flags,
      );

      if (ret == 0) {
        final used = outputSizePtr.value;
        return Xd3Result.ok(
          Uint8List.fromList(outputPtr.asTypedList(used)),
        );
      }

      return Xd3Result.fail(ret, _strerror(ret));
    } finally {
      calloc.free(inputPtr);
      if (sourceLen > 0) calloc.free(sourcePtr);
      calloc.free(outputPtr);
      calloc.free(outputSizePtr);
    }
  }

  /// Apply a VCDIFF delta to produce the new data.
  ///
  /// - [input]  Delta data (from [encode]).
  /// - [source] Original data used when encoding.
  /// - [flags]  Optional flags (default: 0).
  /// - [maxOutputSize] Maximum output buffer size.
  ///   Defaults to `source.length + input.length + 65536`.
  ///
  /// Returns [Xd3Result] with restored data on success.
  Xd3Result decode({
    required Uint8List input,
    required Uint8List source,
    int flags = 0,
    int? maxOutputSize,
  }) {
    final int inputLen = input.length;
    final int sourceLen = source.length;
    final int defaultOutput = sourceLen + inputLen + 65536;
    final int availOutput =
        (maxOutputSize ?? defaultOutput).clamp(1024, 0x7FFFFFFF);

    final inputPtr = calloc<Uint8>(inputLen);
    final sourcePtr = calloc<Uint8>(sourceLen);
    final outputPtr = calloc<Uint8>(availOutput);
    final outputSizePtr = calloc<UsizeT>();

    try {
      inputPtr.asTypedList(inputLen).setAll(0, input);
      sourcePtr.asTypedList(sourceLen).setAll(0, source);
      outputSizePtr.value = availOutput;

      final ret = _native.decodeMemory(
        inputPtr,
        inputLen,
        sourcePtr,
        sourceLen,
        outputPtr,
        outputSizePtr,
        availOutput,
        flags,
      );

      if (ret == 0) {
        final used = outputSizePtr.value;
        return Xd3Result.ok(
          Uint8List.fromList(outputPtr.asTypedList(used)),
        );
      }

      return Xd3Result.fail(ret, _strerror(ret));
    } finally {
      calloc.free(inputPtr);
      calloc.free(sourcePtr);
      calloc.free(outputPtr);
      calloc.free(outputSizePtr);
    }
  }

  /// Get error description for a return code.
  String _strerror(int code) {
    final ptr = _native.strerror(code);
    return ptr == nullptr ? 'Unknown error: $code' : ptr.toDartString();
  }

  /// Unload the DLL. Call when done to release resources.
  void close() {
    // DynamicLibrary doesn't expose unload; this is a no-op placeholder
    // for future cleanup if needed. The OS will reclaim on process exit.
  }

  // ============================================================
  // Streaming API — for large files
  // ============================================================

  /// Stream-encode [newFilePath] against [oldFilePath], write delta to [outputPatchPath].
  ///
  /// Uses fixed-size buffers, memory usage ≈ chunkSize × 3.
  /// Prefer this for files > 256 MB.
  Future<bool> encodeFile({
    required String newFilePath,
    required String oldFilePath,
    required String outputPatchPath,
    int flags = 0,
    int chunkSize = 8 * 1024 * 1024,
    int winsize = 8 * 1024 * 1024,
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) {
    final encoder = Xd3StreamEncoder(
      _native,
      chunkSize: chunkSize,
      winsize: winsize,
    );
    return encoder.encodeFile(
      newFilePath: newFilePath,
      oldFilePath: oldFilePath,
      outputPatchPath: outputPatchPath,
      flags: flags,
      onProgress: onProgress,
    );
  }

  /// Stream-decode [patchFilePath] using [oldFilePath], write to [outputFilePath].
  ///
  /// Uses fixed-size buffers, memory usage ≈ chunkSize × 3.
  /// Prefer this for files > 256 MB.
  Future<bool> decodeFile({
    required String patchFilePath,
    required String oldFilePath,
    required String outputFilePath,
    int flags = 0,
    int chunkSize = 8 * 1024 * 1024,
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) {
    final decoder = Xd3StreamDecoder(_native, chunkSize: chunkSize);
    return decoder.decodeFile(
      patchFilePath: patchFilePath,
      oldFilePath: oldFilePath,
      outputFilePath: outputFilePath,
      flags: flags,
      onProgress: onProgress,
    );
  }
}
