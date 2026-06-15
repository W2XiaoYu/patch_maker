# Patch Maker - CLAUDE.md

## 项目概述

Flutter 桌面应用，通过 xdelta3 (VCDIFF) 实现增量补丁生成与应用。两个核心功能：
- **生成补丁**：对比新旧目录，生成 .patch 文件 + manifest.json
- **安装补丁**：读取 manifest，应用补丁还原文件

## 技术栈

- Flutter + Dart SDK ^3.8.0，目标平台 Windows x64
- xdelta3 v3.0.10 官方 exe（通过 `Process.run` 子进程调用）
- `package:crypto` SHA256 哈希
- Cupertino (iOS 风格) UI，支持中英文

## 关键架构

### xdelta3 子进程层（lib/xdelta3/）

**通过子进程调用官方 xdelta3.exe，不再使用 FFI/DLL。** 每次调用是一个独立 OS 进程，结束后由系统回收内存，不会污染 Flutter 进程。

```
xdelta3_exe.dart  → Xdelta3Exe 单例包装：encodeFile() / decodeFile()
                    通过 Process.run 调用 exe，参数：
                      encode: -f -q -e -s <old> <new> <patch>
                      decode: -f -q -d -s <old> <patch> <output>
```

历史背景：早期方案使用 xdelta3 DLL + Dart FFI（流式 API），但 struct 字段偏移维护成本高、 avail_in 清零等坑容易翻车。已彻底替换为子进程方案。

### 业务层（lib/utils/）

- `path.dart` — `PatchUtils`：补丁生成，在 isolate 中调 `Xdelta3Exe().encodeFile()` + 分块 SHA256
- `installer.dart` — `PatchInstaller`：补丁安装，在 isolate 中调 `Xdelta3Exe().decodeFile()` + 分块 SHA256
- 两个文件各自有 `_fileSha256()` 和 `_DigestSink` 的重复定义（因为是顶层函数，compute() 需要独立入口）

### 模型（lib/model/）

- `ManifestMetadata` — manifest.json 顶层结构
- `FileMetadata` — 每个文件的元数据（路径、SHA256、大小、压缩率等）
- 使用 `json_serializable`，修改后需 `dart run build_runner build`

### EXE 管理

- 源文件：`windows/resources/xdelta3.exe`（官方 xdelta3-x86_64-3.0.10.exe）
- CMake 在构建时复制到 exe 同目录：`windows/CMakeLists.txt`
- 运行时通过 `Platform.resolvedExecutable` 定位 exe 路径（`Xdelta3Exe.locateExe()`）
- VCDIFF 是 RFC 3284/6202 标准，3.0.10 ↔ 3.1.x 生成的补丁互通

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
- `_DigestSink implements Sink<Digest>` — Dart 的 Sink 是 interface class，必须用 implements 而非 extends
- `Process.run` 在 isolate 中可用（dart:io 完整支持），子进程结束后内存由 OS 回收
- 替换 exe 版本：直接覆盖 `windows/resources/xdelta3.exe`，CMake 会自动复制到 build 输出目录
