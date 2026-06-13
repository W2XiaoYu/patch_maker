/// xdelta3 streaming encoder/decoder for large files
///
/// Processes files in fixed-size chunks, keeping memory usage constant
/// regardless of file size.  Use for files > 256 MB.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'xd3_bindings.dart' show Xdelta3Native, Xd3Flags;
import 'xd3_stream_bindings.dart';

// ============================================================
// Constants
// ============================================================

const int _defaultChunkSize = 64 * 1024 * 1024; // 64 MB
const int _defaultWinsize = 64 * 1024 * 1024; // 64 MB

// ============================================================
// Stream encoder
// ============================================================

/// Streaming VCDIFF encoder — generates a .patch file from old + new files.
///
/// Memory usage ≈ chunkSize × 3 (input buffer + source block + output).
class Xd3StreamEncoder {
  final Xd3StreamNative _native;
  final int chunkSize;
  final int winsize;

  Xd3StreamEncoder(Xdelta3Native baseNative, {int? chunkSize, int? winsize})
      : _native = Xd3StreamNative(baseNative),
        chunkSize = chunkSize ?? _defaultChunkSize,
        winsize = winsize ?? _defaultWinsize;

  /// Encode [newFilePath] against [oldFilePath], write delta to [outputPatchPath].
  ///
  /// Returns true on success, false on error.
  Future<bool> encodeFile({
    required String newFilePath,
    required String oldFilePath,
    required String outputPatchPath,
    int flags = 0,
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) async {
    final newFile = File(newFilePath);
    if (!newFile.existsSync()) return false;

    final newFileSize = await newFile.length();
    final oldFile = File(oldFilePath);
    final hasSource = oldFile.existsSync();
    final oldFileSize = hasSource ? await oldFile.length() : 0;

    // Allocate stream, config, source structs
    final streamPtr = calloc<Uint8>(Xd3Sizes.stream);
    final configPtr = calloc<Uint8>(Xd3Sizes.config);
    final sourcePtr = hasSource ? calloc<Uint8>(Xd3Sizes.source) : nullptr;
    final inputBuf = calloc<Uint8>(chunkSize);
    final srcBuf = hasSource ? calloc<Uint8>(chunkSize) : nullptr;

    // getblk callback (if source exists)
    NativeCallable<Xd3GetblkNative>? getblkCallable;
    RandomAccessFile? oldRaf;

    try {
      // Zero-init structs (calloc already zeros)
      xd3ConfigInit(configPtr, winsize: winsize, flags: flags);

      final ret = _native.configStream(streamPtr, configPtr);
      if (ret != 0) {
        stderr.writeln('xd3_config_stream failed: $ret ${xd3GetMsg(streamPtr)}');
        return false;
      }

      // Setup source
      if (hasSource) {
        xd3SourceInit(sourcePtr, chunkSize);
        oldRaf = oldFile.openSync(mode: FileMode.read);

        // Create getblk callback
        getblkCallable = NativeCallable<Xd3GetblkNative>.isolateLocal(
          (Pointer<Uint8> stream, Pointer<Uint8> source, int blkno) {
            return _handleGetblk(source, srcBuf, oldRaf!, blkno, oldFileSize, chunkSize);
          },
          exceptionalReturn: -1,
        );

        // Set getblk in config — but config was already copied to stream.
        // Set it directly in source instead: we handle XD3_GETSRCBLK manually.
        // Actually set getblk function pointer on the stream struct directly.
        _writeGetblkOnStream(streamPtr, getblkCallable);

        final srcRet = _native.setSourceAndSize(
          streamPtr, sourcePtr, oldFileSize,
        );
        if (srcRet != 0 && srcRet != Xd3StreamReturn.getSrcBlk) {
          stderr.writeln('xd3_set_source failed: $srcRet ${xd3GetMsg(streamPtr)}');
          return false;
        }
      }

      // Open files
      final newRaf = newFile.openSync(mode: FileMode.read);
      final outFile = File(outputPatchPath);
      await outFile.parent.create(recursive: true);
      final outRaf = outFile.openSync(mode: FileMode.write);

      try {
        int totalRead = 0;
        int totalWritten = 0;
        int outputCount = 0;
        bool allInputFed = false;
        bool needInput = true;
        int originalFlags = flags;

        while (true) {
          // Feed input chunk ONLY when library asks for it
          if (needInput && !allInputFed) {
            final bytesRead = newRaf.readIntoSync(inputBuf.asTypedList(chunkSize));
            totalRead += bytesRead;

            if (bytesRead == 0) {
              // All input consumed — flush buffered data.
              // Must zero avail_in so the library doesn't re-buffer stale input.
              allInputFed = true;
              xd3SetInput(streamPtr, inputBuf, 0);
              xd3SetFlags(streamPtr, originalFlags | Xd3Flags.flush);
            } else {
              xd3SetInput(streamPtr, inputBuf, bytesRead);
              onProgress?.call(totalRead, newFileSize);
            }
            needInput = false;
          }

          // Process
          final processRet = _native.encodeInput(streamPtr);

          if (processRet == Xd3StreamReturn.output) {
            // Write output
            final outPtr = xd3GetOutputPtr(streamPtr);
            final outLen = xd3GetOutputLen(streamPtr);
            outputCount++;
            totalWritten += outLen;
            if (outLen > 0) {
              outRaf.writeFromSync(outPtr.asTypedList(outLen));
            }
            xd3ConsumeOutput(streamPtr);
            continue;
          }

          if (processRet == Xd3StreamReturn.input) {
            needInput = true;
            if (allInputFed) {
              // No more input available, try close
              break;
            }
            continue;
          }

          if (processRet == Xd3StreamReturn.getSrcBlk) {
            // Should be handled by getblk callback.
            // If callback wasn't set, handle manually.
            if (getblkCallable == null) {
              final blkno = xd3SourceGetRequestedBlkno(sourcePtr);
              _handleGetblk(sourcePtr, srcBuf, oldRaf!, blkno, oldFileSize, chunkSize);
            }
            continue;
          }

          if (processRet == Xd3StreamReturn.winStart ||
              processRet == Xd3StreamReturn.winFinish) {
            continue;
          }

          if (processRet == 0) {
            break;
          }

          // Error
          stderr.writeln('xd3_encode_input error: $processRet ${xd3GetMsg(streamPtr)}');
          return false;
        }

        // Close stream — may produce final output (multiple windows)
        var closeRet = _native.closeStream(streamPtr);
        while (closeRet == Xd3StreamReturn.output) {
          final outPtr = xd3GetOutputPtr(streamPtr);
          final outLen = xd3GetOutputLen(streamPtr);
          outputCount++;
          totalWritten += outLen;
          if (outLen > 0) {
            outRaf.writeFromSync(outPtr.asTypedList(outLen));
          }
          xd3ConsumeOutput(streamPtr);
          closeRet = _native.encodeInput(streamPtr);
        }

        stderr.writeln('[ENC] input=$totalRead output×$outputCount=$totalWritten patch=${File(outputPatchPath).lengthSync()} close=$closeRet');
        return true;
      } finally {
        newRaf.closeSync();
        outRaf.closeSync();
      }
    } finally {
      getblkCallable?.close();
      oldRaf?.closeSync();
      calloc.free(streamPtr);
      calloc.free(configPtr);
      if (sourcePtr != nullptr) calloc.free(sourcePtr);
      calloc.free(inputBuf);
      if (srcBuf != nullptr) calloc.free(srcBuf);
    }
  }

  int _handleGetblk(
    Pointer<Uint8> source,
    Pointer<Uint8> srcBuf,
    RandomAccessFile raf,
    int blkno,
    int fileSize,
    int blksize,
  ) {
    final offset = blkno * blksize;
    if (offset >= fileSize) return -1;

    final remaining = fileSize - offset;
    final toRead = remaining < blksize ? remaining : blksize;

    raf.setPositionSync(offset);
    final bytesRead = raf.readIntoSync(srcBuf.asTypedList(toRead));
    xd3SourceSetBlock(source, srcBuf, bytesRead, blkno);
    return 0;
  }

  void _writeGetblkOnStream(
    Pointer<Uint8> stream,
    NativeCallable<Xd3GetblkNative> callable,
  ) {
    // Write getblk function pointer at stream offset 120
    _writePtr(stream, Xd3StreamOffsets.getblk, callable.nativeFunction);
  }
}

// ============================================================
// Stream decoder
// ============================================================

/// Streaming VCDIFF decoder — applies a .patch file to produce the restored file.
class Xd3StreamDecoder {
  final Xd3StreamNative _native;
  final int chunkSize;

  Xd3StreamDecoder(Xdelta3Native baseNative, {int? chunkSize})
      : _native = Xd3StreamNative(baseNative),
        chunkSize = chunkSize ?? _defaultChunkSize;

  /// Decode [patchFilePath] using source [oldFilePath], write to [outputFilePath].
  ///
  /// Returns true on success, false on error.
  Future<bool> decodeFile({
    required String patchFilePath,
    required String oldFilePath,
    required String outputFilePath,
    int flags = 0,
    void Function(int doneBytes, int totalBytes)? onProgress,
  }) async {
    final patchFile = File(patchFilePath);
    if (!patchFile.existsSync()) return false;

    final oldFile = File(oldFilePath);
    if (!oldFile.existsSync()) return false;

    final patchSize = await patchFile.length();
    final oldFileSize = await oldFile.length();

    final streamPtr = calloc<Uint8>(Xd3Sizes.stream);
    final configPtr = calloc<Uint8>(Xd3Sizes.config);
    final sourcePtr = calloc<Uint8>(Xd3Sizes.source);
    final inputBuf = calloc<Uint8>(chunkSize);
    final srcBuf = calloc<Uint8>(chunkSize);

    NativeCallable<Xd3GetblkNative>? getblkCallable;
    RandomAccessFile? oldRaf;

    try {
      xd3ConfigInit(configPtr, flags: flags);

      final ret = _native.configStream(streamPtr, configPtr);
      if (ret != 0) {
        stderr.writeln('xd3_config_stream failed: $ret ${xd3GetMsg(streamPtr)}');
        return false;
      }

      // Setup source
      xd3SourceInit(sourcePtr, chunkSize);
      oldRaf = oldFile.openSync(mode: FileMode.read);

      getblkCallable = NativeCallable<Xd3GetblkNative>.isolateLocal(
        (Pointer<Uint8> stream, Pointer<Uint8> source, int blkno) {
          final offset = blkno * chunkSize;
          if (offset >= oldFileSize) return -1;
          final remaining = oldFileSize - offset;
          final toRead = remaining < chunkSize ? remaining : chunkSize;
          final raf = oldRaf!;
          raf.setPositionSync(offset);
          final bytesRead = raf.readIntoSync(srcBuf.asTypedList(toRead));
          xd3SourceSetBlock(source, srcBuf, bytesRead, blkno);
          return 0;
        },
        exceptionalReturn: -1,
      );

      _writePtr(streamPtr, Xd3StreamOffsets.getblk, getblkCallable.nativeFunction);

      _native.setSourceAndSize(streamPtr, sourcePtr, oldFileSize);

      // Open files
      final patchRaf = patchFile.openSync(mode: FileMode.read);
      final outFile = File(outputFilePath);
      await outFile.parent.create(recursive: true);
      final outRaf = outFile.openSync(mode: FileMode.write);

      try {
        int totalRead = 0;
        int totalWritten = 0;
        int outputCount = 0;
        bool allInputFed = false;
        bool needInput = true;

        while (true) {
          // Feed input chunk ONLY when library asks for it
          if (needInput && !allInputFed) {
            final bytesRead = patchRaf.readIntoSync(inputBuf.asTypedList(chunkSize));
            totalRead += bytesRead;

            if (bytesRead == 0) {
              // No more input — zero avail_in to avoid re-buffering stale data.
              allInputFed = true;
              xd3SetInput(streamPtr, inputBuf, 0);
              xd3SetFlags(streamPtr, flags | Xd3Flags.flush);
            } else {
              xd3SetInput(streamPtr, inputBuf, bytesRead);
              onProgress?.call(totalRead, patchSize);
            }
            needInput = false;
          }

          final processRet = _native.decodeInput(streamPtr);

          if (processRet == Xd3StreamReturn.output) {
            final outPtr = xd3GetOutputPtr(streamPtr);
            final outLen = xd3GetOutputLen(streamPtr);
            outputCount++;
            totalWritten += outLen;
            if (outLen > 0) {
              outRaf.writeFromSync(outPtr.asTypedList(outLen));
            }
            xd3ConsumeOutput(streamPtr);
            continue;
          }

          if (processRet == Xd3StreamReturn.input) {
            needInput = true;
            if (allInputFed) break;
            continue;
          }

          if (processRet == Xd3StreamReturn.getSrcBlk) {
            // Handled by getblk callback
            continue;
          }

          if (processRet == Xd3StreamReturn.gotHeader ||
              processRet == Xd3StreamReturn.winStart ||
              processRet == Xd3StreamReturn.winFinish) {
            continue;
          }

          if (processRet == 0) break;

          stderr.writeln('xd3_decode_input error: $processRet ${xd3GetMsg(streamPtr)}');
          return false;
        }

        // Close — may produce final output (multiple windows)
        var closeRet = _native.closeStream(streamPtr);
        while (closeRet == Xd3StreamReturn.output) {
          final outPtr = xd3GetOutputPtr(streamPtr);
          final outLen = xd3GetOutputLen(streamPtr);
          outputCount++;
          totalWritten += outLen;
          if (outLen > 0) {
            outRaf.writeFromSync(outPtr.asTypedList(outLen));
          }
          xd3ConsumeOutput(streamPtr);
          closeRet = _native.decodeInput(streamPtr);
        }

        stderr.writeln('[DEC] patch=$totalRead output×$outputCount=$totalWritten close=$closeRet');
        return true;
      } finally {
        patchRaf.closeSync();
        outRaf.closeSync();
      }
    } finally {
      getblkCallable?.close();
      oldRaf?.closeSync();
      calloc.free(streamPtr);
      calloc.free(configPtr);
      calloc.free(sourcePtr);
      calloc.free(inputBuf);
      calloc.free(srcBuf);
    }
  }
}

void _writePtr<T extends NativeType>(Pointer<Uint8> base, int offset, Pointer<T> value) {
  (base.cast<Pointer<T>>() + (offset ~/ 8)).value = value;
}
