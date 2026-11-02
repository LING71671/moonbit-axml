# 参考资料与语料来源

[English](THIRD_PARTY.md)

MoonBit 实现及测试 XML 源码均为本仓库编写，采用 [Apache-2.0](LICENSE)。仓库未包含
第三方实现源码或示例 APK。以下外部工具和规范用于验证：

| 参考 | 版本或修订 | 用途 |
| --- | --- | --- |
| [AOSP ResourceTypes.h](https://github.com/aosp-mirror/platform_frameworks_base/blob/d67e90e8a8301a87726420a1071fca8e52172bd4/libs/androidfw/include/androidfw/ResourceTypes.h) | d67e90e8a8301a87726420a1071fca8e52172bd4；Apache-2.0 | 二进制结构和类型值规范 |
| Android SDK aapt2 | Build Tools 36.0.0，修订 2.20-13193326 | 编译自有 XML 并输出独立参考记录 |
| [Androguard](https://github.com/androguard/androguard) | 4.1.3；Apache-2.0 | 独立解码测试 XML 并记录语义树 |
| [MoonBit core](https://github.com/moonbitlang/core) | 0.10.18+6c83a7f62；Apache-2.0 | 标准库和原生文件 I/O，由工具链提供 |

准确的工具和输入哈希、源码路径、语料来源及参考输出哈希记录在
[fixtures/manifest.json](fixtures/manifest.json)。Android SDK 工具和 Python 依赖仅用于开发，
不随本仓库分发。
