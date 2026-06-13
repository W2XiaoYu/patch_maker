/// xdelta3 DLL — Low-level FFI bindings for Dart
///
/// Do not use this directly. Use the [Xdelta3] wrapper from xdelta3.dart instead.
library;

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

// ============================================================
// Native type aliases
// ============================================================

// xdelta3 uses uint64_t for usize_t and xoff_t on 64-bit Windows
typedef XoffT = Uint64;
typedef UsizeT = Uint64;

// ============================================================
// Return codes
// ============================================================

abstract final class Xd3Return {
  static const int input = -17703;
  static const int output = -17704;
  static const int getSrcBlk = -17705;
  static const int gotHeader = -17706;
  static const int winStart = -17707;
  static const int winFinish = -17708;
  static const int tooFarBack = -17709;
  static const int internal = -17710;
  static const int invalid = -17711;
  static const int invalidInput = -17712;
  static const int noSecond = -17713;
  static const int unimplemented = -17714;
}

// ============================================================
// Flags
// ============================================================

abstract final class Xd3Flags {
  static const int flush = 1 << 4;
  static const int secDjw = 1 << 5;
  static const int secFgk = 1 << 6;
  static const int secLzma = 1 << 24;
  static const int secNoData = 1 << 7;
  static const int secNoInst = 1 << 8;
  static const int secNoAddr = 1 << 9;
  static const int adler32 = 1 << 10;
  static const int adler32NoVer = 1 << 11;
  static const int noCompress = 1 << 13;
  static const int beGreedy = 1 << 14;
  static const int compLevel1 = 1 << 20;
  static const int compLevel2 = 2 << 20;
  static const int compLevel3 = 3 << 20;
  static const int compLevel6 = 6 << 20;
  static const int compLevel9 = 9 << 20;
}

// ============================================================
// Native function typedefs (C signatures)
// ============================================================

// int xd3_encode_memory(
//   const uint8_t *input,       usize_t input_size,
//   const uint8_t *source,      usize_t source_size,
//   uint8_t *output_buffer,     usize_t *output_size,
//   usize_t avail_output,       int flags)
typedef _EncodeMemoryNative = Int32 Function(
  Pointer<Uint8>,
  UsizeT,
  Pointer<Uint8>,
  UsizeT,
  Pointer<Uint8>,
  Pointer<UsizeT>,
  UsizeT,
  Int32,
);
typedef _EncodeMemoryDart = int Function(
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  Pointer<UsizeT>,
  int,
  int,
);

// int xd3_decode_memory(
//   const uint8_t *input,       usize_t input_size,
//   const uint8_t *source,      usize_t source_size,
//   uint8_t *output_buf,        usize_t *output_size,
//   usize_t avail_output,       int flags)
typedef _DecodeMemoryNative = Int32 Function(
  Pointer<Uint8>,
  UsizeT,
  Pointer<Uint8>,
  UsizeT,
  Pointer<Uint8>,
  Pointer<UsizeT>,
  UsizeT,
  Int32,
);
typedef _DecodeMemoryDart = int Function(
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  Pointer<UsizeT>,
  int,
  int,
);

// const char* xd3_strerror(int ret)
typedef _StrerrorNative = Pointer<Utf8> Function(Int32);
typedef _StrerrorDart = Pointer<Utf8> Function(int);

// ============================================================
// DynamicLibrary loader
// ============================================================

/// Loads the xdelta3 DLL and resolves all native functions.
class Xdelta3Native {
  late final DynamicLibrary lib;

  late final _EncodeMemoryDart encodeMemory;
  late final _DecodeMemoryDart decodeMemory;
  late final _StrerrorDart strerror;

  Xdelta3Native({String? dllPath}) {
    lib = _loadLibrary(dllPath);

    encodeMemory = lib.lookupFunction<_EncodeMemoryNative, _EncodeMemoryDart>(
      'xd3_encode_memory',
    );
    decodeMemory = lib.lookupFunction<_DecodeMemoryNative, _DecodeMemoryDart>(
      'xd3_decode_memory',
    );
    strerror = lib.lookupFunction<_StrerrorNative, _StrerrorDart>(
      'xd3_strerror',
    );
  }

  DynamicLibrary _loadLibrary(String? path) {
    if (path != null) {
      return DynamicLibrary.open(path);
    }

    if (Platform.isWindows) {
      // Flutter Windows: DLL is in same directory as executable
      final exePath = Platform.resolvedExecutable;
      final exeDir = exePath.substring(0, exePath.lastIndexOf('\\'));
      final dllPath = '$exeDir\\xdelta3.dll';
      return DynamicLibrary.open(dllPath);
    }

    if (Platform.isLinux) {
      return DynamicLibrary.open('libxdelta3.so');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libxdelta3.dylib');
    }

    throw UnsupportedError('Unsupported platform');
  }
}
