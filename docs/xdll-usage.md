# xdelta3 DLL 使用说明

## 1. 概述

本项目通过 **Dart FFI (Foreign Function Interface)** 调用预编译的 `xdelta3.dll`，实现 VCDIFF 格式的增量补丁生成与应用。FFI 层分为三层：

```
┌──────────────────────────────────────────────────────────────┐
│                    应用层 (Flutter UI)                         │
├──────────────────────────────────────────────────────────────┤
│  PatchUtils (生成补丁)            │  PatchInstaller (应用补丁)     │
│     (lib/utils/path.dart)         │ (lib/utils/installer.dart)    │
│  小文件: xd3.encode()             │  小文件: xd3.decode()         │
│  大文件: xd3.encodeFile() 流式    │  大文件: xd3.decodeFile() 流式 │
├──────────────────────────────────────────────────────────────┤
│            Xdelta3 高层封装 (xdelta3.dart)                      │
│            - encode() / decode()      ← 一次性 API（<256MB）    │
│            - encodeFile() / decodeFile() ← 流式 API（任意大小）   │
│            - Xd3Result 统一返回结果                              │
├──────────────────────────────────────────────────────────────┤
│    FFI 绑定层                                                   │
│    ├── xd3_bindings.dart      ← DLL 加载 + 一次性 API 绑定      │
│    ├── xd3_stream_bindings.dart ← 流式 API 绑定 + 结构体偏移     │
│    └── xd3_streaming.dart     ← 流式编解码器（Xd3StreamEncoder/Decoder）│
├──────────────────────────────────────────────────────────────┤
│               xdelta3.dll (v3.1.0 CMake + MSVC 2022 编译)       │
│               一次性 API: xd3_encode/decode_memory              │
│               流式 API:   xd3_config/encode/decode_input 等     │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. DLL 文件管理

### 2.1 文件位置

| 文件 | 用途 |
|------|------|
| `windows/resources/xdelta3.dll` | 源文件，随项目仓库管理 |
| `build/.../runner/Debug/xdelta3.dll` | 构建产物，自动复制到 exe 同目录 |

### 2.2 构建集成 (CMake)

在 `windows/CMakeLists.txt` 第 110-113 行，通过 CMake install 指令将 DLL 复制到构建输出目录：

```cmake
# Install xdelta3 DLL
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/resources/xdelta3.dll"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)
```

`INSTALL_BUNDLE_LIB_DIR` 就是 exe 所在目录，确保 DLL 与 `patch_maker.exe` 在同一目录下。

### 2.3 运行时加载

`Xdelta3Native._loadLibrary()` 通过 `Platform.resolvedExecutable` 定位 exe 路径，推导出 DLL 的完整路径：

```dart
DynamicLibrary _loadLibrary(String? path) {
  if (path != null) {
    return DynamicLibrary.open(path);  // 允许手动指定路径
  }

  if (Platform.isWindows) {
    final exePath = Platform.resolvedExecutable;  // 例: C:\app\patch_maker.exe
    final exeDir = exePath.substring(0, exePath.lastIndexOf('\\'));
    final dllPath = '$exeDir\\xdelta3.dll';        // C:\app\xdelta3.dll
    return DynamicLibrary.open(dllPath);
  }
  // ... Linux / macOS 支持
}
```

**要点：**
- DLL 必须与 exe 在同一目录
- 可通过 `Xdelta3(dllPath: '自定义路径')` 覆盖自动检测
- Linux 加载 `libxdelta3.so`，macOS 加载 `libxdelta3.dylib`

### 2.4 从源码编译 DLL

DLL 源码位于 `C:\Users\xiaobing\Downloads\xdelta-3.1.0`，使用 CMake + MSVC 2022 x64 编译：

```bash
# 在 VS2022 Developer Command Prompt 中
cd C:\Users\xiaobing\Downloads\xdelta-3.1.0\xdelta-3.1.0
mkdir build-dll && cd build-dll
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release
# 产物：build-dll/Release/xdelta3.dll → 复制到 windows/resources/
```

编译选项：`XD3_USE_LARGESIZET=1`（`usize_t = uint64_t`），`xd3_dll.c` 包装器自动设置 `XD3_ENCODER=1`、`SECONDARY_DJW=1`、`SECONDARY_FGK=1`。

---

## 3. FFI 绑定详解

### 3.1 绑定的 C 函数

DLL 导出 55 个符号，核心函数：

```c
// 编码：生成 VCDIFF 差量数据（一次性 API）
int xd3_encode_memory(
  const uint8_t *input,       // 新文件数据
  usize_t        input_size,  // 新文件大小
  const uint8_t *source,      // 旧文件数据
  usize_t        source_size, // 旧文件大小
  uint8_t       *output,      // 输出缓冲区（调用方分配）
  usize_t       *output_size, // [in/out] 输出缓冲区大小 → 实际写入大小
  usize_t        avail_output,// 输出缓冲区容量
  int            flags        // 编码标志
);

// 解码：还原文件（一次性 API）
int xd3_decode_memory(
  const uint8_t *input,       // 差量数据
  usize_t        input_size,  // 差量大小
  const uint8_t *source,      // 旧文件数据
  usize_t        source_size, // 旧文件大小
  uint8_t       *output,      // 输出缓冲区
  usize_t       *output_size, // [in/out]
  usize_t        avail_output,
  int            flags
);

// 错误码转可读字符串
const char* xd3_strerror(int ret);

// 流式 API
int xd3_config_stream(xd3_stream *stream, xd3_config *config);
int xd3_set_source(xd3_stream *stream, xd3_source *source);
int xd3_set_source_and_size(xd3_stream *stream, xd3_source *source, usize_t size);
int xd3_encode_input(xd3_stream *stream);
int xd3_decode_input(xd3_stream *stream);
int xd3_close_stream(xd3_stream *stream);
void xd3_abort_stream(xd3_stream *stream);
void xd3_free_stream(xd3_stream *stream);
int xd3_get_appheader(xd3_stream *stream, uint8_t **data, usize_t *size);
```

### 3.2 Dart 类型映射

| C 类型 | Dart FFI 类型 | 说明 |
|--------|---------------|------|
| `uint8_t*` | `Pointer<Uint8>` | 字节数据指针 |
| `usize_t` | `Uint64` | 64 位 Windows 上 usize_t 是 uint64_t |
| `usize_t*` | `Pointer<UsizeT>` | 输出大小（in/out 参数） |
| `int` | `Int32` | 返回码 / flags |
| `const char*` | `Pointer<Utf8>` | UTF-8 字符串 |

### 3.3 函数绑定方式

每个 C 函数需要定义两个 typedef——Native 签名和 Dart 签名：

```dart
// C 签名（Native）
typedef _EncodeMemoryNative = Int32 Function(
  Pointer<Uint8>, UsizeT, Pointer<Uint8>, UsizeT,
  Pointer<Uint8>, Pointer<UsizeT>, UsizeT, Int32,
);

// Dart 签名（自动转换为基础类型）
typedef _EncodeMemoryDart = int Function(
  Pointer<Uint8>, int, Pointer<Uint8>, int,
  Pointer<Uint8>, Pointer<UsizeT>, int, int,
);

// 通过 lookupFunction 绑定
encodeMemory = _lib.lookupFunction<_EncodeMemoryNative, _EncodeMemoryDart>(
  'xd3_encode_memory',  // DLL 导出的符号名
);
```

### 3.4 结构体字段偏移

流式 API 通过指针算术直接读写 xdelta3 内部结构体。偏移量定义在 `xd3_stream_bindings.dart` 中，基于 xdelta3 v3.1.0 源码验证：

**xd3_stream 偏移**（`Xd3StreamOffsets`）：

| 偏移 | 字段 | 类型 | 用途 |
|------|------|------|------|
| 0 | next_in | Pointer | 输入数据指针 |
| 8 | avail_in | uint64 | 输入数据长度 |
| 16 | total_in | uint64 | 总输入字节 |
| 24 | next_out | Pointer | 输出数据指针 |
| 32 | avail_out | uint64 | 输出数据长度 |
| 40 | space_out | uint64 | 输出空间总大小 |
| 48 | current_window | uint64 | 当前窗口编号 |
| 56 | total_out | uint64 | 总输出字节 |
| 64 | msg | Pointer | 错误信息 |
| 72 | src | Pointer | xd3_source 指针 |
| 80 | winsize | uint64 | 窗口大小 |
| 120 | getblk | Pointer | getblk 回调函数 |
| 152 | flags | uint32 | 编解码标志 |

**xd3_source 偏移**（`Xd3SourceOffsets`）：

| 偏移 | 字段 | 类型 | 用途 |
|------|------|------|------|
| 0 | blksize | uint64 | 块大小 |
| 32 | curblkno | uint64 | 当前块号（getblk 设置） |
| 40 | onblk | uint64 | 当前块字节数（getblk 设置） |
| 48 | curblk | Pointer | 当前块数据指针（getblk 设置） |
| 104 | getblkno | uint64 | 请求的块号（xdelta3 设置） |

**xd3_config 偏移**（`Xd3ConfigOffsets`）：

| 偏移 | 字段 | 类型 | 用途 |
|------|------|------|------|
| 0 | winsize | uint64 | 窗口大小 |
| 24 | getblk | Pointer | getblk 回调 |
| 56 | flags | uint32 | 标志 |

---

## 4. 高层 API 使用

### 4.1 Xd3Result — 统一结果类型

```dart
class Xd3Result {
  final bool       isOk;          // 是否成功
  final Uint8List  data;          // 输出数据（成功时）
  final int        errorCode;     // 错误码（0 = 成功）
  final String     errorMessage;  // 错误描述
}
```

### 4.2 编码（生成补丁）

```dart
final xd3 = Xdelta3();

// 读取文件
final oldBytes = File('v1.0/data.bin').readAsBytesSync();
final newBytes = File('v2.0/data.bin').readAsBytesSync();

// 生成 VCDIFF delta
final result = xd3.encode(
  input:  newBytes,   // 新文件数据
  source: oldBytes,   // 旧文件数据（可为空，纯压缩）
  flags:  0,          // 可选标志
  outputHeadroom: 1.5, // 输出缓冲区 = input大小 × 此系数
);

if (result.isOk) {
  File('data.bin.patch').writeAsBytesSync(result.data);
  print('补丁大小: ${result.data.length} bytes');
} else {
  print('编码失败: ${result.errorMessage}');
}

xd3.close();
```

**参数说明：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `input` | `Uint8List` | 必填 | 新文件数据 |
| `source` | `Uint8List?` | null | 旧文件数据，null 则为纯压缩 |
| `flags` | `int` | 0 | `Xd3Flags` 的 OR 组合 |
| `outputHeadroom` | `double` | 1.5 | 输出缓冲区倍数，补丁大于源文件时需调高 |

### 4.3 解码（应用补丁）

```dart
final xd3 = Xdelta3();

final oldBytes  = File('v1.0/data.bin').readAsBytesSync();
final patchBytes = File('data.bin.patch').readAsBytesSync();

final result = xd3.decode(
  input:  patchBytes,  // delta 数据
  source: oldBytes,    // 旧文件数据
  maxOutputSize: null, // 自动计算：source + input + 65536
);

if (result.isOk) {
  File('v2.0/data.bin').writeAsBytesSync(result.data);
} else {
  print('解码失败: ${result.errorMessage}');
}

xd3.close();
```

**参数说明：**

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `input` | `Uint8List` | 必填 | delta 数据 |
| `source` | `Uint8List` | 必填 | 旧文件数据 |
| `flags` | `int` | 0 | 解码标志 |
| `maxOutputSize` | `int?` | null | 输出缓冲区大小，null 自动计算 |

---

## 5. 内存管理

### 5.1 分配与释放

所有原生内存通过 `package:ffi` 的 `calloc` 分配，在 `finally` 块中释放：

```dart
Xd3Result encode({required Uint8List input, ...}) {
  // 1. 分配原生内存
  final inputPtr    = calloc<Uint8>(inputLen);
  final sourcePtr   = calloc<Uint8>(sourceLen);
  final outputPtr   = calloc<Uint8>(availOutput);
  final outputSizePtr = calloc<UsizeT>();

  try {
    // 2. 复制数据到原生内存
    inputPtr.asTypedList(inputLen).setAll(0, input);

    // 3. 调用 DLL
    final ret = _native.encodeMemory(...);

    // 4. 读取结果
    if (ret == 0) {
      return Xd3Result.ok(Uint8List.fromList(outputPtr.asTypedList(used)));
    }
    return Xd3Result.fail(ret, _strerror(ret));
  } finally {
    // 5. 无论成功失败，释放所有原生内存
    calloc.free(inputPtr);
    calloc.free(sourcePtr);
    calloc.free(outputPtr);
    calloc.free(outputSizePtr);
  }
}
```

### 5.2 关键注意事项

- **`asTypedList()`** 创建的是原生内存的 **视图**，不是拷贝，数据会随原生内存释放而失效
- **`Uint8List.fromList()`** 在返回前将数据拷贝到 Dart 管理的内存，确保 `free()` 后数据仍可用
- **`nullptr` 处理**：当 `source` 为空时传 `nullptr`，避免分配 0 字节内存

---

## 6. Isolate 中的使用

DLL 调用在 Dart Isolate 中执行，避免阻塞 UI 线程。

### 6.1 补丁生成（PatchUtils）

```dart
// 调用方 — UI 线程
final result = await compute(_makePatchIsolate, {
  'old_file': oldFilePath,
  'new_file': newFilePath,
  'patch_out': patchOutputPath,
  'output_path': outputBasePath,
});

// Isolate 入口 — 后台线程
Map<String, dynamic> _makePatchIsolate(Map<String, String> args) {
  final xd3 = Xdelta3();    // 每个 isolate 创建独立实例
  try {
    final enc = xd3.encode(input: newBytes, source: oldBytes);
    // ... 处理结果 ...
  } finally {
    xd3.close();
  }
}
```

### 6.2 补丁安装（PatchInstaller）

```dart
// 调用方 — UI 线程
final decodeResult = await compute(_decodePatchIsolate, {
  'old_file': oldFilePath,
  'patch_file': patchFilePath,
  'output_file': tempOutputPath,
  'max_output_size': newFileSize + 4096,
});

// Isolate 入口 — 后台线程
Map<String, dynamic> _decodePatchIsolate(Map<String, dynamic> args) {
  final xd3 = Xdelta3();    // 独立实例
  try {
    final result = xd3.decode(input: patchBytes, source: oldBytes);
    // ... 写文件、验证 SHA256 ...
  } finally {
    xd3.close();
  }
}
```

**注意事项：**
- 每个 isolate 必须创建独立的 `Xdelta3()` 实例（DLL 句柄不跨 isolate 共享）
- `compute()` 的入口函数必须是 **顶层函数**（top-level function），不能是类方法

---

## 7. 错误码与标志

### 7.1 返回码 (Xd3Return)

| 常量 | 值 | 含义 |
|------|-----|------|
| `input` | -17703 | 需要更多输入 |
| `output` | -17704 | 有输出可读 |
| `getSrcBlk` | -17705 | 需要源数据块 |
| `gotHeader` | -17706 | 解码头已解析 |
| `winStart` | -17707 | 窗口开始 |
| `winFinish` | -17708 | 窗口结束 |
| `tooFarBack` | -17709 | 回溯距离过远 |
| `internal` | -17710 | 内部错误 |
| `invalid` | -17711 | 无效数据 |
| `invalidInput` | -17712 | 无效输入 |
| `noSecond` | -17713 | 无辅助数据 |
| `unimplemented` | -17714 | 未实现功能 |

返回值 **0** 表示成功，非零通过 `xd3_strerror()` 获取可读描述。

注意：`input`(-17703)、`output`(-17704) 等是流式 API 的正常状态码，不是错误。在流式 API 循环中根据返回码决定下一步操作。

### 7.2 编码标志 (Xd3Flags)

| 标志 | 值 | 说明 |
|------|-----|------|
| `flush` | 1 << 4 | 刷新输出（流式 API 结束时必须设置） |
| `secDjw` | 1 << 5 | DJW 二次压缩 |
| `secFgk` | 1 << 6 | FGK 二次压缩 |
| `secLzma` | 1 << 24 | LZMA 二次压缩 |
| `noCompress` | 1 << 13 | 禁用压缩 |
| `beGreedy` | 1 << 14 | 贪婪匹配模式 |
| `compLevel1` ~ `compLevel9` | N << 20 | 压缩级别 |

多个标志通过 `|` 组合使用：
```dart
xd3.encode(input: data, source: old, flags: Xd3Flags.secDjw | Xd3Flags.compLevel9);
```

---

## 8. 完整调用流程

### 8.1 补丁生成流程

```
用户选择新旧目录
       │
       ▼
  PatchUtils.generatePatchManifest()
       │
       ▼
  _buildTaskList()  ← 扫描新目录，生成文件任务列表
       │
       ▼
  for 每个文件:
       │
       ├── 旧文件不存在?  → 标记为 new_file，直接复制
       │
       ├── SHA256 相同?   → 标记为 unchanged，跳过
       │
       └── 调用 compute(_makePatchIsolate)
              │
              ▼
         Xdelta3()           ← 加载 DLL
         xd3.encodeFile()    ← 流式编码（所有文件）
              │
              ▼
         写 .patch 文件
         计算 SHA256
         xd3.close()
       │
       ▼
  _findDeletedFiles()  ← 查找已删除的文件
       │
       ▼
  生成 manifest.json
```

### 8.2 补丁安装流程

```
用户选择补丁目录和安装目录
       │
       ▼
  PatchInstaller.install()
       │
       ▼
  loadManifest()  ← 读取 manifest.json
       │
       ▼
  for 每个文件:
       │
       ├── deletedFileOnly?  → 删除目标文件
       │
       ├── newFileOnly?      → 从补丁目录复制新文件
       │
       └── 补丁文件 → compute(_decodePatchIsolate)
              │
              ▼
         Xdelta3()            ← 加载 DLL
         xd3.decodeFile()     ← 流式解码（所有文件）
              │
              ▼
         写临时文件
         验证 SHA256
         xd3.close()
              │
              ▼
         临时文件覆盖原文件
       │
       ▼
  清理临时目录，输出统计
```

---

## 9. 项目文件结构

```
patch_maker/
├── lib/
│   ├── xdelta3/
│   │   ├── xd3_bindings.dart         # FFI 绑定：DLL 加载 + 一次性 API
│   │   ├── xd3_stream_bindings.dart  # FFI 绑定：流式 API + 结构体偏移
│   │   ├── xd3_streaming.dart        # 流式编解码器
│   │   └── xdelta3.dart             # 高层封装：encode/decode + encodeFile/decodeFile
│   ├── utils/
│   │   ├── path.dart                 # PatchUtils：自动选择一次性/流式
│   │   └── installer.dart            # PatchInstaller：自动选择一次性/流式
│   └── ...
├── windows/
│   ├── resources/
│   │   └── xdelta3.dll              # 预编译 DLL (v3.1.0, CMake + MSVC 2022 x64)
│   └── CMakeLists.txt               # 构建配置
├── test_streaming.dart              # 流式 API 自测脚本
├── pubspec.yaml
└── docs/
    ├── xdll-usage.md                # 本文档
    └── streaming-api-plan.md        # 流式 API 实现记录
```

---

## 10. 常见问题排查

### DLL 加载失败

**症状：** `Unhandled exception: Invalid argument(s): Failed to load dynamic library`

**排查步骤：**
1. 确认 `xdelta3.dll` 与 `patch_maker.exe` 在同一目录
2. 检查 DLL 架构是否匹配（本项目使用 **x86_64** 版本）
3. 检查是否有杀毒软件拦截 DLL 加载
4. 使用 `Xdelta3(dllPath: '完整路径')` 手动指定 DLL 路径

### 编码输出缓冲区不足

**症状：** encode 返回非零错误码

**解决：** 增大 `outputHeadroom` 参数：
```dart
xd3.encode(input: data, source: old, outputHeadroom: 3.0);
```

### 内存泄漏

FFI 层已通过 `try/finally` 确保原生内存释放。如果出现内存问题：
1. 确认没有在 `finally` 块外部跳过 `calloc.free()`
2. 每次 `Xdelta3()` 使用后调用 `close()`（当前为 no-op，但建议保留以兼容未来实现）

### 跨平台支持

当前仅 Windows 构建包含 DLL。要支持 Linux/macOS：
1. 编译对应平台的 xdelta3 共享库（`.so` / `.dylib`）
2. 放置到与可执行文件同目录
3. `_loadLibrary()` 已包含跨平台路径逻辑，无需修改 Dart 代码

---

## 11. 流式 API

### 11.1 概述

流式 API 通过 `xd3_encode_input` / `xd3_decode_input` 分块处理文件，内存占用恒定（~192MB），不受文件大小限制。

| 特性 | 一次性 API (`encode`/`decode`) | 流式 API (`encodeFile`/`decodeFile`) |
|------|------|------|
| 文件大小限制 | ~1.5 GB | 无限制 |
| 内存占用 | ~7 倍文件大小 | ~192 MB（3×64MB 缓冲区） |
| 实现文件 | `xdelta3.dart` | `xd3_streaming.dart` |

### 11.2 使用方式

```dart
final xd3 = Xdelta3();

// 流式编码（直接从文件到文件）
final ok = await xd3.encodeFile(
  newFilePath: 'v2.0/data.bin',
  oldFilePath: 'v1.0/data.bin',
  outputPatchPath: 'data.bin.patch',
  chunkSize: 8 * 1024 * 1024,  // 8MB 分块
  winsize: 8 * 1024 * 1024,    // 8MB 窗口
  onProgress: (done, total) => print('$done / $total'),
);

// 流式解码
final ok = await xd3.decodeFile(
  patchFilePath: 'data.bin.patch',
  oldFilePath: 'v1.0/data.bin',
  outputFilePath: 'v2.0/data.bin',
);
```

### 11.3 自动切换

业务层（`path.dart`、`installer.dart`）已实现自动选择：
- 文件 < 256 MB → 一次性 API（更快）
- 文件 ≥ 256 MB → 流式 API（省内存）

```dart
// 在 _makePatchIsolate 中
if (shouldUseStreaming(newFileSize)) {
  xd3.encodeFile(...);   // 流式
} else {
  xd3.encode(...);       // 一次性
}
```

### 11.4 流式 API 内部流程

```
编码流程:
  calloc(stream, config, source)  ← 分配结构体（8192/1024/256 字节）
  xd3_config_stream()             ← 初始化流
  xd3_set_source_and_size()       ← 设置源文件大小
  注册 getblk 回调                ← NativeCallable.isolateLocal
  循环:
    RandomAccessFile.read(chunk)  → xd3SetInput(stream, buf, bytesRead)
    xd3_encode_input()            → 状态机
    XD3_OUTPUT  → 写输出文件, xd3ConsumeOutput
    XD3_INPUT   → 读下一个 chunk
    XD3_GETSRCBLK → getblk回调读旧文件块
    XD3_WINSTART / XD3_WINFINISH → continue
  输入文件读完:
    xd3SetInput(stream, buf, 0)   ← 清零 avail_in（关键！）
    xd3SetFlags(stream, FLUSH)    ← 刷新最后的窗口
  xd3_close_stream → xd3_free_stream
  calloc.free(all)               ← 释放所有原生内存
```

### 11.5 关键注意事项：avail_in 清零

当输入文件读完（`bytesRead == 0`）时，**必须**先将 `avail_in` 置零，再设 `XD3_FLUSH`。

**原因**：xdelta3 的 `xd3_encode_buffer_leftover` 函数在输入不足一个窗口时会缓冲输入数据但不修改 `stream.avail_in`。如果不清零，下次调用 `xd3_encode_input` 时，`buffer_leftover` 会再次复制已缓冲的数据，导致最后一个窗口的数据被重复编码。

**表现**：
- 不清零：小文件解码输出恰好是预期的 2 倍
- 大文件：只有最后不足一个窗口的尾部被重复

**正确做法**：
```dart
if (bytesRead == 0) {
  allInputFed = true;
  xd3SetInput(streamPtr, inputBuf, 0);  // 清零 avail_in
  xd3SetFlags(streamPtr, flags | Xd3Flags.flush);
}
```

编码器（`Xd3StreamEncoder`）和解码器（`Xd3StreamDecoder`）都需遵守此规则。

### 11.6 DLL 信息

- 版本：xdelta3 v3.1.0
- 源码：`C:\Users\xiaobing\Downloads\xdelta-3.1.0`
- 编译：CMake + MSVC 2022 x64
- 编译选项：`XD3_USE_LARGESIZET=1`, `XD3_USE_LARGEFILE64=1`
- 类型：`usize_t = uint64_t`, `xoff_t = uint64_t`
- 导出符号：55 个（含 `xd3_encode_input`, `xd3_decode_input`, `xd3_config_stream` 等）
- 实现记录：`docs/streaming-api-plan.md`
