# Patch Maker

基于 xdelta3 的增量更新补丁生成与应用工具。

## 功能

- **生成补丁**：对比新旧版本目录，自动生成 VCDIFF 增量补丁文件
- **安装补丁**：读取补丁目录中的 manifest，将旧版本还原为新版本
- 支持任意大小文件（流式处理，内存占用恒定 ~192MB）
- 自动检测新增文件、删除文件、未变化文件
- SHA256 校验确保数据完整性
- 中英文界面支持

## 技术原理

使用 [xdelta3](https://github.com/jmacd/xdelta) v3.1.0 的流式 API，通过 Dart FFI 调用原生 DLL：

- 补丁生成：分块读取新旧文件 → xd3_encode_input → 写出 VCDIFF delta
- 补丁应用：分块读取 delta + 旧文件 → xd3_decode_input → 写出还原文件
- 哈希校验：分块 SHA256，不全量载入内存

## 使用方法

### 生成补丁

1. 选择新版本目录
2. 选择旧版本目录
3. 选择输出目录
4. 点击开始，等待完成

### 安装补丁

1. 选择补丁目录（包含 manifest.json 和 .patch 文件）
2. 选择安装目标目录
3. 点击开始，等待完成

## 开发

```bash
# 运行
flutter run -d windows

# 构建
flutter build windows

# 生成 JSON 序列化代码（修改 model 后）
dart run build_runner build

# 更新图标
dart run icons_launcher:create

# 静态分析
dart analyze lib/

# 流式 API 自测
dart run test_streaming.dart
```

## 依赖

| 依赖 | 用途 |
|------|------|
| `ffi` | Dart FFI 调用 xdelta3 DLL |
| `crypto` | SHA256 哈希校验 |
| `file_picker` | 文件/目录选择 |
| `json_annotation` | JSON 序列化 |
| `shared_preferences` | 持久化设置 |
| `path_provider` | 应用目录路径 |

## 文档

- [DLL 使用说明](docs/xdll-usage.md)
- [流式 API 实现记录](docs/streaming-api-plan.md)
