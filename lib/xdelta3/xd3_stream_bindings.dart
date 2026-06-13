/// xdelta3 streaming API — Low-level FFI bindings
///
/// Do not use directly. Use [Xd3StreamEncoder] / [Xd3StreamDecoder]
/// from xd3_streaming.dart instead.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'xd3_bindings.dart' show Xdelta3Native, Xd3Return;
// ignore: unused_import used for native type access


// ============================================================
// Stream return codes (reuse Xd3Return values)
// ============================================================

abstract final class Xd3StreamReturn {
  static const int input = Xd3Return.input;       // -17703  need more input
  static const int output = Xd3Return.output;     // -17704  have output
  static const int getSrcBlk = Xd3Return.getSrcBlk; // -17705  need source block
  static const int gotHeader = Xd3Return.gotHeader; // -17706  (decode) got header
  static const int winStart = Xd3Return.winStart;   // -17707  window start
  static const int winFinish = Xd3Return.winFinish; // -17708  window finished
  static const int internal = Xd3Return.internal;   // -17710  internal error
  static const int invalid = Xd3Return.invalid;     // -17711  invalid config
  static const int invalidInput = Xd3Return.invalidInput; // -17712
  static const int noSecond = Xd3Return.noSecond;         // -17713
  static const int unimplemented = Xd3Return.unimplemented; // -17714
}

// ============================================================
// xd3_stream field offsets (verified from xdelta3.h v3.1.0)
// usize_t = uint64, xoff_t = uint64, x86_64 Windows
// ============================================================

abstract final class Xd3StreamOffsets {
  static const int nextIn = 0;    // const uint8_t* (8 bytes)
  static const int availIn = 8;   // usize_t        (8 bytes)
  static const int totalIn = 16;  // xoff_t         (8 bytes)
  static const int nextOut = 24;  // uint8_t*       (8 bytes)
  static const int availOut = 32; // usize_t        (8 bytes)
  static const int spaceOut = 40; // usize_t        (8 bytes)
  static const int currentWindow = 48; // xoff_t    (8 bytes)
  static const int totalOut = 56;    // xoff_t      (8 bytes)
  static const int msg = 64;         // const char* (8 bytes)
  static const int src = 72;         // xd3_source* (8 bytes)
  static const int winsize = 80;     // usize_t     (8 bytes)
  static const int sprevsz = 88;     // usize_t     (8 bytes)
  static const int sprevmask = 96;   // usize_t     (8 bytes)
  static const int ioptSize = 104;   // usize_t     (8 bytes)
  static const int ioptUnlimited = 112; // usize_t  (8 bytes)
  static const int getblk = 120;     // function ptr (8 bytes)
  static const int alloc = 128;      // function ptr (8 bytes)
  static const int free_ = 136;      // function ptr (8 bytes)
  static const int opaque = 144;     // void*        (8 bytes)
  static const int flags = 152;      // uint32_t     (4 bytes)
}

// ============================================================
// xd3_source field offsets (v3.1.0 — no size field)
// ============================================================

abstract final class Xd3SourceOffsets {
  static const int blksize = 0;     // usize_t        (8 bytes)
  static const int name = 8;        // const char*    (8 bytes)
  static const int ioh = 16;        // void*          (8 bytes)
  static const int maxWinsize = 24; // xoff_t         (8 bytes)
  static const int curblkno = 32;   // xoff_t         (8 bytes) — getblk sets
  static const int onblk = 40;      // usize_t        (8 bytes) — getblk sets
  static const int curblk = 48;     // const uint8_t* (8 bytes) — getblk sets
  static const int srclen = 56;     // usize_t        (8 bytes) — xd3 sets
  static const int srcbase = 64;    // xoff_t         (8 bytes) — xd3 sets
  static const int shiftby = 72;    // usize_t        (8 bytes)
  static const int maskby = 80;     // usize_t        (8 bytes)
  static const int cpyoffBlocks = 88; // xoff_t       (8 bytes)
  static const int cpyoffBlkoff = 96; // usize_t      (8 bytes)
  static const int getblkno = 104;    // xoff_t       (8 bytes) — xd3 sets
  static const int maxBlkno = 112;    // xoff_t       (8 bytes)
  static const int onlastblk = 120;   // usize_t      (8 bytes)
  static const int eofKnown = 128;    // int           (4 bytes)
}

// ============================================================
// xd3_config field offsets
// ============================================================

abstract final class Xd3ConfigOffsets {
  static const int winsize = 0;    // usize_t       (8 bytes)
  static const int sprevsz = 8;    // usize_t       (8 bytes)
  static const int ioptSize = 16;  // usize_t       (8 bytes)
  static const int getblk = 24;    // function ptr  (8 bytes)
  static const int alloc = 32;     // function ptr  (8 bytes)
  static const int freef = 40;     // function ptr  (8 bytes)
  static const int opaque = 48;    // void*         (8 bytes)
  static const int flags = 56;     // uint32_t      (4 bytes)
}

// ============================================================
// Struct sizes (over-allocated for safety)
// ============================================================

abstract final class Xd3Sizes {
  static const int stream = 8192;  // xd3_stream is ~800-1000 bytes
  static const int source = 256;   // xd3_source is ~136 bytes
  static const int config = 1024;  // xd3_config is ~200+ bytes
}

// ============================================================
// Native function typedefs
// ============================================================

typedef _ConfigStreamNative = Int32 Function(
  Pointer<Uint8>, Pointer<Uint8>);
typedef _ConfigStreamDart = int Function(
  Pointer<Uint8>, Pointer<Uint8>);

typedef _SetSourceNative = Int32 Function(
  Pointer<Uint8>, Pointer<Uint8>);
typedef _SetSourceDart = int Function(
  Pointer<Uint8>, Pointer<Uint8>);

typedef _SetSourceAndSizeNative = Int32 Function(
  Pointer<Uint8>, Pointer<Uint8>, Uint64);
typedef _SetSourceAndSizeDart = int Function(
  Pointer<Uint8>, Pointer<Uint8>, int);

typedef _EncodeInputNative = Int32 Function(Pointer<Uint8>);
typedef _EncodeInputDart = int Function(Pointer<Uint8>);

typedef _DecodeInputNative = Int32 Function(Pointer<Uint8>);
typedef _DecodeInputDart = int Function(Pointer<Uint8>);

typedef _CloseStreamNative = Int32 Function(Pointer<Uint8>);
typedef _CloseStreamDart = int Function(Pointer<Uint8>);

typedef _AbortStreamNative = Void Function(Pointer<Uint8>);
typedef _AbortStreamDart = void Function(Pointer<Uint8>);

typedef _FreeStreamNative = Void Function(Pointer<Uint8>);
typedef _FreeStreamDart = void Function(Pointer<Uint8>);

typedef _GetAppheaderNative = Int32 Function(
  Pointer<Uint8>, Pointer<Pointer<Uint8>>, Pointer<Uint64>);
typedef _GetAppheaderDart = int Function(
  Pointer<Uint8>, Pointer<Pointer<Uint8>>, Pointer<Uint64>);

// getblk callback: int fn(xd3_stream*, xd3_source*, xoff_t blkno)
typedef Xd3GetblkNative = Int32 Function(
  Pointer<Uint8>, Pointer<Uint8>, Uint64);
typedef Xd3GetblkDart = int Function(
  Pointer<Uint8>, Pointer<Uint8>, int);

// ============================================================
// Streaming FFI loader
// ============================================================

/// Resolves streaming API functions from the xdelta3 DLL.
class Xd3StreamNative {
  late final _ConfigStreamDart configStream;
  late final _SetSourceDart setSource;
  late final _SetSourceAndSizeDart setSourceAndSize;
  late final _EncodeInputDart encodeInput;
  late final _DecodeInputDart decodeInput;
  late final _CloseStreamDart closeStream;
  late final _AbortStreamDart abortStream;
  late final _FreeStreamDart freeStream;
  late final _GetAppheaderDart getAppheader;

  Xd3StreamNative(Xdelta3Native native) {
    final lib = native.lib;

    configStream = lib.lookupFunction<_ConfigStreamNative, _ConfigStreamDart>(
      'xd3_config_stream',
    );
    setSource = lib.lookupFunction<_SetSourceNative, _SetSourceDart>(
      'xd3_set_source',
    );
    setSourceAndSize =
        lib.lookupFunction<_SetSourceAndSizeNative, _SetSourceAndSizeDart>(
      'xd3_set_source_and_size',
    );
    encodeInput = lib.lookupFunction<_EncodeInputNative, _EncodeInputDart>(
      'xd3_encode_input',
    );
    decodeInput = lib.lookupFunction<_DecodeInputNative, _DecodeInputDart>(
      'xd3_decode_input',
    );
    closeStream = lib.lookupFunction<_CloseStreamNative, _CloseStreamDart>(
      'xd3_close_stream',
    );
    abortStream = lib.lookupFunction<_AbortStreamNative, _AbortStreamDart>(
      'xd3_abort_stream',
    );
    freeStream = lib.lookupFunction<_FreeStreamNative, _FreeStreamDart>(
      'xd3_free_stream',
    );
    getAppheader = lib.lookupFunction<_GetAppheaderNative, _GetAppheaderDart>(
      'xd3_get_appheader',
    );
  }
}

// ============================================================
// Helper: read/write struct fields via pointer arithmetic
// ============================================================

/// Read a Pointer<T> from a byte offset in a struct.
Pointer<T> _readPtr<T extends NativeType>(Pointer<Uint8> base, int offset) {
  return (base.cast<Pointer<T>>() + (offset ~/ 8)).value;
}

/// Write a Pointer<T> to a byte offset in a struct.
void _writePtr<T extends NativeType>(Pointer<Uint8> base, int offset, Pointer<T> value) {
  (base.cast<Pointer<T>>() + (offset ~/ 8)).value = value;
}

/// Read a uint64 from a byte offset.
int _readU64(Pointer<Uint8> base, int offset) {
  return (base.cast<Uint64>() + (offset ~/ 8)).value;
}

/// Write a uint64 to a byte offset.
void _writeU64(Pointer<Uint8> base, int offset, int value) {
  (base.cast<Uint64>() + (offset ~/ 8)).value = value;
}

/// Read a uint32 from a byte offset.
int _readU32(Pointer<Uint8> base, int offset) {
  return (base.cast<Uint32>() + (offset ~/ 4)).value;
}

/// Write a uint32 to a byte offset.
void _writeU32(Pointer<Uint8> base, int offset, int value) {
  (base.cast<Uint32>() + (offset ~/ 4)).value = value;
}

// ============================================================
// Stream helpers (equivalent to inline functions in xdelta3.h)
// ============================================================

/// Equivalent to xd3_avail_input: set input data on the stream.
void xd3SetInput(Pointer<Uint8> stream, Pointer<Uint8> data, int len) {
  _writePtr(stream, Xd3StreamOffsets.nextIn, data);
  _writeU64(stream, Xd3StreamOffsets.availIn, len);
}

/// Equivalent to xd3_consume_output: mark output as consumed.
void xd3ConsumeOutput(Pointer<Uint8> stream) {
  _writeU64(stream, Xd3StreamOffsets.availOut, 0);
}

/// Read output pointer from stream.
Pointer<Uint8> xd3GetOutputPtr(Pointer<Uint8> stream) {
  return _readPtr(stream, Xd3StreamOffsets.nextOut);
}

/// Read output length from stream.
int xd3GetOutputLen(Pointer<Uint8> stream) {
  return _readU64(stream, Xd3StreamOffsets.availOut);
}

/// Read total_out from stream.
int xd3GetTotalOut(Pointer<Uint8> stream) {
  return _readU64(stream, Xd3StreamOffsets.totalOut);
}

/// Read total_in from stream.
int xd3GetTotalIn(Pointer<Uint8> stream) {
  return _readU64(stream, Xd3StreamOffsets.totalIn);
}

/// Read error message from stream.
String xd3GetMsg(Pointer<Uint8> stream) {
  final ptr = _readPtr<Utf8>(stream, Xd3StreamOffsets.msg);
  if (ptr == nullptr) return '';
  return ptr.toDartString();
}

/// Read flags from stream.
int xd3GetFlags(Pointer<Uint8> stream) {
  return _readU32(stream, Xd3StreamOffsets.flags);
}

/// Set flags on stream (only XD3_FLUSH / XD3_SKIP_WINDOW allowed).
void xd3SetFlags(Pointer<Uint8> stream, int flags) {
  _writeU32(stream, Xd3StreamOffsets.flags, flags);
}

// ============================================================
// Source helpers
// ============================================================

/// Set block data on source struct (called by getblk callback).
void xd3SourceSetBlock(
  Pointer<Uint8> source,
  Pointer<Uint8> blockData,
  int blockLen,
  int blockNo,
) {
  _writeU64(source, Xd3SourceOffsets.curblkno, blockNo);
  _writeU64(source, Xd3SourceOffsets.onblk, blockLen);
  _writePtr(source, Xd3SourceOffsets.curblk, blockData);
}

/// Read requested block number from source.
int xd3SourceGetRequestedBlkno(Pointer<Uint8> source) {
  return _readU64(source, Xd3SourceOffsets.getblkno);
}

/// Read block size from source.
int xd3SourceGetBlksize(Pointer<Uint8> source) {
  return _readU64(source, Xd3SourceOffsets.blksize);
}

/// Initialize a source struct with block size.
void xd3SourceInit(Pointer<Uint8> source, int blksize) {
  // Zero-init is done by calloc, just set blksize
  _writeU64(source, Xd3SourceOffsets.blksize, blksize);
}

// ============================================================
// Config helpers
// ============================================================

/// Initialize a config struct with winsize and flags.
/// All other fields left as 0 (NULL/defaults).
void xd3ConfigInit(Pointer<Uint8> config, {int winsize = 0, int flags = 0}) {
  if (winsize > 0) _writeU64(config, Xd3ConfigOffsets.winsize, winsize);
  if (flags != 0) _writeU32(config, Xd3ConfigOffsets.flags, flags);
}