# xdelta3 流式 API 实现记录

> 状态：**已完成并验证通过**
>
> 原计划从一次性 API（`xd3_encode_memory`）迁移到流式 API（`xd3_encode_input` / `xd3_decode_input`），已全部实现并修复关键 bug。

## Context

当前 xdelta3 FFI 使用一次性 API（`xd3_encode_memory`），整个文件载入内存，限制约 1-1.5 GB。改为流式 API（`xd3_encode_input` / `xd3_decode_input`），内存恒定（仅缓冲区大小），支持任意大文件。

DLL 来源：`C:\Users\xiaobing\Downloads\xdelta-3.1.0`，版本 3.1.0，**CMake + MSVC 2022 x64** 编译。
关键编译选项：`XD3_USE_LARGESIZET=1`，`XD3_USE_LARGEFILE64=1` → **`usize_t = uint64_t`**，**`xoff_t = uint64_t`**。

---

## 实现结果

### 已完成文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/xdelta3/xd3_stream_bindings.dart` | 新建 | 流式 FFI 绑定 + struct 字段偏移常量 |
| `lib/xdelta3/xd3_streaming.dart` | 新建 | `Xd3StreamEncoder` / `Xd3StreamDecoder` |
| `lib/xdelta3/xdelta3.dart` | 修改 | 添加 `encodeFile()` / `decodeFile()` |
| `lib/utils/path.dart` | 修改 | `PatchUtils` 使用流式编码 |
| `lib/utils/installer.dart` | 修改 | `PatchInstaller` 使用流式解码 |
| `windows/resources/xdelta3.dll` | 重新编译 | CMake + MSVC 2022 x64，从源码构建 |

### 验证结果

`test_streaming.dart` 自测 3 项全部通过：
- 小文件 (93B)：编码 107B 补丁，解码还原 93B，内容一致
- 中等文件 (1MB)：编码 280B 补丁，解码还原 1,049,076B，内容一致
- 大文件 (20MB)：编码 836B 补丁，解码还原 20,975,616B，内容一致

---

## 关键发现：avail_in 清零 bug

### 问题

流式编码器在文件读完时只设置 `XD3_FLUSH` 标志，但**不清零 `stream.avail_in`**。xdelta3 内部的 `xd3_encode_buffer_leftover` 函数在第二次调用时会把已缓冲的输入数据再复制一遍，导致最后一个窗口的数据被重复编码。

### 表现

- 小文件 (93B)：解码输出 186B（恰好 2x）
- 中等文件 (1MB)：解码输出 2MB（恰好 2x）
- 大文件 (20MB)：只有最后不足一个窗口的尾部被重复（多出 4,198,400 字节）

### 原因

xdelta3 的 `xd3_encode_input` 在 `ENC_INPUT` 状态下：
1. 如果 `avail_in < winsize && !FLUSH`，调用 `buffer_leftover` 将输入缓冲到内部 `buf_in`
2. `buffer_leftover` 返回 `XD3_INPUT`（等更多数据），**不修改** `stream.avail_in`
3. 下次调用时，`avail_in` 仍指向旧数据 → `buffer_leftover` 再次复制相同数据

### 修复

在 `bytesRead == 0`（无更多输入）时，先调用 `xd3SetInput(buf, 0)` 将 `avail_in` 置零，再设 `XD3_FLUSH`：

```dart
if (bytesRead == 0) {
  allInputFed = true;
  xd3SetInput(streamPtr, inputBuf, 0);  // 清零 avail_in
  xd3SetFlags(streamPtr, originalFlags | Xd3Flags.flush);
}
```

编码器 (`Xd3StreamEncoder`) 和解码器 (`Xd3StreamDecoder`) 都做了同样修改。

---

## struct 字段偏移（已从 xdelta3 v3.1.0 源码验证）

### xd3_stream 偏移

```
offset 0:   next_in    Pointer<Uint8>   // 输入数据指针
offset 8:   avail_in   uint64           // 输入数据长度
offset 16:  total_in   uint64           // 总输入字节
offset 24:  next_out   Pointer<Uint8>   // 输出数据指针
offset 32:  avail_out  uint64           // 输出数据长度
offset 40:  space_out  uint64           // 输出空间总大小
offset 48:  current_window uint64       // 当前窗口编号
offset 56:  total_out  uint64           // 总输出字节
offset 64:  msg        Pointer<Utf8>    // 错误信息
offset 72:  src        Pointer          // xd3_source 指针
offset 80:  winsize    uint64           // 窗口大小
offset 88:  sprevsz    uint64           // 小字符串匹配范围
offset 96:  sprevmask  uint64           // 小字符串匹配掩码
offset 104: iopt_size  uint64           // 指令优化缓冲区条目数
offset 112: iopt_unlimited uint64       // 无限指令优化
offset 120: getblk     Pointer          // getblk 回调函数
offset 128: alloc      Pointer          // 内存分配函数
offset 136: free_      Pointer          // 内存释放函数
offset 144: opaque     Pointer          // 用户数据指针
offset 152: flags      uint32           // 编解码标志
```

### xd3_source 偏移

```
offset 0:   blksize    uint64           // 块大小
offset 8:   name       Pointer          // 名称（可选）
offset 32:  curblkno   uint64           // getblk 设置：当前块号
offset 40:  onblk      uint64           // getblk 设置：当前块字节数
offset 48:  curblk     Pointer<Uint8>   // getblk 设置：当前块数据指针
offset 56:  srclen     uint64           // xdelta3 设置：源窗口长度
offset 64:  srcbase    uint64           // xdelta3 设置：源窗口基址
offset 104: getblkno   uint64           // xdelta3 设置：请求的块号
offset 128: eofKnown   int32            // 是否已知 EOF
```

### xd3_config 偏移

```
offset 0:   winsize    uint64           // 窗口大小
offset 8:   sprevsz    uint64           // 小字符串匹配范围
offset 16:  iopt_size  uint64           // 指令优化缓冲区条目数
offset 24:  getblk     Pointer          // getblk 回调
offset 32:  alloc      Pointer          // 内存分配函数
offset 40:  freef      Pointer          // 内存释放函数
offset 48:  opaque     Pointer          // 用户数据指针
offset 56:  flags      uint32           // 标志
```

---

## DLL 编译步骤

```bash
# 在 VS2022 Developer Command Prompt 中
cd C:\Users\xiaobing\Downloads\xdelta-3.1.0\xdelta-3.1.0
mkdir build-dll && cd build-dll
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release
# 产物：build-dll/Release/xdelta3.dll
```

DLL 导出 55 个符号，关键函数：
- `xd3_config_stream`, `xd3_set_source`, `xd3_set_source_and_size`
- `xd3_encode_input`, `xd3_decode_input`
- `xd3_close_stream`, `xd3_abort_stream`, `xd3_free_stream`
- `xd3_encode_memory`, `xd3_decode_memory`
- `xd3_get_appheader`, `xd3_strerror`

---

## 内存占用对比

| 场景 | 一次性 API（旧） | 流式 API（新） |
|------|-----------------|---------------|
| 1GB 文件编码 | ~7GB（新+旧+输出） | ~192MB（3×64MB 缓冲区） |
| 4GB 文件编码 | 无法处理 | ~192MB |
