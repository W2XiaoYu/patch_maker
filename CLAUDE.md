# Patch Maker - CLAUDE.md

## 项目概述

Flutter 桌面应用，通过 xdelta3 (VCDIFF) 实现增量补丁生成与应用。两个核心功能：
- **生成补丁**：对比新旧目录，生成 .patch 文件 + manifest.json
- **安装补丁**：读取 manifest，应用补丁还原文件

## 技术栈

- Flutter + Dart SDK ^3.8.0，目标平台 Windows x64
- xdelta3 v3.1.0 DLL（通过 Dart FFI 调用）
- `package:ffi` 原生互操作，`package:crypto` SHA256 哈希
- Cupertino (iOS 风格) UI，支持中英文

## 关键架构

### xdelta3 FFI 层（lib/xdelta3/）

**全部使用流式 API**，内存占用恒定（~192MB），支持任意大文件：

```
xdelta3.dart          → 高层封装：encodeFile() / decodeFile()
xd3_streaming.dart    → 流式编解码器（Xd3StreamEncoder / Xd3StreamDecoder）
xd3_stream_bindings.dart → 流式 FFI 绑定 + struct 字段偏移
xd3_bindings.dart     → DLL 加载 + 一次性 API 绑定（保留备用）
```

DLL 编译信息：`usize_t = uint64_t`, `xoff_t = uint64_t`, 默认缓冲区 64MB。

**重要**：struct 字段偏移在 `xd3_stream_bindings.dart` 中定义为常量（`Xd3StreamOffsets`、`Xd3SourceOffsets`、`Xd3ConfigOffsets`），基于 xdelta3 v3.1.0 源码验证。如更换 DLL 版本需重新验证偏移。

### 业务层（lib/utils/）

- `path.dart` — `PatchUtils`：补丁生成，在 isolate 中执行流式编码 + 分块 SHA256
- `installer.dart` — `PatchInstaller`：补丁安装，在 isolate 中执行流式解码 + 分块 SHA256
- 两个文件各自有 `_fileSha256()` 和 `_DigestSink` 的重复定义（因为是顶层函数，compute() 需要独立入口）

### 模型（lib/model/）

- `ManifestMetadata` — manifest.json 顶层结构
- `FileMetadata` — 每个文件的元数据（路径、SHA256、大小、压缩率等）
- 使用 `json_serializable`，修改后需 `dart run build_runner build`

### DLL 管理

- 源文件：`windows/resources/xdelta3.dll`
- CMake 在构建时复制到 exe 同目录：`windows/CMakeLists.txt` 第 110-113 行
- 运行时通过 `Platform.resolvedExecutable` 定位 DLL 路径
- DLL 源码：`C:\Users\xiaobing\Downloads\xdelta-3.1.0`，CMake + MSVC 2022 x64 编译

## 常用命令

```bash
flutter run -d windows          # 运行
flutter build windows           # 构建
dart run build_runner build     # 重新生成 JSON 序列化代码
dart run icons_launcher:create  # 更新应用图标
dart analyze lib/               # 静态分析
```

## 注意事项

- isolate 入口函数必须是顶层函数（top-level function），不能是类方法
- `Xdelta3Native` 的 `lib` 字段是公开的（`Xd3StreamNative` 需要访问 `DynamicLibrary`）
- 流式 API 使用 `NativeCallable.isolateLocal` 注册 getblk 回调，需要 `exceptionalReturn: -1`
- `_DigestSink implements Sink<Digest>` — Dart 的 Sink 是 interface class，必须用 implements 而非 extends
- **流式 API avail_in 清零**：当输入文件读完（bytesRead == 0）时，必须调用 `xd3SetInput(buf, 0)` 将 `avail_in` 置零后再设 `XD3_FLUSH`。否则 xdelta3 内部的 `buffer_leftover` 函数会把已缓冲的输入数据再复制一遍，导致最后一个窗口的数据被重复编码（输出恰好翻倍）。编码器和解码器都需遵守此规则。
